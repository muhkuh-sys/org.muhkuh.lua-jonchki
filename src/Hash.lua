local hash = {}

hash.tMhash = require("mhash")


function hash:check_sha1(strPath, strSha1)
  local fOk = true
  local tResult = nil


  -- Create a new MHash state for SHA1.
  local tState = self.tMhash.mhash_state()
  tState:init(self.tMhash.MHASH_SHA1)

  -- Open the file and read it in chunks.
  tFile = io.open(strPath, "rb")
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
    strHashBin = tState:hash_end()

    tFile:close()

    -- Convert the binary hash into a string.
    local aHashHex = {}
    for iCnt=1,string.len(strHashBin) do
      table.insert(aHashHex, string.format("%02x", string.byte(strHashBin, iCnt)))
    end
    local strHashHex = table.concat(aHashHex)

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


return hash
