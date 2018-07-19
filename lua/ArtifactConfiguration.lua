--- The artifact configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local ArtifactConfiguration = class()



function ArtifactConfiguration:_init(cLog)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to parse the XML data.
  self.lxp = require 'lxp'

  self.Version = require 'Version'

  -- Get the logger object from the system configuration.
  local tLogWriter = require 'log.writer.prefix'.new('[ArtifactConfiguration] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  -- This is the default extension if it is not specified in the XML.
  self.strDefaultExtension = 'zip'

  -- Save the complete source to be able to reproduce the file.
  self.strSource = nil
  self.strSourceUrl = nil

  -- There is no configuration yet.
  self.tVersion = nil
  self.tInfo = nil
  self.atBuildDependencies = nil
  self.atDependencies = nil

  -- These are the IDs of the repositories serving the configuration and the
  -- artifact.
  self.strRepositortyID_Configuration = nil
  self.strRepositortyID_Artifact = nil
end



function ArtifactConfiguration:get_repository_id_configuration()
  local strRepositoryID = self.strRepositortyID_Configuration
  if strRepositoryID==nil then
    strRepositoryID = 'unknown'
  end

  return strRepositoryID
end



function ArtifactConfiguration:get_repository_id_artifact()
  local strRepositoryID = self.strRepositortyID_Artifact
  if strRepositoryID==nil then
    strRepositoryID = 'unknown'
  end

  return strRepositoryID
end



function ArtifactConfiguration:set_repository_id_configuration(strRepositoryID)
  if self.strRepositortyID_Configuration~=nil then
    error('Trying to override the repository ID of the configuration.')
  end
  self.strRepositortyID_Configuration = strRepositoryID
end



function ArtifactConfiguration:set_repository_id_artifact(strRepositoryID)
  if self.strRepositortyID_Artifact~=nil then
    error('Trying to override the repository ID of the artifact.')
  end

  self.strRepositortyID_Artifact = strRepositoryID
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
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "version".', iPosLine, iPosColumn)
    end
    local tVersion = aLxpAttr.Version()
    local tResult, strError = tVersion:set(strVersion)
    if tResult~=true then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: invalid "version": %s', iPosLine, iPosColumn, strError)
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
    tInfo.strExtension = aLxpAttr.strDefaultExtension
    tInfo.strPlatform = ''

    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn)
    end
    tInfo.strGroup = strGroup

    local strModule = atAttributes['module']
    if strModule==nil or strModule=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "module".', iPosLine, iPosColumn)
    end
    tInfo.strModule = strModule

    local strArtifact = atAttributes['artifact']
    if strArtifact==nil or strArtifact=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
    end
    tInfo.strArtifact = strArtifact

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
    tInfo.tVersion = tVersion

    local strVcsId = atAttributes['vcs-id']
    if strVcsId==nil or strVcsId=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.error('Error in line %d, col %d: missing "vcs-id".', iPosLine, iPosColumn)
    end
    tInfo.strVcsId = strVcsId

    local strExtension = atAttributes['extension']
    if strExtension~=nil and strExtension~='' then
      tInfo.strExtension = strExtension
    end

    -- The empty string is allowed for the platform attribute.
    local strPlatform = atAttributes['platform']
    if strPlatform~=nil then
      tInfo.strPlatform = strPlatform
    end

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

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/dependencies' then
    local atCurrentDependencyGroup = {}
    atCurrentDependencyGroup.atDependencies = {}
    atCurrentDependencyGroup.atBuildDependencies = {}
    aLxpAttr.atCurrentDependencyGroup = atCurrentDependencyGroup
    table.insert(aLxpAttr.atDependencies, atCurrentDependencyGroup)

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/dependencies/build-dependency' then
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

    table.insert(aLxpAttr.atCurrentDependencyGroup.atBuildDependencies, tDependency)

  elseif aLxpAttr.strCurrentPath=='/jonchki-artifact/dependencies/dependency' then
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

    -- The version attribute is optional. If it is not present, the version
    -- is taken from the build-dependencies.
    local strVersion = atAttributes['version']
    if strVersion==nil or strVersion=='' then
      tDependency.tVersion = nil
    else
      local tVersion = aLxpAttr.Version()
      local tResult, strError = tVersion:set(strVersion)
      if tResult~=true then
        aLxpAttr.tResult = nil
        aLxpAttr.tLog.error('Error in line %d, col %d: invalid "version": %s', iPosLine, iPosColumn, strError)
      end
      tDependency.tVersion = tVersion
    end

    table.insert(aLxpAttr.atCurrentDependencyGroup.atDependencies, tDependency)
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



function ArtifactConfiguration:parse_configuration(strConfiguration, strSourceUrl)
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
    atCurrentDependencyGroup = {},

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
    self.tLog.error('Failed to parse the artifact configuration "%s": %s in line %d, column %d, position %d.', strSourceUrl, strMsg, uiLine, uiCol, uiPos)
  elseif aLxpAttr.tResult~=true then
    self.tLog.error('Failed to parse the configuration file "%s"', strSourceUrl)
  else
    self.tVersion = aLxpCallbacks.userdata.tVersion
    self.tInfo = aLxpCallbacks.userdata.tInfo
    self.atDependencies = aLxpCallbacks.userdata.atDependencies

    -- Check if all required components are present.
    -- NOTE: the dependency block is optional.
    if self.tVersion==nil then
      self.tLog.error('Failed to parse the artifact configuration "%s": No Version found!', strConfiguration)
    elseif self.tInfo==nil then
      self.tLog.error('Failed to parse the artifact configuration "%s": No Info block found!', strConfiguration)
    else
      tResult = true

      -- Check if all depedencies have version numbers.
      for _,atDependencyGroup in pairs(self.atDependencies) do
        for _,tDependency in pairs(atDependencyGroup.atDependencies) do
          -- Does this dependency have a version number?
          if tDependency.tVersion==nil then
            -- No, the dependency has no version number. Look for the artifact
            -- in the build dependencies.
            local fFound = false
            for _,tBuildDependency in pairs(atDependencyGroup.atBuildDependencies) do
              if tBuildDependency.strGroup==tDependency.strGroup and tBuildDependency.strModule==tDependency.strModule and tBuildDependency.strArtifact==tDependency.strArtifact then
                tDependency.tVersion = tBuildDependency.tVersion
                fFound = true
                break
              end
            end
            if fFound == false then
              self.tLog.error('Failed to parse the artifact configuration "%s": The dependency G:%s,M:%s,A:%s has no version, which is only allowed if it is present in the build-dependencies - but it is not!', strConfiguration, tDependency.strGroup, tDependency.strModule, tDependency.strArtifact)
              tResult = nil
            end
          end
        end
      end
    end
  end

  return tResult
end



-- Compare GMAV and the platform with the expected values.
function ArtifactConfiguration:check_configuration(strGroup, strModule, strArtifact, tVersion, strPlatform)
  -- Be optimistic.
  local tResult = true

  -- Compare the group.
  if strGroup~=self.tInfo.strGroup then
    self.tLog.error('Error in configuration from %s: expected group "%s", got "%s".', self.strSourceUrl, strGroup, self.tInfo.strGroup)
    tResult = false
  end

  -- Compare the module.
  if strModule~=self.tInfo.strModule then
    self.tLog.error('Error in configuration from %s: expected module "%s", got "%s".', self.strSourceUrl, strModule, self.tInfo.strModule)
    tResult = false
  end

  -- Compare the artifact.
  if strArtifact~=self.tInfo.strArtifact then
    self.tLog.error('Error in configuration from %s: expected artifact "%s", got "%s".', self.strSourceUrl, strArtifact, self.tInfo.strArtifact)
    tResult = false
  end

  -- Compare the version.
  local strVersion = tVersion:get()
  local strSelfVersion = self.tInfo.tVersion:get()
  if strVersion~=strSelfVersion then
    self.tLog.error('Error in configuration from %s: expected version "%s", got "%s".', self.strSourceUrl, strVersion, strSelfVersion)
    tResult = false
  end

  if strPlatform~=self.tInfo.strPlatform then
    self.tLog.error('Error in configuration from %s: expected platform "%s", got "%s".', self.strSourceUrl, strPlatform, self.tInfo.strPlatform)
    tResult = false
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
    table.insert(astrRepr, string.format('    extension: %s', self.tInfo.strExtension))
    table.insert(astrRepr, string.format('    platform: %s', self.tInfo.strPlatform))

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
    for uiGroupCnt,atDependencyGroup in pairs(self.atDependencies) do
      table.insert(astrRepr, string.format('  group %d:', uiGroupCnt))

      table.insert(astrRepr, string.format('    dependencies: %d', #atDependencyGroup.atDependencies))
      for uiCnt,tAttr in pairs(atDependencyGroup.atDependencies) do
        table.insert(astrRepr, string.format('    %d:', uiCnt))
        table.insert(astrRepr, string.format('      group: %s', tAttr.strGroup))
        table.insert(astrRepr, string.format('      module: %s', tAttr.strModule))
        table.insert(astrRepr, string.format('      artifact: %s', tAttr.strArtifact))
        table.insert(astrRepr, string.format('      version: %s', tAttr.tVersion:get()))
        table.insert(astrRepr, '')
      end

      table.insert(astrRepr, string.format('    build dependencies: %d', #atDependencyGroup.atBuildDependencies))
      for uiCnt,tAttr in pairs(atDependencyGroup.atBuildDependencies) do
        table.insert(astrRepr, string.format('    %d:', uiCnt))
        table.insert(astrRepr, string.format('      group: %s', tAttr.strGroup))
        table.insert(astrRepr, string.format('      module: %s', tAttr.strModule))
        table.insert(astrRepr, string.format('      artifact: %s', tAttr.strArtifact))
        table.insert(astrRepr, string.format('      version: %s', tAttr.tVersion:get()))
        table.insert(astrRepr, '')
      end
    end
  end
  table.insert(astrRepr, ')')

  return table.concat(astrRepr, '\n')
end



function ArtifactConfiguration:writeToReport(tReport, strPath)
  local strVersion = ''
  if self.version~=nil then
    strVersion = self.tVersion:get()
  end
  tReport:addData(strPath .. '/version', strVersion)

  -- Add the info node.
  local strInfoGroup = ''
  local strInfoModule = ''
  local strInfoArtifact = ''
  local strInfoVersion = ''
  local strInfoVcsId = ''
  local strInfoExtension = ''
  local strInfoPlatform = ''
  local strInfoLicense = ''
  local strInfoAuthorName = ''
  local strInfoAuthorUrl = ''
  local strInfoDescription = ''
  if self.tInfo~=nil then
    strInfoGroup = self.tInfo.strGroup
    strInfoModule = self.tInfo.strModule
    strInfoArtifact = self.tInfo.strArtifact
    strInfoVersion = self.tInfo.tVersion:get()
    strInfoVcsId = self.tInfo.strVcsId
    strInfoExtension = self.tInfo.strExtension
    strInfoPlatform = self.tInfo.strPlatform
    strInfoLicense = self.tInfo.strLicense
    strInfoAuthorName = self.tInfo.strAuthorName
    strInfoAuthorUrl = self.tInfo.strAuthorUrl
    strInfoDescription = self.tInfo.strDescription
  end
  tReport:addData(strPath .. '/info/group', strInfoGroup)
  tReport:addData(strPath .. '/info/module', strInfoModule)
  tReport:addData(strPath .. '/info/artifact', strInfoArtifact)
  tReport:addData(strPath .. '/info/version', strInfoVersion)
  tReport:addData(strPath .. '/info/vcs_id', strInfoVcsId)
  tReport:addData(strPath .. '/info/extension', strInfoExtension)
  tReport:addData(strPath .. '/info/platform', strInfoPlatform)
  tReport:addData(strPath .. '/info/license', strInfoLicense)
  tReport:addData(strPath .. '/info/author_name', strInfoAuthorName)
  tReport:addData(strPath .. '/info/author_url', strInfoAuthorUrl)
  tReport:addData(strPath .. '/info/description', strInfoDescription)

  -- Add the repository IDs.
  tReport:addData(strPath .. '/repositories/configuration', self:get_repository_id_configuration())
  tReport:addData(strPath .. '/repositories/artifact', self:get_repository_id_artifact())

  -- Add the dependencies.
  if self.atDependencies~=nil then
    for uiGroupCnt,atDependencyGroup in ipairs(self.atDependencies) do
      for uiCnt,tDependency in ipairs(atDependencyGroup.atDependencies) do
        tReport:addData(string.format('%s/dependency_group@id=%d/dependency@id=%d/group', strPath, uiGroupCnt, uiCnt), tDependency.strGroup)
        tReport:addData(string.format('%s/dependency_group@id=%d/dependency@id=%d/module', strPath, uiGroupCnt, uiCnt), tDependency.strModule)
        tReport:addData(string.format('%s/dependency_group@id=%d/dependency@id=%d/artifact', strPath, uiGroupCnt, uiCnt), tDependency.strArtifact)
        if tDependency.tVersion~=nil then
          tReport:addData(string.format('%s/dependency_group@id=%d/dependency@id=%d/version', strPath, uiGroupCnt, uiCnt), tDependency.tVersion:get())
        end
      end

      for uiCnt,tDependency in ipairs(atDependencyGroup.atBuildDependencies) do
        tReport:addData(string.format('%s/dependency_group@id=%d/build_dependency@id=%d/group', strPath, uiGroupCnt, uiCnt), tDependency.strGroup)
        tReport:addData(string.format('%s/dependency_group@id=%d/build_dependency@id=%d/module', strPath, uiGroupCnt, uiCnt), tDependency.strModule)
        tReport:addData(string.format('%s/dependency_group@id=%d/build_dependency@id=%d/artifact', strPath, uiGroupCnt, uiCnt), tDependency.strArtifact)
        if tDependency.tVersion~=nil then
          tReport:addData(string.format('%s/dependency_group@id=%d/build_dependency@id=%d/version', strPath, uiGroupCnt, uiCnt), tDependency.tVersion:get())
        end
      end
    end
  end
end



return ArtifactConfiguration
