local hash = {}


-- Get the mhash plugin for the hash algorithms.
hash.mhash = require("mhash")



function hash:bin_to_hex(strBin)
  local aHashHex = {}
  for iCnt=1,string.len(strBin) do
    table.insert(aHashHex, string.format("%02x", string.byte(strBin, iCnt)))
  end
  local strHashHex = table.concat(aHashHex)
end



function hash:check_sha1(strPath, strSha1)
  local fOk = true
  local tResult = nil


  -- Create a new MHash state for SHA1.
  local tState = self.mhash.mhash_state()
  tState:init(self.mhash.MHASH_SHA1)

  -- Open the file and read it in chunks.
  local tFile = io.open(strPath, "rb")
  if tFile==nil then
    fOk = false
    tResult = string.format("Failed to open the file for reading: %s", strPath)
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
    local strHashHex = self:bin_to_hex(strHashBin)

    local strHashExpected = string.lower(strSha1)
    if strHashExpected==strHashHex then
      print("Hash OK!")
      fOk = true
      tResult = nil
    else
      fOk = false
      tResult = string.format("The hash does not match!\nExpected: %s\nRead:    %s", strHashExpected, strHashHex)
    end
  end

  return fOk,tResult
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



function hash:check_sha1_string(strData, strSha1)
  local fOk = true
  local tResult = nil


  -- Convert the binary hash into a string.
  local strHash = self:get_sha1_string(strData)

  local strHashExpected = string.lower(strSha1)
  if strHashExpected==strHashHex then
    fOk = true
    tResult = nil
  else
    fOk = false
    tResult = string.format("The hash does not match!\nExpected: %s\nRead:    %s", strHashExpected, strHashHex)
  end

  return fOk,tResult
end


return hash
