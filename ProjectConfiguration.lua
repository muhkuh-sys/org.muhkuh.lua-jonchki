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
    tCurrentRepository.strID = atAttributes['id']
    tCurrentRepository.strType = atAttributes['type']
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
    tCurrentRepository.strConfig = nil
    tCurrentRepository.strArtifact = nil
    
    aLxpAttr.tCurrentRepository = tCurrentRepository
    
  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/config" then
    tCurrentRepository.strConfig = atAttributes['pattern']

  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/artifact" then
    tCurrentRepository.strArtifact = atAttributes['pattern']

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

  if aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository/config" then
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
