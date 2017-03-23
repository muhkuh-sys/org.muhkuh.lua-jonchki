--- The installer class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Installer = class()


--- Initialize a new instance of the installer.
function Installer:_init(cLogger, cSystemConfiguration)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- The "archives" module is a wrapper for LUA modules and CLI tools to
  -- create and depack archives.
  local cArchives = require 'installer.archives'
  self.archives = cArchives(cLogger)

  -- The install helper class.
  self.InstallHelper = require 'installer.install_helper'

  self.cLogger = cLogger

  -- The system configuration.
  self.cSystemConfiguration = cSystemConfiguration
end



function Installer:run_install_script(strInstallScriptFile, strDepackPath, cInstallHelper, strGMAV)
  local tResult

  -- Get the path to the installation script.
  self.cLogger:info('Running the install script "%s".', strInstallScriptFile)
  -- Check if the file exists.
  if self.pl.path.exists(strInstallScriptFile)~=strInstallScriptFile then
    tResult = nil
    self.cLogger:error('The install script "%s" does not exist.', strInstallScriptFile)
  else
    -- Check if the install script is a file.
    if self.pl.path.isfile(strInstallScriptFile)~=true then
      tResult = nil
      self.cLogger:error('The install script "%s" is no file.', strInstallScriptFile)
    else
      -- Call the install script.
      local strError
      tResult, strError = self.pl.utils.readfile(strInstallScriptFile, false)
      if tResult==nil then
        tResult = nil
        self.cLogger:error('Failed to read the install script "%s": %s', strInstallScriptFile, strError)
      else
        -- Parse the install script.
        local strInstallScript = tResult
        tResult, strError = loadstring(strInstallScript, strInstallScriptFile)
        if tResult==nil then
          tResult = nil
          self.cLogger:error('Failed to parse the install script "%s": %s', strInstallScriptFile, strError)
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
            self.cLogger:error('Failed to run the install script "%s": %s', strInstallScriptFile, tostring(strError))

          -- The second value is the return value.
          elseif strError~=true then
            tResult = nil
            self.cLogger:error('The install script "%s" returned "%s".', strInstallScriptFile, tostring(strError))
          end
        end
      end
    end
  end

  return tResult
end



function Installer:install_artifacts(atArtifacts, cPlatform, fInstallBuildDependencies, strFinalizerScript)
  local tResult = true

  -- Create the installation helper.
  local cInstallHelper = self.InstallHelper(self.cLogger, self.cSystemConfiguration, cPlatform, fInstallBuildDependencies)

  for _,tAttr in pairs(atArtifacts) do
    local tInfo = tAttr.cArtifact.tInfo
    local strGroup = tInfo.strGroup
    local strModule = tInfo.strModule
    local strArtifact = tInfo.strArtifact
    local strVersion = tInfo.tVersion:get()
    local strArtifactPath = tAttr.strArtifactPath

    local strGMAV = string.format('%s-%s-%s-%s', strGroup, strModule, strArtifact, strVersion)
    self.cLogger:info('Installing %s for target %s', strGMAV, tostring(cPlatform))

    -- Create a unique temporary path for the artifact.
    local strGroupPath = self.pl.stringx.replace(strGroup, '.', self.pl.path.sep)
    local strDepackPath = self.pl.path.join(self.cSystemConfiguration.tConfiguration.depack, strGroupPath, strModule, strArtifact, strVersion)

    -- Does the depack path already exist?
    if self.pl.path.exists(strDepackPath)==strDepackPath then
      tResult = nil
      self.cLogger:error('The unique depack path %s already exists.', strDepackPath)
      break
    else
      local strError
      tResult, strError = self.pl.dir.makepath(strDepackPath)
      if tResult~=true then
        tResult = nil
        self.cLogger:error('Failed to create the depack path for %s: %s', strGMAV, strError)
        break
      else
        -- Add the depack path and the version to the replacement list.
        local strVariableArtifactPath = string.format('artifact_path_%s.%s.%s', strGroup, strModule, strArtifact)
        tResult = cInstallHelper:add_replacement(strVariableArtifactPath, strArtifactPath)
        if tResult~=true then
          self.cLogger:error('Failed to add the artifact path variable for %s.', strGMAV)
          break
        else
          local strVariableNameDepackPath = string.format('depack_path_%s.%s.%s', strGroup, strModule, strArtifact)
          tResult = cInstallHelper:add_replacement(strVariableNameDepackPath, strDepackPath)
          if tResult~=true then
            self.cLogger:error('Failed to add the depack path variable for %s.', strGMAV)
            break
          else
            local strVariableNameVersion = string.format('version_%s.%s.%s', strGroup, strModule, strArtifact)
            tResult = cInstallHelper:add_replacement(strVariableNameVersion, strVersion)
            if tResult~=true then
              self.cLogger:error('Failed to add the version variable for %s.', strGMAV)
              break
            else
              tResult = self.archives:depack_archive(strArtifactPath, strDepackPath)
              if tResult==nil then
                self.cLogger:error('Error depacking %s .', strGMAV)
                break
              end

              local strInstallScriptFile = self.pl.path.join(strDepackPath, 'install.lua')
              tResult = self:run_install_script(strInstallScriptFile, strDepackPath, cInstallHelper, strGMAV)
              if tResult==nil then
                self.cLogger:error('Error installing %s .', strGMAV)
                break
              end
            end
          end
        end
      end
    end
  end

  if tResult==true then
    if strFinalizerScript~=nil then
      -- Get the absolute path for the finalizer script.
      local strFinalizerScriptAbs = self.pl.path.abspath(strFinalizerScript)
      -- Get the path component of the finalizer script.
      local strWorkingPath = self.pl.path.dirname(strFinalizerScriptAbs)
      self.cLogger:info('Run the finalizer script "%s".', strFinalizerScriptAbs)
      tResult = self:run_install_script(strFinalizerScriptAbs, strWorkingPath, cInstallHelper, 'finalizer script')
      if tResult==nil then
        self.cLogger:error('Error running the finalizer script.')
      end
    end
  end

  return tResult
end

return Installer
