--- The installer class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Installer = class()


--- Initialize a new instance of the installer.
function Installer:_init(cLog, cReport, cSystemConfiguration, cRootArtifactConfiguration, strFinalizerScript)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- The "archives" module is a wrapper for LUA modules and CLI tools to
  -- create and depack archives.
  local cArchives = require 'installer.archives'
  self.archives = cArchives(cLog)

  -- Create an empty list of post triggers.
  self.atPostTriggers = {}

  -- The install helper class.
  self.InstallHelper = require 'installer.install_helper'
  self.tCurrentInstallHelper = nil

  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[Installer] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )
  self.cReport = cReport

  -- The system configuration.
  self.cSystemConfiguration = cSystemConfiguration

  -- The configuration object for the root artifact.
  self.cRootArtifactConfiguration = cRootArtifactConfiguration

  -- The finalizer script for the post trigger.
  self.strFinalizerScript = strFinalizerScript
end



function Installer:run_install_script(strInstallScriptFile, strDepackPath, strGMAV)
  local tResult

  -- Get the current install helper.
  local cInstallHelper = self.tCurrentInstallHelper

  -- Get the path to the installation script.
  self.tLog.info('Running the install script "%s".', strInstallScriptFile)
  -- Check if the file exists.
  if self.pl.path.exists(strInstallScriptFile)~=strInstallScriptFile then
    tResult = nil
    self.tLog.error('The install script "%s" does not exist.', strInstallScriptFile)
  else
    -- Check if the install script is a file.
    if self.pl.path.isfile(strInstallScriptFile)~=true then
      tResult = nil
      self.tLog.error('The install script "%s" is no file.', strInstallScriptFile)
    else
      -- Call the install script.
      local strError
      tResult, strError = self.pl.utils.readfile(strInstallScriptFile, false)
      if tResult==nil then
        tResult = nil
        self.tLog.error('Failed to read the install script "%s": %s', strInstallScriptFile, strError)
      else
        -- Parse the install script.
        local strInstallScript = tResult
        local loadstring = loadstring or load
        tResult, strError = loadstring(strInstallScript, strInstallScriptFile)
        if tResult==nil then
          tResult = nil
          self.tLog.error('Failed to parse the install script "%s": %s', strInstallScriptFile, strError)
        else
          local fnInstall = tResult

          -- Set the artifact's depack path as the current working folder.
          cInstallHelper:setCwd(strDepackPath)

          -- Set the current artifact identification for error messages.
          cInstallHelper:setId(strGMAV)

          -- Call the install script.
          tResult, strError = pcall(fnInstall, cInstallHelper)
          if tResult~=true then
            tResult = nil
            self.tLog.error('Failed to run the install script "%s": %s', strInstallScriptFile, tostring(strError))

          -- The second value is the return value.
          elseif strError~=true then
            tResult = nil
            self.tLog.error('The install script "%s" returned "%s".', strInstallScriptFile, tostring(strError))
          end
        end
      end
    end
  end

  return tResult
end



function Installer:install_artifacts(atArtifacts, cPlatform, fInstallBuildDependencies)
  local tResult = true

  -- Create the installation helper.
  local cInstallHelper = self.InstallHelper(self.cLog, fInstallBuildDependencies, self.atPostTriggers)
  -- Register the finalizer as a post trigger.
  cInstallHelper:register_post_trigger(self.run_finalizer, self, 75)
  -- Add replacement variables.
  local atReplacements = {
    ['install_base'] = self.cSystemConfiguration.tConfiguration.install_base,
    ['install_executables'] = self.cSystemConfiguration.tConfiguration.install_executables,
    ['install_shared_objects'] = self.cSystemConfiguration.tConfiguration.install_shared_objects,
    ['install_lua_path'] = self.cSystemConfiguration.tConfiguration.install_lua_path,
    ['install_lua_cpath'] = self.cSystemConfiguration.tConfiguration.install_lua_cpath,
    ['install_doc'] = self.cSystemConfiguration.tConfiguration.install_doc,
    ['install_dev'] = self.cSystemConfiguration.tConfiguration.install_dev,
    ['install_dev_include'] = self.cSystemConfiguration.tConfiguration.install_dev_include,
    ['install_dev_lib'] = self.cSystemConfiguration.tConfiguration.install_dev_lib,
    ['install_dev_cmake'] = self.cSystemConfiguration.tConfiguration.install_dev_cmake,

    ['platform_cpu_architecture'] = cPlatform:get_cpu_architecture(),
    ['platform_distribution_id'] = cPlatform:get_distribution_id(),
    ['platform_distribution_version'] = cPlatform:get_distribution_version(),
    ['platform_distribution_version_separator'] = '-',

    ['root_artifact_group'] = self.cRootArtifactConfiguration.tInfo.strGroup,
    ['root_artifact_module'] = self.cRootArtifactConfiguration.tInfo.strModule,
    ['root_artifact_artifact'] = self.cRootArtifactConfiguration.tInfo.strArtifact,
    ['root_artifact_version'] = self.cRootArtifactConfiguration.tInfo.tVersion:get(),
    ['root_artifact_vcs_id'] = self.cRootArtifactConfiguration.tInfo.strVcsId,
    ['root_artifact_extension'] = self.cRootArtifactConfiguration.tInfo.strExtension,
    ['root_artifact_license'] = self.cRootArtifactConfiguration.tInfo.strLicense,
    ['root_artifact_author_name'] = self.cRootArtifactConfiguration.tInfo.strAuthorName,
    ['root_artifact_author_url'] = self.cRootArtifactConfiguration.tInfo.strAuthorUrl,
    ['root_artifact_description'] = self.cRootArtifactConfiguration.tInfo.strDescription,

    ['report_path'] = self.cReport:getFileName()
  }
  for strKey, strValue in pairs(atReplacements) do
    if strValue~=nil then
      tResult = cInstallHelper:add_replacement(strKey, strValue)
      if tResult~=true then
        self.tLog.error('Failed to add the replacement variable "%s".', strKey)
        break
      end
    end
  end
  if tResult==true then
    self.tCurrentInstallHelper = cInstallHelper

    for _,tAttr in pairs(atArtifacts) do
      local tInfo = tAttr.cArtifact.tInfo
      local strGroup = tInfo.strGroup
      local strModule = tInfo.strModule
      local strArtifact = tInfo.strArtifact
      local strVersion = tInfo.tVersion:get()
      local strArtifactPath = tAttr.strArtifactPath

      local strGMAV = string.format('%s-%s-%s-%s', strGroup, strModule, strArtifact, strVersion)
      self.tLog.info('Installing %s for target %s', strGMAV, tostring(cPlatform))

      -- Create a unique temporary path for the artifact.
      local strGroupPath = self.pl.stringx.replace(strGroup, '.', self.pl.path.sep)
      local strDepackPath = self.pl.path.join(self.cSystemConfiguration.tConfiguration.depack, strGroupPath, strModule, strArtifact, strVersion)

      -- Does the depack path already exist?
      if self.pl.path.exists(strDepackPath)==strDepackPath then
        tResult = nil
        self.tLog.error('The unique depack path %s already exists.', strDepackPath)
        break
      else
        local strError
        tResult, strError = self.pl.dir.makepath(strDepackPath)
        if tResult~=true then
          tResult = nil
          self.tLog.error('Failed to create the depack path for %s: %s', strGMAV, strError)
          break
        else
          -- Add the depack path and the version to the replacement list.
          local strVariableArtifactPath = string.format('artifact_path_%s.%s.%s', strGroup, strModule, strArtifact)
          tResult = cInstallHelper:add_replacement(strVariableArtifactPath, strArtifactPath)
          if tResult~=true then
            self.tLog.error('Failed to add the artifact path variable for %s.', strGMAV)
            break
          else
            local strVariableNameDepackPath = string.format('depack_path_%s.%s.%s', strGroup, strModule, strArtifact)
            tResult = cInstallHelper:add_replacement(strVariableNameDepackPath, strDepackPath)
            if tResult~=true then
              self.tLog.error('Failed to add the depack path variable for %s.', strGMAV)
              break
            else
              local strVariableNameVersion = string.format('version_%s.%s.%s', strGroup, strModule, strArtifact)
              tResult = cInstallHelper:add_replacement(strVariableNameVersion, strVersion)
              if tResult~=true then
                self.tLog.error('Failed to add the version variable for %s.', strGMAV)
                break
              else
                tResult = self.archives:depack_archive(strArtifactPath, strDepackPath)
                if tResult==nil then
                  self.tLog.error('Error depacking %s .', strGMAV)
                  break
                end

                local strInstallScriptFile = self.pl.path.join(strDepackPath, 'install.lua')
                tResult = self:run_install_script(strInstallScriptFile, strDepackPath, strGMAV)
                if tResult==nil then
                  self.tLog.error('Error installing %s .', strGMAV)
                  break
                end
              end
            end
          end
        end
      end
    end

    if tResult==true then
      -- Run all post triggers.
      self.tLog.debug('Running post trigger scripts.')
      for uiLevel, atLevel in self.pl.tablex.sort(self.atPostTriggers) do
        self.tLog.debug('Running post trigger actions for level %d.', uiLevel)
        for _, tPostAction in ipairs(atLevel) do
          tResult = tPostAction.fn(tPostAction.userdata, cInstallHelper)
          if tResult==nil then
            self.tLog.error('Error running the post trigger action script.')
            break
          end
        end
      end
    end
  end

  return tResult
end



function Installer:run_finalizer()
  local tResult = true
  local strFinalizerScript = self.strFinalizerScript

  if strFinalizerScript~=nil then
    -- Get the absolute path for the finalizer script.
    local strFinalizerScriptAbs = self.pl.path.abspath(strFinalizerScript)
    -- Get the path component of the finalizer script.
    local strWorkingPath = self.pl.path.dirname(strFinalizerScriptAbs)
    self.tLog.info('Run the finalizer script "%s".', strFinalizerScriptAbs)
    tResult = self:run_install_script(strFinalizerScriptAbs, strWorkingPath, 'finalizer script')
    if tResult==nil then
      self.tLog.error('Error running the finalizer script.')
    end
  end

  return tResult
end

return Installer
