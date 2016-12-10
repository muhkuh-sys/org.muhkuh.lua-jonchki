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

  -- The "luazip" module is used to depack the archives.
  self.zip = require 'zip'

  -- The install helper class.
  self.InstallHelper = require 'installer.install_helper'

  self.cLogger = cLogger

  -- The system configuration.
  self.cSystemConfiguration = cSystemConfiguration
end



function Installer:depack_archive(strArtifactPath, strDepackPath)
  local tResult
  local strError

  self.cLogger:info('Depacking artifact archive "%s" to "%s".', strArtifactPath, strDepackPath)
  -- Open the artifact as a zip file.
  tResult, strError = self.zip.open(strArtifactPath)
  if tResult==nil then
    self.cLogger:error('Failed to open %s as a ZIP archive: %s', strArtifactPath, strError)
  else
    local tZip = tResult

    -- Loop over all files in the archive.
    for tAttr in tZip:files() do
      local strZipFileName = tAttr.filename
      self.cLogger:debug('Extracting "%s"', strZipFileName)
      -- Skip entries ending with a "/".
      if string.sub(strZipFileName, -1)~='/' then
        -- Get the directory part of the filename.
        local strZipFolder = self.pl.path.dirname(strZipFileName)
        local strOutputFolder = self.pl.path.join(strDepackPath, strZipFolder)

        -- The output folder must be below the depack folder.
        local strRel = self.pl.path.relpath(strDepackPath, strOutputFolder)
        if strRel~='' then
          if string.sub(strRel, 1, 2)~='..' then
            tResult = nil
            self.cLogger:error('The path "%s" leaves the depack folder!', strZipFileName)
            break
          end
          -- Create the output folder.
          tResult, strError = self.pl.dir.makepath(strOutputFolder)
          if tResult==nil then
            self.cLogger:error('Failed to create the folder: "%s"', strError)
            break
          end
        end

        -- Copy the file from the ZIP archive to the destination folder.
        local strOutputFile = self.pl.path.join(strDepackPath, strZipFileName)
        local tFileSrc = tZip:open(strZipFileName)
        if tFileSrc==nil then
          tResult = nil
          self.cLogger:error('Failed to extract "%s".', strZipFileName)
          break
        end
        local tFileDst = io.open(strOutputFile, 'wb')
        if tFileDst==nil then
          tResult = nil
          self.cLogger:error('Failed open the file "%s" for writing.', strOutputFile)
          break
        end
        repeat
          local aucData = tFileSrc:read(4096)
          if aucData~=nil then
            tFileDst:write(aucData)
          end
        until aucData==nil
        tFileSrc:close()
        tFileDst:close()
      end
    end

    tZip:close()
  end

  return tResult
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

  for _,tGMAV in pairs(atArtifacts) do
    local strGroup = tGMAV.strGroup
    local strModule = tGMAV.strModule
    local strArtifact = tGMAV.strArtifact
    local strVersion = tGMAV.tVersion:get()
    local strArtifactPath = tGMAV.strArtifactPath

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
              tResult = self:depack_archive(strArtifactPath, strDepackPath)
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
