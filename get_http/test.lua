local curl = require 'curl'
for k,v in pairs(curl) do
	print (k,v)
end

local strURL = 'http://127.0.0.1/jonchki/org/muhkuh/lua/lua-romloader/2.2.2/lua51-romloader-2.2.2.xml'


local function curl_download(atChunks, aucBuffer)
	table.insert(atChunks, aucBuffer)
	return 0
end

local function curl_progress(tDummy, ulDlTotal, ulDlNow, ulUpTotal, ulUpNow)
	print(string.format('%d%% (%d/%d)', ulDlTotal/ulDlNow*100, ulDlNow, ulDlTotal))
end

tCURL = curl.easy_init()

tCURL:setopt(tCURL.OPT_URL, strURL)

-- Collect the received data in a table.
local atChunks = {}
tCURL:setopt(tCURL.OPT_WRITEDATA, atChunks)
tCURL:setopt(tCURL.OPT_WRITEFUNCTION, curl_download)
tCURL:setopt(tCURL.OPT_PROGRESSDATA, nil)
tCURL:setopt(tCURL.OPT_PROGRESSFUNCTION, curl_progress)

tCURL:perform()
tCURL:close()

local strData = table.concat(atChunks)
print(strData)
