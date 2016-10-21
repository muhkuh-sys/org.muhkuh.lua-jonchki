--- The project configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local ProjectConfiguration = class()



function ProjectConfiguration:_init()
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to parse the XML data.
  self.lxp = require 'lxp'

  -- There is no configuration yet.
  self.atRepositories = nil
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function ProjectConfiguration.parseCfg_StartElement(tParser, strName, atAttributes)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()
  local tCurrentRepository = aLxpAttr.tCurrentRepository

  table.insert(aLxpAttr.atCurrentPath, strName)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")

  if aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository" then
    local tCurrentRepository = {}
    local strID = atAttributes['id']
    if strID==nil or strID=='' then
      error(string.format('Error in line %d, col %d: missing "id".', iPosLine, iPosColumn))
    end
    -- Is the ID already defined?
    for uiCnt, tRepo in pairs(aLxpAttr.atRepositories) do
      if tRepo.strID==strID then
        error(string.format('Error in line %d, col %d: the ID "%s" is already used.', iPosLine, iPosColumn, strID))
      end
    end
    tCurrentRepository.strID = strID
    local strType = atAttributes['type']
    if strType==nil or strType=='' then
      error(string.format('Error in line %d, col %d: missing "type".', iPosLine, iPosColumn))
    end
    tCurrentRepository.strType = strType
    local strCacheable = atAttributes['cacheable']
    local fCacheable 
    if strCacheable=='0' or string.lower(strCacheable)=='false' or string.lower(strCacheable)=='no' then
      fCacheable = false
    elseif strCacheable=='1' or string.lower(strCacheable)=='true' or string.lower(strCacheable)=='yes' then
      fCacheable = true
    else
      error(string.format('Error in line %d, col %d: invalid value for "cacheable": "%s".', iPosLine, iPosColumn, strCacheable))
    end
    tCurrentRepository.cacheable = fCacheable
    tCurrentRepository.strRoot = nil
    tCurrentRepository.strVersions = nil
    tCurrentRepository.strConfig = nil
    tCurrentRepository.strArtifact = nil

    aLxpAttr.tCurrentRepository = tCurrentRepository
  end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function ProjectConfiguration.parseCfg_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()
  local tCurrentRepository = aLxpAttr.tCurrentRepository

  if aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository" then
    -- Check if all data is present.
    local astrMissing = {}
    if tCurrentRepository.strID==nil then
      table.insert(astrMissing, 'id')
    end
    if tCurrentRepository.strType==nil then
      table.insert(astrMissing, 'type')
    end
    if tCurrentRepository.strRoot==nil then
      table.insert(astrMissing, 'root')
    end
    if tCurrentRepository.strVersions==nil then
      table.insert(astrMissing, 'versions')
    end
    if tCurrentRepository.strConfig==nil then
      table.insert(astrMissing, 'config')
    end
    if tCurrentRepository.strArtifact==nil then
      table.insert(astrMissing, 'artifact')
    end
    if #astrMissing ~= 0 then
      error(string.format('Error in line %d, col %d: missing items: %s', iPosLine, iPosColumn, table.concat(astrMissing)))
    end

    -- All data is present.
    table.insert(aLxpAttr.atRepositories, tCurrentRepository)
    aLxpAttr.tCurrentRepository = nil
  end

  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function ProjectConfiguration.parseCfg_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata
  local tCurrentRepository = aLxpAttr.tCurrentRepository

  if aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/root" then
    tCurrentRepository.strRoot = strData
  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/versions" then
    tCurrentRepository.strVersions = strData
  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/config" then
    tCurrentRepository.strConfig = strData
  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/artifact" then
    tCurrentRepository.strArtifact = strData
  end
end



function ProjectConfiguration:parse_configuration(strConfigurationFilename)
  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    error('The function "parse_configuration" expects a filename as a parameter.')
  end

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    tCurrentRepository = nil,
    atRepositories = {}
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.parseCfg_StartElement
  aLxpCallbacks.EndElement    = self.parseCfg_EndElement
  aLxpCallbacks.CharacterData = self.parseCfg_CharacterData
  aLxpCallbacks.userdata      = aLxpAttr

  local tParser = self.lxp.new(aLxpCallbacks)

  -- Read the complete file.
  local strXmlText, strError = self.pl.utils.readfile(strConfigurationFilename, false)
  if strXmlText==nil then
    error(string.format('Error reading the configuration file: %s', strError))
  end

  local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strXmlText)
  if tParseResult~=nil then
    tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
  end
  tParser:close()

  if tParseResult~=nil then
    self.atRepositories = aLxpCallbacks.userdata.atRepositories
  else
    error(string.format("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos))
  end
end



function ProjectConfiguration:toxml(tXml)
  tXml:addtag('jonchkicfg')

  local atRepositories = self.atRepositories
  if atRepositories~=nil then
    tXml:addtag('repositories')

    -- Loop over all repositories.
    for _, tRepository in pairs(self.atRepositories) do
      -- Create the "repository" node with the attributes "id", "type" and "cacheable".
      local tAttributes = {
        ['id'] = tRepository.strID,
        ['type'] = tRepository.strType,
        ['cacheable'] = tostring(tRepository.cacheable)
      }
      tXml:addtag('repository', tAttributes)

      -- Create the "root" node.
      tXml:addtag('root')
      tXml:text(tRepository.strRoot)
      tXml:up()

      -- Create the "versions" node.
      tXml:addtag('versions')
      tXml:text(tRepository.strVersions)
      tXml:up()

      -- Create the "config" node.
      tXml:addtag('config')
      tXml:text(tRepository.strConfig)
      tXml:up()

      -- Create the "artifact" node.
      tXml:addtag('artifact')
      tXml:text(tRepository.strArtifact)
      tXml:up()

      tXml:up()
    end

    tXml:up()
  end

  tXml:up()
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function ProjectConfiguration:__tostring()
  local strCfg = nil

  if self.atRepositories==nil then
    strCfg = 'ProjectConfiguration()'
  else
    strCfg = self.pl.pretty.write(self.atRepositories)
  end

  return strCfg
end


return ProjectConfiguration
