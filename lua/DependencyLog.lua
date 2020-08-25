--- The artifact configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local DependencyLog = class()



function DependencyLog:_init(cLog)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to parse the XML data.
  self.lxp = require 'lxp'

  self.Version = require 'Version'

  -- Get the logger object from the system configuration.
  local tLogWriter = require 'log.writer.prefix'.new('[DependencyLog] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  -- There are no dependencies yet.
  self.atBuildDependencies = {}
  self.atDependencies = {}
end



function DependencyLog:addDependency(strGroup, strModule, strArtifact, tVersion)
  local tLog = self.tLog

  -- If the version is a string, convert it to a version object.
  if type(tVersion)=='string' then
    local tVersionObject = self.Version()
    local tResult, strError = tVersionObject:set(tVersion)
    if tResult~=true then
      tLog.error('Failed to parse the version string "%s": %s', tostring(tVersion), strError)
      error('Failed to parse the version string.')
    end
    tVersion = tVersionObject
  end

  local tDependency = {
    strGroup = strGroup,
    strModule = strModule,
    strArtifact = strArtifact,
    tVersion = tVersion
  }
  table.insert(self.atDependencies, tDependency)
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function DependencyLog.parseCfg_StartElement(tParser, strName, atAttributes)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn = tParser:pos()

  table.insert(aLxpAttr.atCurrentPath, strName)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")

  if aLxpAttr.strCurrentPath=='/dependency-log/dependencies/build-dependency' then
    local tDependency = {}

    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn)
    end
    tDependency.strGroup = strGroup

    local strModule = atAttributes['module']
    if strModule==nil or strModule=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "module".', iPosLine, iPosColumn)
    end
    tDependency.strModule = strModule

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
    end
    tDependency.strArtifact = strArtifact

    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn)
    end
    local tVersion = aLxpAttr.Version()
    local tResult, strError = tVersion:set(strVersion)
    if tResult~=true then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: invalid "version": %s', iPosLine, iPosColumn, strError)
    end
    tDependency.tVersion = tVersion

    table.insert(aLxpAttr.atBuildDependencies, tDependency)

  elseif aLxpAttr.strCurrentPath=='/dependency-log/dependencies/dependency' then
    local tDependency = {}

    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn)
    end
    tDependency.strGroup = strGroup

    local strModule = atAttributes['module']
    if strModule==nil or strModule=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "module".', iPosLine, iPosColumn)
    end
    tDependency.strModule = strModule

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
    end
    tDependency.strArtifact = strArtifact

    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn)
    end
    local tVersion = aLxpAttr.Version()
    local tResult, strError = tVersion:set(strVersion)
    if tResult~=true then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: invalid "version": %s', iPosLine, iPosColumn, strError)
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
function DependencyLog.parseCfg_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn, iPosAbs = tParser:pos()

  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function DependencyLog.parseCfg_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata

end



function DependencyLog:parse_configuration_file(strConfigurationFilename)
  local tResult = nil

  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    self.tLog.error('The function "parse_configuration_file" expects a filename as a parameter.')
  else
    local strXmlText, strMsg = self.pl.utils.readfile(strConfigurationFilename, false)
    if strXmlText==nil then
      self.tLog.error('Error reading the configuration file: %s', strMsg)
    else
      tResult = self:parse_configuration(strXmlText, strConfigurationFilename)
    end
  end

  return tResult
end



function DependencyLog:parse_configuration(strConfiguration, strSourceUrl)
  local tResult = nil


  -- Save the complete source and the source URL.
  self.strSource = strConfiguration
  self.strSourceUrl = strSourceUrl

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    Version = self.Version,
    tVersion = nil,
    tInfo = nil,
    atDependencies = {},

    strDefaultExtension = self.strDefaultExtension,
    tResult = true,
    tLog = self.tLog
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.parseCfg_StartElement
  aLxpCallbacks.EndElement    = self.parseCfg_EndElement
  aLxpCallbacks.CharacterData = self.parseCfg_CharacterData
  aLxpCallbacks.userdata      = aLxpAttr

  local tParser = self.lxp.new(aLxpCallbacks)

  local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strConfiguration)
  if tParseResult~=nil then
    tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
    if tParseResult~=nil then
      tParser:close()
    end
  end

  if tParseResult==nil then
    self.tLog.error('Failed to parse the dependency log "%s": %s in line %d, column %d, position %d.', strSourceUrl, strMsg, uiLine, uiCol, uiPos)
  elseif aLxpAttr.tResult~=true then
    self.tLog.error('Failed to parse the dependency log "%s"', strSourceUrl)
  else
    self.tVersion = aLxpCallbacks.userdata.tVersion
    self.tInfo = aLxpCallbacks.userdata.tInfo
    self.atDependencies = aLxpCallbacks.userdata.atDependencies
  end

  return tResult
end



function DependencyLog:writeToFile(strFile)
  local tLog = self.tLog
  local pl = self.pl

  -- Dump the complete file as XML.
  local astrData = {}
  table.insert(astrData, '<?xml version="1.0" encoding="UTF-8"?>')
  table.insert(astrData, '<dependency-log>')

  local atDependencies = self.atDependencies
  table.insert(astrData, '\t<dependencies>')
  for _,tAttr in pairs(atDependencies) do
    table.insert(astrData, string.format(
      '\t\t<dependency group="%s" module="%s" artifact="%s" version="%s"/>',
      tAttr.strGroup,
      tAttr.strModule,
      tAttr.strArtifact,
      tAttr.tVersion:get()
    ))
  end
  table.insert(astrData, '\t</dependencies>')

  local atBuildDependencies = self.atBuildDependencies
  table.insert(astrData, '\t<build-dependencies>')
  for _,tAttr in pairs(atBuildDependencies) do
    table.insert(astrData, string.format(
      '\t\t<dependency group="%s" module="%s" artifact="%s" version="%s"/>',
      tAttr.strGroup,
      tAttr.strModule,
      tAttr.strArtifact,
      tAttr.tVersion:get()
    ))
  end
  table.insert(astrData, '\t</build-dependencies>')

  table.insert(astrData, '</dependency-log>')

  tLog.debug('Writing the dependency log file to "%s".', strFile)
  local tResult, strError = pl.utils.writefile(strFile, table.concat(astrData, '\n'), false)
  if tResult==nil then
    tLog.error('Failed to open "%s" for writing: %s', strFile, strError)
    error('Failed to open the dependency log for writing.')
  end
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function DependencyLog:__tostring()
  local astrRepr = {}
  table.insert(astrRepr, 'DependencyLog(')

  local atDependencies = self.atDependencies
  table.insert(astrRepr, string.format('    dependencies: %d', #atDependencies))
  for uiCnt,tAttr in pairs(atDependencies) do
    table.insert(astrRepr, string.format('    %d:', uiCnt))
    table.insert(astrRepr, string.format('      group: %s', tAttr.strGroup))
    table.insert(astrRepr, string.format('      module: %s', tAttr.strModule))
    table.insert(astrRepr, string.format('      artifact: %s', tAttr.strArtifact))
    table.insert(astrRepr, string.format('      version: %s', tAttr.tVersion:get()))
    table.insert(astrRepr, '')
  end

  local atBuildDependencies = self.atBuildDependencies
  table.insert(astrRepr, string.format('    build dependencies: %d', #atBuildDependencies))
  for uiCnt,tAttr in pairs(atBuildDependencies) do
    table.insert(astrRepr, string.format('    %d:', uiCnt))
    table.insert(astrRepr, string.format('      group: %s', tAttr.strGroup))
    table.insert(astrRepr, string.format('      module: %s', tAttr.strModule))
    table.insert(astrRepr, string.format('      artifact: %s', tAttr.strArtifact))
    table.insert(astrRepr, string.format('      version: %s', tAttr.tVersion:get()))
    table.insert(astrRepr, '')
  end
  table.insert(astrRepr, ')')

  return table.concat(astrRepr, '\n')
end



function DependencyLog:getVersion(strGroup, strModule, strArtifact)
  local tVersion
  for _, tAttr in pairs(self.atDependencies) do
    if tAttr.strGroup==strGroup and tAttr.strModule==strModule and tAttr.strArtifact==strArtifact then
      tVersion = tAttr.tVersion
      break
    end
  end

  return tVersion
end


return DependencyLog
