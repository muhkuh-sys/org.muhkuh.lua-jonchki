--- The artifact configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local ArtifactConfiguration = class()



function ArtifactConfiguration:_init()
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to parse the XML data.
  self.lxp = require 'lxp'

  self.Version = require 'Version'

  -- There is no configuration yet.
  self.tVersion = nil
  self.tInfo = nil
  self.atDependencies = nil
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function ArtifactConfiguration.parseCfg_StartElement(tParser, strName, atAttributes)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()

  table.insert(aLxpAttr.atCurrentPath, strName)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")

  if aLxpAttr.strCurrentPath=='/jonchki-artifact' then
    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      error(string.format('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn))
    end
    local tVersion = aLxpAttr.Version()
    local fOk = tVersion:set(strVersion)
    if fOk~=true then
      error(string.format('Error in line %d, col %d: invalid "version".', iPosLine, iPosColumn))
    end
    aLxpAttr.tVersion = tVersion
    
  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/info' then
    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      error(string.format('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn))
    end
    aLxpAttr.tInfo.strGroup = strGroup

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      error(string.format('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn))
    end
    aLxpAttr.tInfo.strArtifact = strArtifact

    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      error(string.format('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn))
    end
    local tVersion = aLxpAttr.Version()
    local fOk = tVersion:set(strVersion)
    if fOk~=true then
      error(string.format('Error in line %d, col %d: invalid "version".', iPosLine, iPosColumn))
    end
    aLxpAttr.tInfo.tVersion = tVersion

    local strVcsId = atAttributes['vcs-id']
    if strVcsId==nil or strVcsId=='' then
      error(string.format('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn))
    end
    aLxpAttr.tInfo.strVcsId = strVcsId

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/dependencies/dependency' then
    local tDependency = {}
    
    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      error(string.format('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn))
    end
    tDependency.strGroup = strGroup

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      error(string.format('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn))
    end
    tDependency.strArtifact = strArtifact

    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      error(string.format('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn))
    end
    local tVersion = aLxpAttr.Version()
    local fOk = tVersion:set(strVersion)
    if fOk~=true then
      error(string.format('Error in line %d, col %d: invalid "version".', iPosLine, iPosColumn))
    end
    tDependency.tVersion = tVersion
    
    table.insert(aLxpAttr.atDependencies, tDependency)
  end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function ArtifactConfiguration.parseCfg_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()
  local tCurrentRepository = aLxpAttr.tCurrentRepository

  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



function ArtifactConfiguration:parse_configuration(strConfigurationFilename)
  local tResult = nil
  local strError = ''


  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    error('The function "parse_configuration" expects a filename as a parameter.')
  end

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    Version = self.Version,
    tVersion = nil,
    tInfo = {},
    atDependencies = {}
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.parseCfg_StartElement
  aLxpCallbacks.EndElement    = self.parseCfg_EndElement
  aLxpCallbacks.userdata      = aLxpAttr

  local tParser = self.lxp.new(aLxpCallbacks)

  -- Read the complete file.
  local strXmlText, strMsg = self.pl.utils.readfile(strConfigurationFilename, false)
  if strXmlText==nil then
    strError = string.format('Error reading the configuration file: %s', strMsg)
  else
    local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strXmlText)
    if tParseResult~=nil then
      tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
    end
    tParser:close()

    if tParseResult==nil then
      strError = string.format("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
    else
      self.tVersion = aLxpCallbacks.userdata.tVersion
      self.tInfo = aLxpCallbacks.userdata.tInfo
      self.atDependencies = aLxpCallbacks.userdata.atDependencies

      tResult = true
    end
  end

  return tResult, strError
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function ArtifactConfiguration:__tostring()
  local astrRepr = {}
  table.insert(astrRepr, 'ArtifactConfiguration(')
  if self.tVersion==nil then
    table.insert(astrRepr, '  no version available')
  else
    table.insert(astrRepr, string.format('  version: %s', tostring(self.tVersion)))
  end

  if self.tInfo==nil then
    table.insert(astrRepr, '  no info block available')
  else
    table.insert(astrRepr, '  info:')
    table.insert(astrRepr, string.format('    group: %s', self.tInfo.strGroup))
    table.insert(astrRepr, string.format('    artifact: %s', self.tInfo.strArtifact))
    table.insert(astrRepr, string.format('    version: %s', tostring(self.tInfo.tVersion)))
    table.insert(astrRepr, string.format('    vcs-id: %s', self.tInfo.strVcsId))
  end

  if self.atDependencies==nil then
    table.insert(astrRepr, '  no dependencies available')
  else
    table.insert(astrRepr, string.format('  dependencies: %d', #self.atDependencies))
    for uiCnt,tAttr in pairs(self.atDependencies) do
      table.insert(astrRepr, string.format('  %d', uiCnt))
      table.insert(astrRepr, string.format('    group: %s', tAttr.strGroup))
      table.insert(astrRepr, string.format('    artifact: %s', tAttr.strArtifact))
      table.insert(astrRepr, string.format('    version: %s', tostring(tAttr.tVersion)))
      table.insert(astrRepr, '')
    end
  end
  table.insert(astrRepr, ')')
  
  return table.concat(astrRepr, '\n')
end


return ArtifactConfiguration
