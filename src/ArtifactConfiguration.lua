--- The artifact configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local ArtifactConfiguration = class()



function ArtifactConfiguration:_init(tLogger)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to parse the XML data.
  self.lxp = require 'lxp'

  self.Version = require 'Version'

  -- Get the logger object from the system configuration.
  self.tLogger = tLogger

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
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn)
    end
    local tVersion = aLxpAttr.Version()
    local fOk = tVersion:set(strVersion)
    if fOk~=true then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: invalid "version".', iPosLine, iPosColumn)
    end
    aLxpAttr.tVersion = tVersion

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/info' then
    -- Create a new "info" table.
    local tInfo = {}
    -- Set some default values for the optional elements.
    tInfo.strLicense = nil
    tInfo.strAuthorName = nil
    tInfo.strAuthorUrl = nil
    tInfo.strDescription = nil

    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn)
    end
    tInfo.strGroup = strGroup

    local strModule = atAttributes['module']
    if strModule==nil or strModule=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "module".', iPosLine, iPosColumn)
    end
    tInfo.strModule = strModule

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
    end
    tInfo.strArtifact = strArtifact

    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn)
    end
    local tVersion = aLxpAttr.Version()
    local fOk = tVersion:set(strVersion)
    if fOk~=true then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: invalid "version".', iPosLine, iPosColumn)
    end
    tInfo.tVersion = tVersion

    local strVcsId = atAttributes['vcs-id']
    if strVcsId==nil or strVcsId=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
    end
    tInfo.strVcsId = strVcsId

    aLxpAttr.tInfo = tInfo

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/info/license' then
    local tInfo = aLxpAttr.tInfo

    local strLicense = atAttributes['name']
    if strLicense~=nil and strLicense~='' then
      tInfo.strLicense = strLicense
    end

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/info/author' then
    local tInfo = aLxpAttr.tInfo

    local strAuthorName = atAttributes['name']
    if strAuthorName~=nil and strAuthorName~='' then
      tInfo.strAuthorName = strAuthorName
    end

    local strAuthorUrl = atAttributes['url']
    if strAuthorUrl~=nil and strAuthorUrl~='' then
      tInfo.strAuthorUrl = strAuthorUrl
    end

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/dependencies/dependency' then
    local tDependency = {}
    
    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn)
    end
    tDependency.strGroup = strGroup

    local strModule = atAttributes['module']
    if strModule==nil or strModule=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "module".', iPosLine, iPosColumn)
    end
    tDependency.strModule = strModule

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
    end
    tDependency.strArtifact = strArtifact

    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn)
    end
    local tVersion = aLxpAttr.Version()
    local fOk = tVersion:set(strVersion)
    if fOk~=true then
      aLxpAttr.tResult = nil
      self.tLogger:error('Error in line %d, col %d: invalid "version".', iPosLine, iPosColumn)
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

  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function ArtifactConfiguration.parseCfg_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata

  if aLxpAttr.strCurrentPath=="/jonchki-artifact/info/description" then
    aLxpAttr.tInfo.strDescription = strData
  end
end



function ArtifactConfiguration:parse_configuration_file(strConfigurationFilename)
  local tResult = nil

  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    self.tLogger:error('The function "parse_configuration" expects a filename as a parameter.')
  else
    local strXmlText, strMsg = self.pl.utils.readfile(strConfigurationFilename, false)
    if strXmlText==nil then
      self.tLogger:error('Error reading the configuration file: %s', strMsg)
    else
      tResult = self:parse_configuration(strXmlText)
    end
  end

  return tResult
end



function ArtifactConfiguration:parse_configuration(strConfiguration)
  local tResult = nil

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    Version = self.Version,
    tVersion = nil,
    tInfo = nil,
    atDependencies = {},

    tResult = true
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
  end
  tParser:close()

  if tParseResult==nil then
    self.tLogger:error("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
  elseif aLxpAttr.tResult~=true then
    self.tLogger:error('Failed to parse the configuration file "%s"', strConfiguration)
  else
    self.tVersion = aLxpCallbacks.userdata.tVersion
    self.tInfo = aLxpCallbacks.userdata.tInfo
    self.atDependencies = aLxpCallbacks.userdata.atDependencies

    local tResult = true
    if self.tVersion==nil then
      tResult = false
      self.tLogger:error('Failed to parse the artifact configuration "%s": No Version found!', strConfiguration)
    end
    if self.tInfo==nil then
      tResult = false
      self.tLogger:error('Failed to parse the artifact configuration "%s": No Info block found!', strConfiguration)
    end
    -- NOTE: the dependency block is optional.
  end

  return tResult
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function ArtifactConfiguration:__tostring()
  local astrRepr = {}
  table.insert(astrRepr, 'ArtifactConfiguration(')
  if self.tVersion==nil then
    table.insert(astrRepr, '  no version available')
  else
    table.insert(astrRepr, string.format('  version: %s', self.tVersion:get()))
  end

  if self.tInfo==nil then
    table.insert(astrRepr, '  no info block available')
  else
    table.insert(astrRepr, '  info:')
    table.insert(astrRepr, string.format('    group: %s', self.tInfo.strGroup))
    table.insert(astrRepr, string.format('    module: %s', self.tInfo.strModule))
    table.insert(astrRepr, string.format('    artifact: %s', self.tInfo.strArtifact))
    table.insert(astrRepr, string.format('    version: %s', self.tInfo.tVersion:get()))
    table.insert(astrRepr, string.format('    vcs-id: %s', self.tInfo.strVcsId))

    local strLicense = self.tInfo.strLicense
    if strLicense==nil then
      strLicense = 'no license specified'
    else
      strLicense = string.format('license: %s', strLicense)
    end
    table.insert(astrRepr, string.format('    %s', strLicense))

    local strAuthorName = self.tInfo.strAuthorName
    if strAuthorName==nil then
      strAuthorName = 'no author name specified'
    else
      strAuthorName = string.format('author name: %s', strAuthorName)
    end
    table.insert(astrRepr, string.format('    %s', strAuthorName))

    local strAuthorUrl = self.tInfo.strAuthorUrl
    if strAuthorUrl==nil then
      strAuthorUrl = 'no author url specified'
    else
      strAuthorUrl = string.format('author url: %s', strAuthorUrl)
    end
    table.insert(astrRepr, string.format('    %s', strAuthorUrl))

    local strDescription = self.tInfo.strDescription
    if strDescription==nil then
      strDescription = 'no description specified'
    else
      strDescription = string.format('description: %s', strDescription)
    end
    table.insert(astrRepr, string.format('    %s', strDescription))

  end

  if self.atDependencies==nil then
    table.insert(astrRepr, '  no dependencies available')
  else
    table.insert(astrRepr, string.format('  dependencies: %d', #self.atDependencies))
    for uiCnt,tAttr in pairs(self.atDependencies) do
      table.insert(astrRepr, string.format('  %d:', uiCnt))
      table.insert(astrRepr, string.format('    group: %s', tAttr.strGroup))
      table.insert(astrRepr, string.format('    module: %s', tAttr.strModule))
      table.insert(astrRepr, string.format('    artifact: %s', tAttr.strArtifact))
      table.insert(astrRepr, string.format('    version: %s', tAttr.tVersion:get()))
      table.insert(astrRepr, '')
    end
  end
  table.insert(astrRepr, ')')

  return table.concat(astrRepr, '\n')
end



function ArtifactConfiguration:toxml(tXml)
  local tAttr = {}
  if self.version~=nil then
    tAttr.version = self.tVersion:get()
  end
  tXml:addtag('jonchki-artifact', tAttr)

  -- Add the info node.
  if self.tInfo~=nil then
    local tAttr = {
      ['group'] = self.tInfo.strGroup,
      ['module'] = self.tInfo.strModule,
      ['artifact'] = self.tInfo.strArtifact,
      ['version'] = self.tInfo.tVersion:get(),
      ['vcs-id'] = self.tInfo.strVcsId
    }
    tXml:addtag('info', tAttr)

    local tAttr = {
      ['name'] = self.tInfo.strLicense,
    }
    tXml:addtag('license', tAttr)
    tXml:up()

    local tAttr = {
      ['name'] = self.tInfo.strAuthorName,
      ['url'] = self.tInfo.strAuthorName
    }
    tXml:addtag('author', tAttr)
    tXml:up()

    tXml:addtag('description')
    local strDescription = self.tInfo.strDescription
    if strDescription~=nil and strDescription~='' then
      tXml:text(strDescription)
    end
    tXml:up()

    tXml:up()
  end

  -- Add the dependencies.
  if self.atDependencies~=nil then
    tXml:addtag('dependencies')
      for _,tDependency in pairs(self.atDependencies) do
        local tAttr = {
          ['group'] = tDependency.strGroup,
          ['module'] = tDependency.strModule,
          ['artifact'] = tDependency.strArtifact,
          ['version'] = tDependency.tVersion:get()
        }
        tXml:addtag('dependency', tAttr)
        tXml:up()
      end
    tXml:up()
  end

  tXml:up()
end



return ArtifactConfiguration
