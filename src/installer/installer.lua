--- The installer class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Installer = class()


--- Initialize a new instance of the installer.
function Installer:_init(cSystemConfiguration)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- The "luazip" module is used to depack the archives.
  self.zip = require 'zip'

  -- The install helper class.
  self.InstallHelper = require 'installer.install_helper'

  -- The system configuration.
  self.cSystemConfiguration = cSystemConfiguration
end



function Installer:depack_archive(strArtifactPath, strDepackPath)
  local tResult = true
  local strError = ''

  -- Open the artifact as a zip file.
  tResult, strError = self.zip.open(strArtifactPath)
  if tResult==nil then
    strError = string.format('Failed to open %s as a ZIP archive: %s', strArtifactPath, strError)
  else
    local tZip = tResult
  
    -- Loop over all files in the archive.
    for tAttr in tZip:files() do
      local strZipFileName = tAttr.filename
      print(string.format('  extracting "%s"', strZipFileName))
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
            strError = string.format('The path "%s" leaves the depack folder!', strZipFileName)
            break
          end
          -- Create the output folder.
          tResult, strError = self.pl.dir.makepath(strOutputFolder)
          if tResult==nil then
            break
          end
        end

        -- Copy the file from the ZIP archive to the destination folder.
        local strOutputFile = self.pl.path.join(strDepackPath, strZipFileName)
        local tFileSrc = tZip:open(strZipFileName)
        if tFileSrc==nil then
          tResult = nil
          strError = string.format('Failed to extract "%s".', strZipFileName)
          break
        end
        local tFileDst = io.open(strOutputFile, 'wb')
        if tFileDst==nil then
          tResult = nil
          strError = string.format('Failed write to "%s".', strOutputFile)
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

  return tResult, strError
end



function Installer:run_install_script(strDepackPath, cInstallHelper, strGMAV)
  local tResult = true
  local strError = ''

  -- Get the path to the installation script.
  local strInstallScriptFile = self.pl.path.join(strDepackPath, 'install.lua')
  -- Check if the file exists.
  if self.pl.path.exists(strInstallScriptFile)~=strInstallScriptFile then
    tResult = nil
    strError = string.format('The install script "%s" does not exist.', strInstallScriptFile)
  else
    -- Check if the install script is a file.
    if self.pl.path.isfile(strInstallScriptFile)~=true then
      tResult = nil
      strError = string.format('The install script "%s" is no file.', strInstallScriptFile)
    else
      -- Call the install script.
      local tResult, strError = self.pl.utils.readfile(strInstallScriptFile, false)
      if tResult==nil then
        tResult = nil
        strError = string.format('Failed to read the install script "%s": %s', strInstallScriptFile, strError)
      else
        -- Parse the install script.
        local strInstallScript = tResult
        tResult, strError = loadstring(strInstallScript, strInstallScriptFile)
        if tResult==nil then
          tResult = nil
          strError = string.format('Failed to parse the install script "%s": %s', strInstallScriptFile, strError)
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
            strError = string.format('Failed to run the install script "%s": %s', strInstallScriptFile, tostring(strError))

          -- The second value is the return value.
          elseif strError~=true then
            tResult = nil
            strError = string.format('The install script "%s" returned "%s".', strInstallScriptFile, tostring(strError))
          end
        end
      end
    end
  end

  return tResult, strError
end



function Installer:install_artifacts(atArtifacts)
  local tResult = true
  local strError = ''

  -- Create the installation helper.
  local cInstallHelper = self.InstallHelper(self.cSystemConfiguration)

  for _,tGMAV in pairs(atArtifacts) do
    local strGroup = tGMAV.strGroup
    local strModule = tGMAV.strModule
    local strArtifact = tGMAV.strArtifact
    local tVersion = tGMAV.tVersion
    local strVersion = tGMAV.tVersion:get()
    local strArtifactPath = tGMAV.strArtifactPath

    local strGMAV = string.format('%s-%s-%s-%s', strGroup, strModule, strArtifact, strVersion)
    print(string.format('Installing %s', strGMAV))

    -- Create a unique temporary path for the artifact.
    local strGroupPath = self.pl.stringx.replace(strGroup, '.', self.pl.path.sep)
    local strDepackPath = self.pl.path.join(self.cSystemConfiguration.tConfiguration.depack, strGroupPath, strModule, strArtifact, strVersion)

    -- Does the depack path already exist?
    if self.pl.path.exists(strDepackPath)==strDepackPath then
      tResult = nil
      strError = string.format('The unique depack path %s already exists.', strDepackPath)
      break
    else
      tResult, strError = self.pl.dir.makepath(strDepackPath)
      if tResult~=true then
        tResult = nil
        strError = string.format('Failed to create the depack path for %s: %s', strGMAV, strError)
        break
      else
        tResult, strError = self:depack_archive(strArtifactPath, strDepackPath)
        if tResult==nil then
          strError = string.format('Error depacking %s: %s', strGMAV, strError)
          break
        end

        tResult, strError = self:run_install_script(strDepackPath, cInstallHelper, strGMAV)
        if tResult==nil then
          strError = string.format('Error installing %s: %s', strGMAV, strError)
          break
        end
      end
    end
  end

  return tResult, strError
end

return Installer
