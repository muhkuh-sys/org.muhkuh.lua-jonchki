--- A repository driver for a filesystem.
-- The repository module provides an abstraction to a number of different
-- repositories. The real work is done by drivers. This is the driver
-- providing access to a repository on a filesystem.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2016 Christoph Thelen

-- Create the class.
local class = require 'pl.class'
local RepositoryDriver = require 'repository_driver.repository_driver'
local RepositoryDriverFilesystem = class(RepositoryDriver)



function RepositoryDriverFilesystem:_init(cLog, tPlatform, strID)
  -- Set the logger, platform and the ID of the repository driver.
  self:super(cLog, tPlatform, strID)

  -- Clear the patterns for the configuration and artifact.
  self.fCacheable = nil
  self.ulRescan = nil
  self.strRoot = nil
  self.strVersions = nil
  self.strConfig = nil
  self.strArtifact = nil
end



-- This is a static member.
function RepositoryDriverFilesystem.matches_type(strType)
  return strType=='file'
end



function RepositoryDriverFilesystem:configure(atSettings)
  self.fCacheable = atSettings.cacheable
  self.ulRescan = atSettings.ulRescan
  -- Replace "~" with the users home folder and make an absolute path from the root.
  self.strRoot = self.pl.path.abspath(self.pl.path.expanduser(atSettings.strRoot))
  -- Replace "~" with the users home folder for the other settings, but do not
  -- change it to absolute paths. It will be appended to the root.
  self.strVersions = self.pl.path.expanduser(atSettings.strVersions)
  self.strConfig = self.pl.path.expanduser(atSettings.strConfig)
  self.strArtifact = self.pl.path.expanduser(atSettings.strArtifact)

  self.tLog.debug(tostring(self))

  return true
end



function RepositoryDriverFilesystem:exists()
  local tResult

  -- Does the root folder exist?
  if self.pl.path.exists(self.strRoot)~=self.strRoot then
    tResult = nil
    self.tLog.error('The repository root path "%s" does not exist.', self.strRoot)

  -- Is the root folder really a folder?
  elseif self.pl.path.isdir(self.strRoot)~=true then
    tResult = nil
    self.tLog.error('The repository root path "%s" is no directory.', self.strRoot)

  else
    tResult = true
  end

  return tResult
end



function RepositoryDriverFilesystem:get_available_versions(strGroup, strModule, strArtifact)
  self.tLog.debug('Get available versions for %s/%s/%s.', strGroup, strModule, strArtifact)
  self.uiStatistics_VersionScans = self.uiStatistics_VersionScans + 1
  local tResult = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the versions path.
    local strVersions = self:replace_path(strGroup, strModule, strArtifact, nil, nil, nil, self.strVersions)

    -- Append the version folder to the root.
    -- FIXME: First check if the path is already absolute. In this case do not append the root folder.
    local strVersionPath = self.pl.path.join(self.strRoot, strVersions)
    self.tLog.debug('  Looking in path "%s"', strVersionPath)

    -- Continue only if the version folder exists.
    -- If the folder does not exist, there is no matching aritfact.
    local atVersions = {}
    if self.pl.path.isdir(strVersionPath)~=true then
      self.tLog.debug('The path "%s" does not exist.', strVersionPath)
    else
      -- Get all subfolders in the version folder.
      -- NOTE: this function returns the absolute paths, not only the subfolder names.
      local atPaths = self.pl.dir.getdirectories(strVersionPath)

      -- Extract the subfolder names from the paths and check if this is a valid version number.
      for _,strPath in pairs(atPaths) do
        local _,strSubfolder = self.pl.path.splitpath(strPath)
        local tVersion = self.Version()
        local fOk = tVersion:set(strSubfolder)
        if fOk==true then
          table.insert(atVersions, tVersion)
          self.tLog.debug('  Found version: %s', tVersion:get())
        end
      end
    end

    if #atVersions == 0 then
      self.tLog.debug('  No versions found.')
    end
    tResult = atVersions
  end

  return tResult
end



function RepositoryDriverFilesystem:get_configuration(strGroup, strModule, strArtifact, tVersion)
  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- Does the root folder of the repository exist?
  local tResult = self:exists()
  if tResult~=true then
    self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
    tResult = nil
  else
    -- Try the platform independent version first.
    local strCurrentPlatform = ''
    local strCfgSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml', self.strConfig)
    local strHashSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml.hash', self.strConfig)
    -- Append the version folder to the root.
    -- FIXME: First check if the paths are already absolute. In this case do not append the root folder.
    local strCfgPath = self.pl.path.join(self.strRoot, strCfgSubdirectory)
    local strHashPath = self.pl.path.join(self.strRoot, strHashSubdirectory)
    self.tLog.debug('Try to get the platform independent configuration from "%s".', strCfgPath)
    if self.pl.path.exists(strCfgPath)~=strCfgPath or self.pl.path.exists(strHashPath)~=strHashPath then
      -- Try the platform specific version.
      strCurrentPlatform = self.tPlatform:get_platform_id('_')
      strCfgSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml', self.strConfig)
      strHashSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml.hash', self.strConfig)
      -- Append the version folder to the root.
      -- FIXME: First check if the paths are already absolute. In this case do not append the root folder.
      strCfgPath = self.pl.path.join(self.strRoot, strCfgSubdirectory)
      strHashPath = self.pl.path.join(self.strRoot, strHashSubdirectory)
      self.tLog.debug('Try to get the platform specific configuration for "%s" from "%s".', strCurrentPlatform, strCfgPath)
      if self.pl.path.exists(strCfgPath)~=strCfgPath or self.pl.path.exists(strHashPath)~=strHashPath then
        tResult = nil
        self.tLog.error('No platform independent or platform specific configuration file found for %s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())
      end
    end

    if tResult==true then
      -- Get the complete file.
      -- Read it as binary to prevent the conversion of the linefeed. This would give a wrong hash sum.
      local strCfg, strError = self.pl.utils.readfile(strCfgPath, true)
      if strCfg==nil then
        tResult = nil
        self.tLog.error('Failed to read the configuration file "%s": %s', strCfgPath, strError)
        self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
      else
        -- Get the hash sum.
        tResult, strError = self.pl.utils.readfile(strHashPath, false)
        if tResult==nil then
          self.tLog.error('Failed to get the hash sum of "%s": %s', strCfgPath, strError)
          self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
        else
          local strHash = tResult

          -- Check the hash sum.
          tResult = self.hash:check_string(strCfg, strHash, strCfgPath, strHashPath)
          if tResult~=true then
            self.tLog.error('The hash sum of the configuration "%s" does not match.', strCfgPath)
            self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
            tResult = nil
          else
            local cA = self.ArtifactConfiguration(self.cLog)
            tResult = cA:parse_configuration(strCfg, strCfgPath)
            if tResult~=true then
              tResult = nil
              self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
            else
              -- Compare the GMAVP from the configuration with the requested values.
              tResult = cA:check_configuration(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform)
              if tResult~=true then
                self.tLog.error('%s The configuration for artifact %s/%s does not match the requested group/module/artifact/version/platform.', self.strID, strGMAV, strCurrentPlatform)
                self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
                tResult = nil
              else
                tResult = cA
                self.uiStatistics_GetConfiguration_Success = self.uiStatistics_GetConfiguration_Success + 1
                self.uiStatistics_ServedBytesConfig = self.uiStatistics_ServedBytesConfig + string.len(strCfg)
                self.uiStatistics_ServedBytesConfigHash = self.uiStatistics_ServedBytesConfigHash + string.len(strHash)
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



function RepositoryDriverFilesystem:get_artifact(cArtifact, strDestinationFolder)
  -- Does the root folder of the repository exist?
  local tResult = self:exists()
  if tResult~=true then
    self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
  else
    local tInfo = cArtifact.tInfo
    local strGroup = tInfo.strGroup
    local strModule = tInfo.strModule
    local strArtifact = tInfo.strArtifact
    local tVersion = tInfo.tVersion
    local strPlatform = tInfo.strPlatform
    local strExtension = tInfo.strExtension

    -- Construct the artifact path.
    local strArtifactSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strPlatform, strExtension, self.strArtifact)
    local strHashSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strPlatform, string.format('%s.hash', strExtension), self.strArtifact)

    -- Append the version folder to the root.
    -- FIXME: First check if the paths are already absolute. In this case do not append the root folder.
    local strArtifactPath = self.pl.path.join(self.strRoot, strArtifactSubdirectory)
    local strHashPath = self.pl.path.join(self.strRoot, strHashSubdirectory)

    -- Get the file name.
    local _, strFileName = self.pl.path.splitpath(strArtifactPath)

    -- Copy the file to the destination folder.
    local strLocalFile = self.pl.path.join(strDestinationFolder, strFileName)
    local strError
    tResult, strError = self.pl.file.copy(strArtifactPath, strLocalFile)
    if tResult~=true then
      tResult = nil
      self.tLog.error('Failed to copy the artifact to the depack folder: %s', strError)
      self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
    else
      -- Get tha SHA sum.
      tResult, strError = self.pl.utils.readfile(strHashPath, true)
      if tResult==nil then
        self.tLog.error('Failed to get the hash sum of "%s".', strArtifactPath)
        self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
      else
        local strHash = tResult

        -- Compare the hash sums.
        tResult = self.hash:check_file(strLocalFile, strHash, strHashPath)
        if tResult~=true then
          self.tLog.error('The hash sum of the artifact "%s" does not match.', strArtifactPath)
          self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
        else
          tResult = strLocalFile
          self.uiStatistics_GetArtifact_Success = self.uiStatistics_GetArtifact_Success + 1
          self.uiStatistics_ServedBytesArtifact = self.uiStatistics_ServedBytesArtifact + self.pl.path.getsize(strLocalFile)
          self.uiStatistics_ServedBytesArtifactHash = self.uiStatistics_ServedBytesArtifactHash + string.len(strHash)
        end
      end
    end
  end

  return tResult
end



function RepositoryDriverFilesystem:__tostring()
  local tRepr = {}
  table.insert(tRepr, 'RepositoryDriverFilesystem(')
  table.insert(tRepr, string.format('\tid = "%s"', self.strID))
  table.insert(tRepr, string.format('\tcacheable = "%s"', tostring(self.fCacheable)))
  table.insert(tRepr, string.format('\troot = "%s"', self.strRoot))
  table.insert(tRepr, string.format('\tversions = "%s"', self.strVersions))
  table.insert(tRepr, string.format('\tconfig = "%s"', self.strConfig))
  table.insert(tRepr, string.format('\tartifact = "%s"', self.strArtifact))
  table.insert(tRepr, ')')
  local strRepr = table.concat(tRepr, '\n')

  return strRepr
end


return RepositoryDriverFilesystem
