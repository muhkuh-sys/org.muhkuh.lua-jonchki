-- strFileName = 'sourceforge.html'
-- strFileName = 'bintray.html'
strFileName = 'github.html'


-- Read the complete file.
local tFile = io.open(strFileName, 'rt')
local strHtml = tFile:read('*a')
tFile:close()

-- Extract all links.
for strLink, strText in string.gmatch(strHtml, '<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
	-- Found a valid version?
	local fFound = false

	-- Extract the version from the text.
	local strVersion = string.match(strText, '[%d%.]+')
	if strVersion~=nil then
		-- Extract the versions from the link and compare them to the text version.
		-- NOTE: The link might have more matches as it can contain stuff like "lua51".
		for strVersionLink in string.gmatch(strLink, '[%d%.]+') do
			if strVersionLink==strVersion then
				fFound = true
				break
			end
		end
	end

	if fFound==true then
		print('******* Found version:', strVersion)
	end
end
