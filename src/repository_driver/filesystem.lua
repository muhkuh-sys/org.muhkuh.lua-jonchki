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



function RepositoryDriverFilesystem:_init(tLogger, strID)
  -- Set the logger and the ID of the repository driver.
  self:super(tLogger, strID)

  -- Clear the patterns for the configuration and artifact.
  self.fCacheable = nil
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
  -- Replace "~" with the users home folder and make an absolute path from the root.
  self.strRoot = self.pl.path.abspath(self.pl.path.expanduser(atSettings.strRoot))
  -- Replace "~" with the users home folder for the other settings, but do not
  -- change it to absolute paths. It will be appended to the root.
  self.strVersions = self.pl.path.expanduser(atSettings.strVersions)
  self.strConfig = self.pl.path.expanduser(atSettings.strConfig)
  self.strArtifact = self.pl.path.expanduser(atSettings.strArtifact)

  self.tLogger:debug(tostring(self))

  return true
end



function RepositoryDriverFilesystem:exists()
  local tResult

  -- Does the root folder exist?
  if self.pl.path.exists(self.strRoot)~=self.strRoot then
    tResult = nil
    self.tLogger:error('The repository root path "%s" does not exist.', self.strRoot)

  -- Is the root folder really a folder?
  elseif self.pl.path.isdir(self.strRoot)~=true then
    tResult = nil
    self.tLogger:error('The repository root path "%s" is no directory.', self.strRoot)

  else
    tResult = true
  end

  return tResult
end



function RepositoryDriverFilesystem:get_available_versions(strGroup, strModule, strArtifact)
  self.tLogger:debug('Get available versions for %s/%s/%s.', strGroup, strModule, strArtifact)
  local tResult = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the versions path.
    local strVersions = self:replace_path(strGroup, strModule, strArtifact, nil, nil, self.strVersions)

    -- Append the version folder to the root.
    -- FIXME: First check if the path is already absolute. In this case do not append the root folder.
    local strVersionPath = self.pl.path.join(self.strRoot, strVersions)
    self.tLogger:debug('  Looking in path "%s"', strVersionPath)

    -- Continue only if the version folder exists.
    -- If the folder does not exist, there is no matching aritfact.
    local atVersions = {}
    if self.pl.path.isdir(strVersionPath)~=true then
      self.tLogger:debug('The path "%s" does not exist.', strVersionPath)
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
          self.tLogger:debug('  Found version: %s', tVersion:get())
        end
      end
    end

    if #atVersions == 0 then
      self.tLogger:debug('  No versions found.')
    end
    tResult = atVersions
  end

  return tResult
end



function RepositoryDriverFilesystem:get_configuration(strGroup, strModule, strArtifact, tVersion)
  -- Does the root folder of the repository exist?
  local tResult = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the configuration path.
    local strCfgSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, 'xml', self.strConfig)
    local strHashSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, 'xml.hash', self.strConfig)

    -- Append the version folder to the root.
    -- FIXME: First check if the paths are already absolute. In this case do not append the root folder.
    local strCfgPath = self.pl.path.join(self.strRoot, strCfgSubdirectory)
    local strHashPath = self.pl.path.join(self.strRoot, strHashSubdirectory)

    -- Get the complete file.
    -- Read it as binary to prevent the conversion of the linefeed. This would give a wrong hash sum.
    local strCfg, strError = self.pl.utils.readfile(strCfgPath, true)
    if strCfg==nil then
      tResult = nil
      self.tLogger:error('Failed to read the configuration file "%s": %s', strCfgPath, strError)
    else
      -- Get the hash sum.
      tResult, strError = self.pl.util.readfile(strHashPath, false)
      if tResult==nil then
        self.tLogger:error('Failed to get the hash sum of "%s": %s', strCfgPath, strError)
      else
        local strHash = tResult

        -- Check the hash sum.
        tResult = self.hash:check_string(strCfg, strHash, strCfgPath, strHashPath)
        if tResult~=true then
          self.tLogger:error('The hash sum of the configuration "%s" does not match.', strCfgPath)
          tResult = nil
        else
          local cA = self.ArtifactConfiguration(self.tLogger)
          tResult = cA:parse_configuration(strCfg, strCfgPath)
          if tResult~=true then
            tResult = nil
          else
            tResult = cA
          end
        end
      end
    end
  end

  return tResult
end



function RepositoryDriverFilesystem:get_artifact(strGroup, strModule, strArtifact, tVersion, strExtension, strDestinationFolder)
  -- Does the root folder of the repository exist?
  local tResult = self:exists()
  if tResult==true then
    -- Construct the artifact path.
    local strArtifactSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, strExtension, self.strArtifact)
    local strHashSubdirectory = self:replace_path(strGroup, strModule, strArtifact, tVersion, string.format('%s.hash', strExtension), self.strArtifact)

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
      self.tLogger:error('Failed to copy the artifact to the depack folder: %s', strError)
    else
      -- Get tha SHA sum.
      tResult, strError = self.pl.utils.readfile(strHashPath, true)
      if tResult==nil then
        self.tLogger:error('Failed to get the hash sum of "%s".', strArtifactPath)
      else
        local strHash = tResult

        -- Compare the hash sums.
        tResult = self.hash:check_file(strLocalFile, strHash, strHashPath)
        if tResult~=true then
          self.tLogger:error('The hash sum of the artifact "%s" does not match.', strArtifactPath)
        else
          tResult = strLocalFile
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
