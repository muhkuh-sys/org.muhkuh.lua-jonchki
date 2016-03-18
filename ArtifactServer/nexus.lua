

local artifact_server = {}

artifact_server.tLxp = require("lxp")
artifact_server.tHash = require("Hash")


--- Initialize the artifact server object.
-- The internal luasocket states are created. The base URL and the POM group for the
-- Nexus server is set.
-- @param strNexusBase The URL of the Nexus server.
-- @param strGroup     The group to operate on.
function artifact_server:init(atConfiguration)
  local fOk = true
  local astrMsg = {}

	self.tHttp = require("socket.http")
	self.tLtn12 = require("ltn12")

  for strKey,tValue in pairs(atConfiguration) do
    if strKey=="strNexusBaseURL" then
      self.strNexusBase = tValue
    elseif strKey=="strGroup" then
      self.strGroup = tValue
    else
      table.insert(astrMsg, string.format("Unknown key: '%s'.", strKey))
      fOk = false
    end
  end

  return fOk, table.concat(astrMsg, " ")
end



--- Get a part of a search result from the server.
-- This function can search for a sepcific artifact in the group or
-- it can retrieve a list of all artifacts in the group. The group is specified with the "init" call.
-- Note that Nexus servers refuse to send huge results in one go. The results are tuncated in this
-- case, for example to the first 200 entries. Use the "uiFrom" and "uiCount" parameters to fetch
-- large results in smaller pieces.
-- @param strArtifact The name of the artifact to search for or nil to get all artifacts in the group.
-- @param uiFrom      The offset of the first result. This is 0 based.
-- @param uiCount     The number of results to fetch from the server starting at uiFrom.
function artifact_server:get_search_chunk(strArtifact, uiFrom, uiCount)
  local fOk = nil
  local strData = nil
  -- Collect the results in this array.
	local t = {}

	-- Create the URL.
	local strURL = self.strNexusBase .. "/service/local/lucene/search?g=" .. self.strGroup
	if strArtifact~=nil then
		strURL = strURL .. "&a=" .. strArtifact
	end
  strURL = strURL .. string.format("&from=%d&count=%d", uiFrom, uiCount)
	local s,r = self.tHttp.request{
		url = strURL,
		sink = self.tLtn12.sink.table(t)
	}

	if s==nil then
		fOk = nil
    strData = string.format("Failed to access nexus search engine at %s: %s", strURL, r)
  elseif r~=200 then
		fOk = nil
    strData = string.format("Failed to retrieve the nexus search result from %s: %d", strURL, r)
  else
    fOk = true
    strData = table.concat(t)
  end

	return fOk, strData
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function artifact_server.parseSearch_StartElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata

	table.insert(aLxpAttr.atCurrentPath, strName)
	aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")

	if aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact" then
		aLxpAttr.atCurrentArtifact = {}
    aLxpAttr.atCurrentArtifact.repositoryId = ""
		aLxpAttr.atCurrentArtifact.atLinks = {}
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/artifactHits/artifactHit/artifactLinks/artifactLink" then
		aLxpAttr.atCurrentArtifactLink = {}
		aLxpAttr.atCurrentArtifactLink.classifier = ""
		aLxpAttr.atCurrentArtifactLink.extension = ""
	end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function artifact_server.parseSearch_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata

	if aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact" then
		table.insert(aLxpAttr.atArtifacts, aLxpAttr.atCurrentArtifact)
		aLxpAttr.atCurrentArtifact = {}
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/artifactHits/artifactHit/artifactLinks/artifactLink" then
		table.insert(aLxpAttr.atCurrentArtifact.atLinks, aLxpAttr.atCurrentArtifactLink)
		aLxpAttr.atCurrentArtifactLink = nil
	end

	table.remove(aLxpAttr.atCurrentPath)
	aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function artifact_server.parseSearch_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata

	if aLxpAttr.strCurrentPath=="/searchNGResponse/totalCount" then
		aLxpAttr.uiTotalCount = tonumber(strData)
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/from" then
		aLxpAttr.uiFrom = tonumber(strData)
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/count" then
		aLxpAttr.uiCount = tonumber(strData)
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/tooManyResults" then
		if string.lower(strData)=="true" then
			aLxpAttr.fTooManyResults = true
		else
			aLxpAttr.fTooManyResults = false
		end
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/groupId" then
		aLxpAttr.atCurrentArtifact.groupId = strData
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/artifactId" then
		aLxpAttr.atCurrentArtifact.artifactId = strData
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/version" then
		aLxpAttr.atCurrentArtifact.version = strData
  elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/artifactHits/artifactHit/repositoryId" then
    aLxpAttr.atCurrentArtifact.repositoryId = strData
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/artifactHits/artifactHit/artifactLinks/artifactLink/classifier" then
		aLxpAttr.atCurrentArtifactLink.classifier = strData
	elseif aLxpAttr.strCurrentPath=="/searchNGResponse/data/artifact/artifactHits/artifactHit/artifactLinks/artifactLink/extension" then
		aLxpAttr.atCurrentArtifactLink.extension = strData
	end
end



--- Parse the XML result of a search query.
-- The XML data is parsed with the expat parser. The following fields are extracted:
--  * totalCount: the total (i.e. not truncated) number of results for the query
--  * from:       the start offset in the total results. This can be '-1' for "not specified" or the parameter of the search query.
--  * count:      the number of requested results. This can be '-1' for "not specified" or the parameter of the search query.
--  * all artifacts with their G,A,V,C and E parameters.
-- @param strChunk       The XML response for the search query.
-- @param atArtifactList A table where all search reaults are collected.
function artifact_server:parse_search_chunk(strChunk, atArtifactList)
  local fOk = nil
  local tResult = nil
  -- Start with an empty artifact list is none provided.
  atArtifactList = atArtifactList or {}

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    uiTotalCount = nil,
    uiFrom = nil,
    uiCount = nil,
    fTooManyResults = nil,

    atCurrentArtifact = nil,
    atCurrentArtifactLink = nil,
    atArtifacts = atArtifactList
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.parseSearch_StartElement
  aLxpCallbacks.EndElement    = self.parseSearch_EndElement
  aLxpCallbacks.CharacterData = self.parseSearch_CharacterData
  aLxpCallbacks.userdata      = aLxpAttr

  local tParser = self.tLxp.new(aLxpCallbacks)
  local tParseResult,strMsg,uiLine,uiCol,uiPos = tParser:parse(strChunk)
  if tResult~=nil then
    tParseResult,strMsg,uiLine,uiCol,uiPos = tParser:parse()
  end
  tParser:close()

  if tParseResult~=nil then
    fOk = true
    tResult = aLxpAttr
  else
    fOk = false
    tResult = string.format("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
  end

  return fOk, tResult
end



--- Search the Nexus server for an artifact or all return all artifacts in the group.
-- If the parameter "strArtifact" is set, search for the artifact.
-- Otherwise return all artifacts in the group.
-- The function handles truncated responses and requests the data in small pieces.
-- @param strArtifact The name of the artifact or "nil" to search the complete group.
-- @return The first value is true on success or false if an error occured.
-- @return On success a table with the search results is returned. On error this is a descriptive string.
function artifact_server:search(strArtifact)
  local fOk = true
  local tResult = nil
  local atArtifacts = {}
  local uiOffset = 0
  local uiCount = 200
  repeat
    local fOk,strChunk = self:get_search_chunk(strArtifact, uiOffset, uiCount)
    if fOk~=true then
      -- Return the error message.
      tResult = strChunk
      break
    end

    local fOk,tParsed = self:parse_search_chunk(strChunk, atArtifacts)
    if fOk~=true then
      -- Return the error message.
      tResult = tParsed
      break
    end

    -- Check the result for valid data.
    if tParsed.uiTotalCount==nil or tParsed.uiFrom==nil or tParsed.uiCount==nil or tParsed.fTooManyResults==nil then
      fOk = false
      tResult = "The server response has an invalid format. One or more of the following fields are missing: totalCount, from, count tooManyResults"
      break
    end

    -- Get the next offset.
    uiOffset = tParsed.uiFrom + tParsed.uiCount
  until uiOffset>=tParsed.uiTotalCount

  if fOk==true then
    tResult = atArtifacts
  end

  return fOk, tResult
end



function artifact_server:get_resolve_data(atArtifact, strClassifier, strExtension)
  local fOk = nil
  local strData = nil
  -- Collect the results in this array.
	local t = {}


	-- Create the URL.
  local strURL = string.format("%s/service/local/artifact/maven/resolve?g=%s&a=%s&v=%s&r=%s&c=%s&e=%s", self.strNexusBase, atArtifact.groupId, atArtifact.artifactId, atArtifact.version, atArtifact.repositoryId, strClassifier, strExtension)
	local s,r = self.tHttp.request{
		url = strURL,
		sink = self.tLtn12.sink.table(t)
	}

	if s==nil then
		fOk = nil
    strData = string.format("Failed to access nexus search engine at %s: %s", strURL, r)
  elseif r~=200 then
		fOk = nil
    strData = string.format("Failed to retrieve the nexus search result from %s: %d", strURL, r)
  else
    fOk = true
    strData = table.concat(t)
  end

	return fOk, strData
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function artifact_server.parseResolve_StartElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata

	table.insert(aLxpAttr.atCurrentPath, strName)
	aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function artifact_server.parseResolve_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata

	table.remove(aLxpAttr.atCurrentPath)
	aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function artifact_server.parseResolve_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata

	if aLxpAttr.strCurrentPath=="/artifact-resolution/data/sha1" then
		aLxpAttr.strSha1 = strData
	elseif aLxpAttr.strCurrentPath=="/artifact-resolution/data/repositoryPath" then
		aLxpAttr.strRepositoryPath = strData
	end
end



function artifact_server:parse_resolve_data(strData)
  local fOk = nil
  local tResult = nil


  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    strSha1 = nil,
    strRepositoryPath = nil
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.parseResolve_StartElement
  aLxpCallbacks.EndElement    = self.parseResolve_EndElement
  aLxpCallbacks.CharacterData = self.parseResolve_CharacterData
  aLxpCallbacks.userdata      = aLxpAttr

  local tParser = self.tLxp.new(aLxpCallbacks)
  local tParseResult,strMsg,uiLine,uiCol,uiPos = tParser:parse(strData)
  if tResult~=nil then
    tParseResult,strMsg,uiLine,uiCol,uiPos = tParser:parse()
  end
  tParser:close()

  if tParseResult~=nil then
    fOk = true
    tResult = aLxpAttr
  else
    fOk = false
    tResult = string.format("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
  end

  return fOk,tResult
end



function artifact_server:download_artifact(atArtifact, strClassifier, strExtension)
  local fOk = nil
  local tResult = nil


  local strOutputFileName = "/tmp/test.bin"

  -- Open the output file.
  local tFile = io.open(strOutputFileName, "wb")
  if tFile==nil then
    fOk = false
    tResult = "Failed to open the output file"
  else
    -- Create the URL.
    local strURL = string.format("%s/service/local/artifact/maven/content?g=%s&a=%s&v=%s&r=%s&c=%s&e=%s", self.strNexusBase, atArtifact.groupId, atArtifact.artifactId, atArtifact.version, atArtifact.repositoryId, strClassifier, strExtension)
    local s,r = self.tHttp.request{
      url = strURL,
      sink = self.tLtn12.sink.file(tFile)
    }

    if s==nil then
      fOk = false
      tResult = string.format("Failed to access nexus search engine at %s: %s", strURL, r)
    elseif r~=200 then
      fOk = false
      tResult = string.format("Failed to retrieve the nexus search result from %s: %d", strURL, r)
    else
      fOk = true
      tResult = strOutputFileName
    end
  end

	return fOk, tResult
end



function artifact_server:download(atArtifact, strClassifier, strExtension)
  local fOk = true
  local tResult = nil
  -- Collect the results in this array.
	local t = {}


  -- Get the resolve data.
  fOk,tResult = self:get_resolve_data(atArtifact, strClassifier, strExtension)
  if fOk==true then
    local strResolveData = tResult

    fOk,tResult = self:parse_resolve_data(strResolveData)
    if fOk==true then
      local tResolveData = tResult
      -- Check if all fields are set.
      if tResolveData.strSha1==nil or tResolveData.strRepositoryPath==nil then
        fOk = false
        tResult = "Invalid result from the server, no sha1 or repository path!"
      else
        print("Sha1: " .. tResolveData.strSha1)
        print("Path: " .. tResolveData.strRepositoryPath)

        -- Write the SHA1 sum to the local repository.
        -- TODO...

        -- Download the artifact.
        fOk,tResult = self:download_artifact(atArtifact, strClassifier, strExtension)
        if fOk==true then
          local strLocalArtifactFileName = tResult
          -- Check the hash sum of the file.
          fOk, tResult = self.tHash:check_sha1(strLocalArtifactFileName, tResolveData.strSha1)
          if fOk==true then
            print("Download OK!")
          else
            -- Remove the SHA1 sum and the artifact.
            os.remove(strLocalArtifactFileName)
            -- TODO: remove SHA1 file
          end
        end
      end
    end
  end

	return fOk, tResult
end



return artifact_server
