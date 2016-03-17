local tArtifactServer = require("ArtifactServer")



function printTree1(k, v, iIndent)
  local strIndent = string.rep(" ", iIndent)

  if type(v)=="table" then
    print(string.format("%s%s = {", strIndent, tostring(k)))
    for k1,v1 in pairs(v) do
      printTree1(k1, v1, iIndent + 2)
    end
    print(string.format("%s}", strIndent))
  else
    print(string.format("%s%s = %s", strIndent, tostring(k), tostring(v)))
  end
end

function printTree(v)
  printTree1("", v, 0)
end


local atAttr = {}
atAttr.strNexusBaseURL = "http://nexus.netx01"
atAttr.strGroup = "com.hilscher.muhkuh.tools"
--atAttr.strGroup = "com.hilscher.secmem_data"
local fOk,strError = tArtifactServer:init("nexus", atAttr)
if fOk~=true then
  error("Failed to initialize the driver: " .. strError)
end

--a,b = nexus_search:search("crypto_cli_public")
local fOk,atArtifacts = tArtifactServer:resolve("crypto_cli_public", "1.2.0")
print(fOk,atArtifacts)
if fOk~=true then
	error("The search failed: " .. atArtifacts)
end

print("Total: " .. #atArtifacts)

for iCnt,atArtifact in ipairs(atArtifacts) do
	print("  " .. atArtifact.groupId)
	print("  " .. atArtifact.artifactId)
	print("  " .. atArtifact.version)
	for iCnt2,atLink in ipairs(atArtifact.atLinks) do
		print("    " .. atLink.classifier .. ":" .. atLink.extension)
	end
	print("-----------------------")
end


