-- Create the hash class.
local class = require 'pl.class'
local Hash = class()


function Hash:_init(cLog)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- Get the logger object.
  local tLogWriter = require 'log.writer.prefix'.new('[Hash] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  -- Try to load the mhash plugin for the hash algorithms.
  local tResult, mhash = pcall(require, 'mhash')
  if tResult==true then
    self.tLog.info('Using mhash to generate hashes.')

    -- Found mhash.
    self.mhash = mhash

    self.atMhashHashes = {
      ['MD5'] = self.mhash.MHASH_MD5,
      ['SHA1'] = self.mhash.MHASH_SHA1,
      ['SHA224'] = self.mhash.MHASH_SHA224,
      ['SHA256'] = self.mhash.MHASH_SHA256,
      ['SHA384'] = self.mhash.MHASH_SHA384,
      ['SHA512'] = self.mhash.MHASH_SHA512
    }
  else
    self.tLog.info('Using CLI tools to generate hashes.')

    -- mhash not found.
    self.mhash = nil

    -- Map the hashes to the command line tools.
    self.atCliHashes = {
      ['MD5'] = 'md5sum',
      ['SHA1'] = 'sha1sum',
      ['SHA224'] = 'sha224sum',
      ['SHA256'] = 'sha256sum',
      ['SHA384'] = 'sha384sum',
      ['SHA512'] = 'sha512sum'
    }
    self.auiHashSizes = {
      ['MD5'] = 16,
      ['SHA1'] = 20,
      ['SHA224'] = 28,
      ['SHA256'] = 32,
      ['SHA384'] = 48,
      ['SHA512'] = 64
    }

    -- Look for the command line tools.
    local fFound = true
    -- The detection needs the popen function.
    if io.popen==nil then
      self.tLog.info('Unable to detect the command line tools for hashes: io.popen is not available.')
      fFound = false
    else
      -- Loop over all command line tools.
      for strId, strCliTool in pairs(self.atCliHashes) do
        -- Try to run the tool.
        local tFile, strError = io.popen(string.format('%s --version', strCliTool))
        if tFile==nil then
          self.tLog.error('Failed to detect the command line tool "%s": %s', strCliTool, strError)
          fFound = false
          break
        else
          -- Read all data from the tool.
          local strData = tFile:read('*a')
          tFile:close()
        end

        self.tLog.debug('Detected "%s".', strCliTool)
      end
    end

    if fFound==false then
      error('No mhash LUA module and not all command line tools detected. Unable to build a hash.')
    end
  end

  -- Initialize the list of known hashes.
  self.atHashQuality = {
    ['MD5'] = 0,
    ['SHA1'] = 1,
    ['SHA224'] = 3,
    ['SHA256'] = 2,
    ['SHA384'] = 5,
    ['SHA512'] = 4
  }
  self.atHashGenerateOrder = {
    'MD5',
    'SHA1',
    'SHA224',
    'SHA256',
    'SHA384',
    'SHA512'
  }
end



--- Convert a string to a HEX dump.
-- Convert each char in the string to its HEX representation.
-- @param strBin The string with the data to dump.
-- @return A HEX dump of strBin.
function Hash:_bin_to_hex(strBin)
  local aHashHex = {}
  for iCnt=1,string.len(strBin) do
    table.insert(aHashHex, string.format("%02x", string.byte(strBin, iCnt)))
  end
  return table.concat(aHashHex)
end



function Hash:_get_hash_for_file(strPath, strHashName)
  local tResult = nil

  if self.mhash==nil then
    -- Construct the command.
    local strCmd = string.format('%s --binary %s', self.atCliHashes[strHashName], strPath)
    -- Try to run the tool.
    local tFile, strError = io.popen(strCmd)
    if tFile==nil then
      self.tLog.info('Failed to run the command "%s": %s', strCmd, strError)
    else
      -- Read all data from the tool.
      local strData = tFile:read('*a')
      tFile:close()

      -- Parse the output.
      tResult = string.match(strData, '^([0-9a-fA-F]+)%s+')
    end

  else
    -- Create a new MHASH state.
    local tHashID = self.atMhashHashes[strHashName]
    local tState = self.mhash.mhash_state()
    tState:init(tHashID)

    -- Open the file and read it in chunks.
    local tFile, strError = io.open(strPath, 'rb')
    if tFile==nil then
      tResult = nil
      self.tLog.error('Failed to open the file "%s" for reading: %s', strPath, strError)
    else
      repeat
        local tChunk = tFile:read(4096)
        if tChunk~=nil then
          tState:hash(tChunk)
        end
      until tChunk==nil
      tFile:close()

      -- Get the binary hash.
      local strHashBin = tState:hash_end()

      -- Convert the binary hash into a string.
      tResult = self:_bin_to_hex(strHashBin)
    end
  end

  return tResult
end



function Hash:_get_hash_for_string(strData, strHashName)
  local tResult

  if self.mhash==nil then
    -- Get a name for a temp file.
    local strTmpFile = self.pl.path.tmpname()
    -- Write the data to the temp file.
    local tFileResult, strError = self.pl.utils.writefile(strTmpFile, strData, true)
    if tFileResult==nil then
      self.tLog.error('Failed to create the temp file "%s" to generate a hash: %s', strTmpFile, strError)
    else
      -- Hash the temp file.
      tResult = self:_get_hash_for_file(strTmpFile, strHashName)
      -- Remove the temp file.
      tFileResult, strError = os.remove(strTmpFile)
      if tFileResult==nil then
        self.tLog.error('Failed to remove the temp file "%s" after creating the hash: %s', strTmpFile, strError)
        tResult = nil
      end
    end

  else
    -- Create a new MHASH state.
    local tHashID = self.atMhashHashes[strHashName]
    local tState = self.mhash.mhash_state()
    tState:init(tHashID)
    tState:hash(strData)
    local strHashBin = tState:hash_end()

    -- Convert the binary hash into a string.
    tResult = self:_bin_to_hex(strHashBin)
  end

  -- Convert the binary hash into a string.
  return tResult
end



function Hash:_parse_hashes(strText, strSourceURL)
  -- Be optimistic.
  local tResult = true

  -- Collect all known hashes in this table.
  local atHashes = {}
  local uiFoundHashes = 0

  -- Loop over all lines in the string.
  local uiLineNumber = 0
  for strLine in self.pl.stringx.lines(strText) do
    -- Count the line numbers.
    uiLineNumber = uiLineNumber + 1

    -- Remove whitespace from the start and the end of the line.
    local strLineStripped = self.pl.stringx.strip(strLine)

    -- Skip empty lines or comments.
    if string.len(strLineStripped)~=0 and string.sub(strLineStripped, 1, 1)~='#' then
      local strID, strHash = string.match(strLineStripped, '^([A-Z0-9-_]+):([0-9a-fA-F]+)$')
      if strID==nil then
        self.tLog.error('%s line %d: Malformed line "%s".', strSourceURL, uiLineNumber, strLine)
        tResult = nil
        break

      else
        -- Is this a known HASH ID?
        local tHashID
        if self.mhash==nil then
          tHashID = self.atCliHashes[strID]
        else
          tHashID = self.atMhashHashes[strID]
        end
        if tHashID==nil then
          -- NOTE: this is no error as older versions should be able to use more recent hash files.
          self.tLog.warning('%s line %d: Ignoring unknown hash ID "%s".', strSourceURL, uiLineNumber, strID)

        -- Was this HASH ID already processed in another line?
        elseif atHashes[strID]~=nil then
          self.tLog.error('%s line %d: Hash ID "%s" defined twice.', strSourceURL, uiLineNumber, strID)
          tResult = nil
          break

        else
          -- The size of the hash string must be a multiple of 2.
          local uiHashSize = string.len(strHash)
          if math.mod(uiHashSize, 2)~=0 then
            self.tLog.error('%s line %d: The length of the hash sum is not a multiple of 2.', strSourceURL, uiLineNumber)
            tResult = nil
            break
          else
            -- Check the size of the hash.
            local uiExpectedSize
            if self.mhash==nil then
              uiExpectedSize = self.auiHashSizes[strID]
            else
              uiExpectedSize = self.mhash.get_block_size(tHashID)
            end
            if (uiExpectedSize*2)~=uiHashSize then
              self.tLog.error('%s line %d: Invalid hash size for ID "%s", expected %d, got %d.', strSourceURL, uiLineNumber, strID, uiExpectedSize*2, uiHashSize)
              tResult = nil
              break
            else
              -- The hash is OK.
              atHashes[strID] = string.lower(strHash)
              self.tLog.debug('%s: Found hash ID "%s".', strSourceURL, strID)
              uiFoundHashes = uiFoundHashes + 1
            end
          end
        end
      end
    end
  end

  -- Remove all hashes if an error occured.
  if tResult==nil then
    atHashes = nil
  elseif uiFoundHashes==0 then
    self.tLog.error('%s: No valid hashes found.', strSourceURL)
    atHashes = nil
  end

  return atHashes
end



-- Pick the "best" hash function from the list of available ones.
-- The quality is determined by the table self.atHashQuality .
function Hash:_pick_best_hash(atAvailableHashes)
  local uiBestQuality = -1
  local strBestHashName = nil
  local strBestHashValue = nil

  for strHashName,strHashValue in pairs(atAvailableHashes) do
    local uiQuality = self.atHashQuality[strHashName]
    if uiQuality>uiBestQuality then
      uiBestQuality = uiQuality
      strBestHashName = strHashName
      strBestHashValue = strHashValue
    end
  end

  return strBestHashName, strBestHashValue
end



function Hash:check_string(strData, strHash, strDataURL, strHashURL)
  local tResult = nil


  -- Parse the HASH file.
  local atHashes = self:_parse_hashes(strHash, strHashURL)
  if atHashes~=nil then
    -- Pick the best HASH.
    local strHashName, strExpectedHash = self:_pick_best_hash(atHashes)
    if strHashName==nil then
      self.tLog.error('No useable hash found.')
    else
      -- Get the hash sum of the data.
      local strLocalHash = self:_get_hash_for_string(strData, strHashName)

      -- Compare the HASH sums.
      if strExpectedHash~=strLocalHash then
        self.tLog.error('The %s hash for "%s" does not match.', strHashName, strDataURL)
        self.tLog.error('The locally generated %s hash for %s is %s .', strHashName, strDataURL, strLocalHash)
        self.tLog.error('The expected %s hash read from %s is %s .', strHashName, strHashURL, strExpectedHash)
      else
        -- The hash sums match.
        self.tLog.debug('The %s hash for "%s" matches.', strHashName, strDataURL)
        tResult = true
      end
    end
  end

  return tResult
end



function Hash:check_file(strPath, strHash, strHashURL)
  local tResult = nil


  -- Parse the HASH file.
  local atHashes = self:_parse_hashes(strHash, strHashURL)
  if atHashes~=nil then
    -- Pick the best HASH.
    local strHashName, strExpectedHash = self:_pick_best_hash(atHashes)
    if strHashName==nil then
      self.tLog.error('No useable hash found.')
    else
      -- Get the hash sum of the data.
      local strLocalHash = self:_get_hash_for_file(strPath, strHashName)

      -- Compare the HASH sums.
      if strExpectedHash~=strLocalHash then
        self.tLog.error('The %s hash for "%s" does not match.', strHashName, strPath)
        self.tLog.error('The locally generated %s hash for %s is %s .', strHashName, strPath, strLocalHash)
        self.tLog.error('The expected %s hash read from %s is %s .', strHashName, strHashURL, strExpectedHash)
      else
        -- The hash sums match.
        self.tLog.debug('The %s hash for "%s" matches.', strHashName, strPath)
        tResult = true
      end
    end
  end

  return tResult
end



function Hash:generate_hashes_for_string(strData)
  local atHashes = {}

  -- Loop over all known hashes.
  for _,strHashID in ipairs(self.atHashGenerateOrder) do
    local strHash = self:_get_hash_for_string(strData, strHashID)
    local strHashFormat = string.format("%s:%s", strHashID, strHash)
    table.insert(atHashes, strHashFormat)
  end

  return table.concat(atHashes, '\n')
end



function Hash:generate_hashes_for_file(strPath)
  local tResult = true
  local atHashes = {}

  -- Loop over all known hashes.
  for _,strHashID in ipairs(self.atHashGenerateOrder) do
    local strHash = self:_get_hash_for_file(strPath, strHashID)
    if strHash==nil then
      tResult = nil
      break
    else
      local strHashFormat = string.format("%s:%s", strHashID, strHash)
      table.insert(atHashes, strHashFormat)
    end
  end

  if tResult==true then
    tResult = table.concat(atHashes, '\n')
  end

  return tResult
end



return Hash
