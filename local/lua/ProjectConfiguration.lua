--- The project configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2017 Christoph Thelen


-- Create the configuration class.
local class = require 'pl.class'
local ProjectConfiguration = class()



function ProjectConfiguration:_init(cLog, cReport)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to parse the XML data.
  self.lxp = require 'lxp'

  -- Get the logger.
  local tLogWriter = require 'log.writer.prefix'.new('[ProjectConfiguration] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  -- Get the report.
  self.tReport = cReport

  -- There is no configuration yet.
  self.atRepositories = nil

  -- No default policy list.
  self.atPolicyListDefault = nil
  -- No overrides.
  self.atPolicyListOverrides = nil
end



--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function ProjectConfiguration.parseCfg_StartElement(tParser, strName, atAttributes)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn = tParser:pos()

  table.insert(aLxpAttr.atCurrentPath, strName)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")

  if aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository" then
    local tCurrentRepository = {}
    local strID = atAttributes['id']
    if strID==nil or strID=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "id".', iPosLine, iPosColumn)
    else
      -- Is the ID already defined?
      local fIsDuplicate = false
      for _, tRepo in pairs(aLxpAttr.atRepositories) do
        if tRepo.strID==strID then
          fIsDuplicate = true
          break
        end
      end
      if fIsDuplicate==true then
        aLxpAttr.tResult = nil
        aLxpAttr.tLog.fatal('Error in line %d, col %d: the ID "%s" is already used.', iPosLine, iPosColumn, strID)
      else
        tCurrentRepository.strID = strID
        local strType = atAttributes['type']
        if strType==nil or strType=='' then
          aLxpAttr.tResult = nil
          aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "type".', iPosLine, iPosColumn)
        else
          tCurrentRepository.strType = strType
          local fCacheable = nil
          local strCacheable = atAttributes['cacheable']
          -- Default to no cache if the attribute is not present.
          if strCacheable==nil then
            fCacheable = false
          elseif strCacheable=='0' or string.lower(strCacheable)=='false' or string.lower(strCacheable)=='no' then
            fCacheable = false
          elseif strCacheable=='1' or string.lower(strCacheable)=='true' or string.lower(strCacheable)=='yes' then
            fCacheable = true
          end
          if fCacheable==nil then
            aLxpAttr.tResult = nil
            aLxpAttr.tLog.fatal('Error in line %d, col %d: invalid value for "cacheable": "%s".', iPosLine, iPosColumn, strCacheable)
          else
            tCurrentRepository.cacheable = fCacheable

            local ulRescan = nil
            local strRescan = atAttributes['rescan']
            -- Default to a rescan time of 0.
            if strRescan==nil then
              ulRescan = 0
            else
              ulRescan = tonumber(strRescan)
              if ulRescan==nil then
                aLxpAttr.tResult = nil
                aLxpAttr.tLog.fatal('Error in line %d, col %d: invalid value for "rescan", not a number: "%s".', iPosLine, iPosColumn, strRescan)
              elseif ulRescan<0 then
                ulRescan = nil
                aLxpAttr.tResult = nil
                aLxpAttr.tLog.fatal('Error in line %d, col %d: invalid value for "rescan", must not be negative: %d.', iPosLine, iPosColumn, ulRescan)
              end
            end
            if ulRescan~=nil then
              tCurrentRepository.ulRescan = ulRescan
              tCurrentRepository.strRoot = nil
              tCurrentRepository.strVersions = nil
              tCurrentRepository.strConfig = nil
              tCurrentRepository.strArtifact = nil
            end

            aLxpAttr.tCurrentRepository = tCurrentRepository
          end
        end
      end
    end

  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/policies/default/policy" then
    local strID = atAttributes['id']
    if strID==nil or strID=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "id".', iPosLine, iPosColumn)
    else
      table.insert(aLxpAttr.atPolicyListDefault, strID)
    end

  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/policies/override" then
    local strGroup = atAttributes['group']
    if strGroup==nil or strGroup=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "group".', iPosLine, iPosColumn)
    else
      local strModule = atAttributes['module']
      if strModule==nil or strModule=='' then
        aLxpAttr.tResult = nil
        aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "module".', iPosLine, iPosColumn)
      else
        local strArtifact = atAttributes['artifact']
        if strArtifact==nil or strArtifact=='' then
          aLxpAttr.tResult = nil
          aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "artifact".', iPosLine, iPosColumn)
        else
          local strItem = string.format('%s/%s/%s', strGroup, strModule, strArtifact)
          aLxpAttr.strCurrentPolicyOverrideItem = strItem
          aLxpAttr.atCurrentPolicyOverrides = {}
        end
      end
    end

  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/policies/override/policy" then
    local strID = atAttributes['id']
    if strID==nil or strID=='' then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: missing "id".', iPosLine, iPosColumn)
    else
      table.insert(aLxpAttr.atCurrentPolicyOverrides, strID)
    end
  end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function ProjectConfiguration.parseCfg_EndElement(tParser, strName)
  local aLxpAttr = tParser:getcallbacks().userdata
  local iPosLine, iPosColumn = tParser:pos()
  local tCurrentRepository = aLxpAttr.tCurrentRepository

  if aLxpAttr.strCurrentPath=="/jonchkicfg/repositories/repository" then
    -- Check if all data is present.
    local astrMissing = {}
    if tCurrentRepository.strID==nil then
      table.insert(astrMissing, 'id')
    end
    local strType = tCurrentRepository.strType
    if strType==nil then
      table.insert(astrMissing, 'type')
    else
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
      if strType=='http' then
        if tCurrentRepository.strInitialPage==nil then
          table.insert(astrMissing, 'initialpage')
        end
        if tCurrentRepository.strVersionParser==nil then
          table.insert(astrMissing, 'versionparser')
        end
      end
    end
    if #astrMissing ~= 0 then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: missing items: %s', iPosLine, iPosColumn, table.concat(astrMissing, ', '))
    else
      -- All data is present.
      table.insert(aLxpAttr.atRepositories, tCurrentRepository)
      aLxpAttr.tCurrentRepository = nil
    end

  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/policies/default" then
    -- The default list must not be empty.
    if #aLxpAttr.atPolicyListDefault == 0 then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: the default policies must not be empty', iPosLine, iPosColumn)
    end

  elseif aLxpAttr.strCurrentPath=="/jonchkicfg/policies/override" then
    -- Add the new override to the list.
    -- The override must not be empty.
    if #aLxpAttr.atCurrentPolicyOverrides == 0 then
      aLxpAttr.tResult = nil
      aLxpAttr.tLog.fatal('Error in line %d, col %d: the overrides policies must not be empty', iPosLine, iPosColumn)
    else
      local strCurrentPolicyOverrideItem = aLxpAttr.strCurrentPolicyOverrideItem
      if aLxpAttr.atPolicyListOverrides[strCurrentPolicyOverrideItem] ~= nil then
        aLxpAttr.tResult = nil
        aLxpAttr.tLog.fatal('Error in line %d, col %d: overriding %s more than once', iPosLine, iPosColumn, strCurrentPolicyOverrideItem)
      else
        aLxpAttr.atPolicyListOverrides[strCurrentPolicyOverrideItem] = aLxpAttr.atCurrentPolicyOverrides
      end
    end

    aLxpAttr.atCurrentPolicyOverrides = nil
    aLxpAttr.strCurrentPolicyOverrideItem = nil

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

  local strCurrentPath = aLxpAttr.strCurrentPath
  if strCurrentPath=="/jonchkicfg/repositories/repository/root" then
    tCurrentRepository.strRoot = strData
  elseif strCurrentPath=="/jonchkicfg/repositories/repository/versions" then
    tCurrentRepository.strVersions = strData
  elseif strCurrentPath=="/jonchkicfg/repositories/repository/config" then
    tCurrentRepository.strConfig = strData
  elseif strCurrentPath=="/jonchkicfg/repositories/repository/artifact" then
    tCurrentRepository.strArtifact = strData
  elseif strCurrentPath=="/jonchkicfg/repositories/repository/initialpage" then
    tCurrentRepository.strInitialPage = strData
  elseif strCurrentPath=="/jonchkicfg/repositories/repository/versionparser" then
    tCurrentRepository.strVersionParser = strData
  end
end



function ProjectConfiguration:parse_configuration(strConfigurationFilename)
  -- Be optimistic!
  local tResult = true

  self.tLog.info('Reading the project configuration from "%s"', strConfigurationFilename)

  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    tResult = nil
    self.tLog.fatal('The function "parse_configuration" expects a filename as a parameter.')
  else
    local aLxpAttr = {
      -- Start at root ("/").
      atCurrentPath = {""},
      strCurrentPath = nil,

      tCurrentRepository = nil,
      atRepositories = {},

      atPolicyListDefault = {},

      strCurrentPolicyOverrideItem = nil,
      atCurrentPolicyOverrides = nil,
      atPolicyListOverrides = {},

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

    -- Read the complete file.
    local strXmlText, strError = self.pl.utils.readfile(strConfigurationFilename, false)
    if strXmlText==nil then
      tResult = nil
      self.tLog.fatal('Error reading the configuration file: %s', strError)
    else
      local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strXmlText)
      if tParseResult~=nil then
        tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
      end
      tParser:close()

      if tParseResult==nil then
        tResult = nil
        self.tLog.fatal("%s: %d,%d,%d", strMsg, uiLine, uiCol, uiPos)
      elseif aLxpAttr.tResult==nil then
        tResult = nil
      else
        -- Set the default policy list to "001" and "002" if it was not specified yet.
        if #aLxpAttr.atPolicyListDefault == 0 then
          table.insert(aLxpAttr.atPolicyListDefault, '001')
          table.insert(aLxpAttr.atPolicyListDefault, '002')
        end

        self.atRepositories = aLxpAttr.atRepositories
        self.atPolicyListDefault = aLxpAttr.atPolicyListDefault
        self.atPolicyListOverrides = aLxpAttr.atPolicyListOverrides

        -- Add all repositories to the report.
        for uiCnt, tRepository in ipairs(self.atRepositories) do
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/id', uiCnt), tRepository.strID)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/type', uiCnt), tRepository.strType)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/cacheable', uiCnt), tRepository.cacheable)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/rescan', uiCnt), tRepository.ulRescan)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/root', uiCnt), tRepository.strRoot)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/versions', uiCnt), tRepository.strVersions)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/config', uiCnt), tRepository.strConfig)
          self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/artifact', uiCnt), tRepository.strArtifact)
          if tRepository.strType=='http' then
            self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/initialpage', uiCnt), tRepository.strInitialPage)
            self.tReport:addData(string.format('configuration/project/repositories/repository@idx=%d/versionparser', uiCnt), tRepository.strVersionParser)
          end
        end

        -- Add all default policies to the report.
        for uiCnt, strPolicy in ipairs(self.atPolicyListDefault) do
          self.tReport:addData(string.format('configuration/project/policies/default@idx=%d/policy', uiCnt), strPolicy)
        end

        -- Add the policy overrides to the report.
        -- FIXME: sort the overrides by GAV. Maybe with penlight?
        local uiCnt = 1
        for strGMA, atPolicies in pairs(self.atPolicyListOverrides) do
          self.tReport:addData(string.format('configuration/project/policies/override@idx=%d/GAV', uiCnt), strPolicies)
          for uiCnt, strPolicy in ipairs(atPolicies) do
            self.tReport:addData(string.format('configuration/project/policies/override@idx=%d/policy', uiCnt), strPolicy)
          end
        end
      end
    end
  end

  return tResult
end



--- Return the complete configuration as a string.
-- @return The configuration as a string.
function ProjectConfiguration:__tostring()
  local strCfg

  if self.atRepositories==nil then
    strCfg = 'ProjectConfiguration()'
  else
    strCfg = self.pl.pretty.write(self.atRepositories)
  end

  return strCfg
end


return ProjectConfiguration
