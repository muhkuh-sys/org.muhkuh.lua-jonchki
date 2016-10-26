--- A repository driver for a filesystem.
-- The repository module provides an abstraction to a number of different
-- repositories. The real work is done by drivers. This is the driver
-- providing access to a repository on a filesystem.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the class.
local class = require 'pl.class'
local RepositoryDriver = require 'repository_driver.repository_driver'
local RepositoryDriverFilesystem = class(RepositoryDriver)



function RepositoryDriverFilesystem:_init(strID)
  -- Set the ID of the repository driver.
  self:super(strID)

  -- Clear the patterns for the configuration and artifact.
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
  self.strRoot = atSettings.strRoot
  self.strVersions = atSettings.strVersions
  self.strConfig = atSettings.strConfig
  self.strArtifact = atSettings.strArtifact
end



function RepositoryDriverFilesystem:exists()
  local tResult
  local strError

  -- Does the root folder exist?
  if self.pl.path.exists(self.strRoot)~=self.strRoot then
    tResult = nil
    strError = string.format('The repository root path "%s" does not exist.', self.strRoot)

  -- Is the root folder really a folder?
  elseif self.pl.path.isdir(self.strRoot)~=true then
    tResult = nil
    strError = string.format('The repository root path "%s" is no directory.', self.strRoot)

  else
    tResult = true
  end

  return tResult, strError
end



function RepositoryDriverFilesystem:get_available_versions(strGroup, strArtifact)
  local tResult, strError = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the versions path.
    local strVersions = self:replace_path(strGroup, strArtifact, nil, self.strVersions)

    -- Append the version folder to the root.
    local strVersionPath = self.pl.path.join(self.strRoot, strVersions)

    -- Continue only if the version folder exists.
    -- If the folder does not exist, there is no matching aritfact.
    local atVersions = {}
    if self.pl.path.isdir(strVersionPath)==true then
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
        end
      end
    end

    tResult = atVersions
    strError = nil
  end

  return tResult, strError
end



function RepositoryDriverFilesystem:get_sha_sum(strMainFile)
  local tResult = nil
  local strError = nil

  -- Get the SHA1 path.
  local strShaPath = strMainFile .. '.sha1'

  -- Get tha SHA sum.
  local strShaRaw, strMsg = self.pl.utils.readfile(strShaPath, false)
  if strShaRaw==nil then
    tResult = nil
    strError = string.format('Failed to read the SHA file "%s": %s', strShaPath, strMsg)
  else
    -- Extract the SHA sum.
    local strMatch = string.match(strShaRaw, '%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x')
    if strMatch==nil then
      tResult = nil
      strError = 'The SHA1 file does not contain a valid hash.'
    else
      tResult = strMatch
      strError = ''
    end
  end

  return tResult, strError
end



function RepositoryDriverFilesystem:get_configuration(strGroup, strArtifact, tVersion)
  -- Does the root folder of the repository exist?
  local tResult, strError = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the configuration path.
    local strCfg = self:replace_path(strGroup, strArtifact, tVersion, self.strConfig)

    -- Append the version folder to the root.
    local strCfgPath = self.pl.path.join(self.strRoot, strCfg)

    -- Get the complete file.
    local strCfg, strMsg = self.pl.utils.readfile(strCfgPath, false)
    if strCfg==nil then
      tResult = nil
      strError = string.format('Failed to read the configuration file "%s": %s', strCfgPath, strMsg)
    else
      -- Get tha SHA sum.
      tResult, strError = self:get_sha_sum(strCfgPath)
      if tResult~=nil then
        local strShaRemote = tResult

        -- Build the local SHA sum.
        local strShaLocal = self.Hash:get_sha1_string(strCfg)

        -- Compare the SHA1 sum from the repository and the local.
        if strShaRemote~=strShaLocal then
          tResult = nil
          strError = 'The SHA1 sum of the configuration does not match.'
        else
          local cA = self.ArtifactConfiguration()
          cA:parse_configuration(strCfg)

          tResult = cA
          strError = nil
        end
      end
    end
  end

  return tResult, strError
end



function RepositoryDriverFilesystem:get_artifact(strGroup, strArtifact, tVersion, strDestinationFolder)
  -- Does the root folder of the repository exist?
  local tResult, strError = self:exists()
  if tResult==true then
    -- Construct the artifact path.
    local strArtifact = self:replace_path(strGroup, strArtifact, tVersion, self.strArtifact)

    -- Append the version folder to the root.
    local strArtifactPath = self.pl.path.join(self.strRoot, strArtifact)
    -- Get the file name.
    local _, strFileName = self.pl.path.splitpath(strArtifactPath)

    -- Copy the file to the destination folder.
    local strLocalFile = self.pl.path.join(strDestinationFolder, strFileName)
    tResult, strError = self.pl.file.copy(strArtifactPath, strLocalFile)
    if tResult~=true then
      tResult = nil
      strError = string.format('Failed to copy the artifact to the depack folder: %s', strError)
    else
      -- Get tha SHA sum.
      tResult, strError = self:get_sha_sum(strArtifactPath)
      if tResult~=nil then
        local strShaRemote = tResult

        -- Compare the SHA sums.
        tResult, strError = self.Hash:check_sha1(strLocalFile, strShaRemote)
        if tResult~=true then
          tResult = nil
          strError = 'The SHA1 sum of the configuration does not match.'
        else
          tResult = strLocalFile
          strError = nil
        end
      end
    end
  end

  return tResult, strError
end



function RepositoryDriverFilesystem:__tostring()
  local tRepr = {}
  table.insert(tRepr, 'RepositoryDriverFilesystem(')
  table.insert(tRepr, string.format('\tid = "%s"', self.strID))
  table.insert(tRepr, string.format('\troot = "%s"', self.strRoot))
  table.insert(tRepr, string.format('\tversions = "%s"', self.strVersions))
  table.insert(tRepr, string.format('\tconfig = "%s"', self.strConfig))
  table.insert(tRepr, string.format('\tartifact = "%s"', self.strArtifact))
  table.insert(tRepr, ')')
  local strRepr = table.concat(tRepr, '\n')

  return strRepr
end

return RepositoryDriverFilesystem
