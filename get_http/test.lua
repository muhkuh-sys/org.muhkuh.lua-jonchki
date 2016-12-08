local curl = require 'curl'

local strURL = 'https://github.com/muhkuh-sys/org.muhkuh.tools-flasher/releases/download/v1.3.0/ivy.xml'

-- Collect the received data in a table.
local atChunks = {}
local sizTotal = 0

local function curl_download(aucBuffer)
	table.insert(atChunks, aucBuffer)
	local sizNew = string.len(aucBuffer)
  sizTotal = sizTotal + sizNew
  print(string.format('Dl %d.', sizTotal)) 
	return sizNew
end

tCURL = curl.easy_init()

tCURL:setopt(curl.OPT_FOLLOWLOCATION, 1)
tCURL:setopt(curl.OPT_URL, strURL)

--tCURL:setopt(curl.OPT_WRITEDATA, atChunks)
tCURL:setopt(curl.OPT_WRITEFUNCTION, curl_download)

tCURL:perform()
if tCURL.close~=nil then
  tCURL:close()
end

local strData = table.concat(atChunks)
print(strData)
