local hash = {}


-- Get the mhash plugin for the hash algorithms.
hash.mhash = require("mhash")



function hash:bin_to_hex(strBin)
  local aHashHex = {}
  for iCnt=1,string.len(strBin) do
    table.insert(aHashHex, string.format("%02x", string.byte(strBin, iCnt)))
  end
  return table.concat(aHashHex)
end



function hash:get_sha1_file(strPath)
  local tResult = nil
  local strError = nil

  -- Create a new MHash state for SHA1.
  local tState = self.mhash.mhash_state()
  tState:init(self.mhash.MHASH_SHA1)

  -- Open the file and read it in chunks.
  local tFile = io.open(strPath, "rb")
  if tFile==nil then
    tResult = nil
    strError = string.format("Failed to open the file for reading: %s", strPath)
  else
    repeat
      local tChunk = tFile:read(4096)
      if tChunk~=nil then
        tState:hash(tChunk)
      end
    until tChunk==nil
    tFile:close()

    local strHashBin = tState:hash_end()

    -- Convert the binary hash into a string.
    tResult = self:bin_to_hex(strHashBin)
  end

  return tResult, strError
end



function hash:get_sha1_string(strData, strSha1)
  -- Create a new MHash state for SHA1.
  local tState = self.mhash.mhash_state()
  tState:init(self.mhash.MHASH_SHA1)
  tState:hash(strData)
  local strHashBin = tState:hash_end()

  -- Convert the binary hash into a string.
  return self:bin_to_hex(strHashBin)
end



function hash:check_string(strData, strHash)
  local fOk = nil


  -- FIXME: For now assume the hash is SHA1. Use identifier instead.

  -- Create the SHA1 hash for the data.
  local strHashData = self:get_sha1_string(strData)

  -- Convert the expected hash to lowercase.
  local strHashExpected = string.lower(strHash)
  if strHashExpected==strHashData then
    fOk = true
  else
    fOk = false
    -- TODO: write both hashes to the logger.
  end

  return fOk
end



function hash:check_file(strPath, strHash)
  local fOk = nil


  -- FIXME: For now assume the hash is SHA1. Use identifier instead.

  -- Create the SHA1 hash for the data.
  local strHashData = self:get_sha1_file(strPath)
  if strHashData==nil then
    -- FIXME: write an error message to the logger.
  else
    -- Convert the expected hash to lowercase.
    local strHashExpected = string.lower(strHash)
    if strHashExpected==strHashData then
      fOk = true
    else
      fOk = false
      -- TODO: write both hashes to the logger.
    end
  end

  return fOk
end


return hash
