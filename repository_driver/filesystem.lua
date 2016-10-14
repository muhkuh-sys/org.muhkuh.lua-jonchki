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



function RepositoryDriverFilesystem:getArtifactConfiguration(strGroup, strArtifact, tVersion)
  local tResult, strError = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the config path.
    local strConfig = self:replace_path(strGroup, strArtifact, tVersion, self.strConfig)

    -- Append the config path to the root.
    local strConfigPath = self.pl.path.join(self.strRoot, strConfig)

    -- Is the configuration a file?
    if self.pl.path.isfile(strConfigPath)~=true then
      tResult = false
      strError = string.format('The artifact configuration at "%s" is no file.', strConfigPath)
    else
      -- Read the complete configuration.
      local tArtifact = self.ArtifactConfiguration()
      tResult, strError = tArtifact:parse_configuration(strConfigPath)
      if tResult==true then
        tResult = tArtifact
      end
    end
  end

  return tResult, strError
end



function RepositoryDriverFilesystem:get_available_versions(tArtifact)
  local tResult, strError = self:exists()
  if tResult==true then
    -- Replace the artifact placeholder in the versions path.
    local strVersions = self:replace_path(tArtifact.strGroup, tArtifact.strArtifact, tArtifact.tVersion, self.strVersions)

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
          -- For a test get the artifact configuration.
          local tArtifact, strError = self:getArtifactConfiguration(tArtifact.strGroup, tArtifact.strArtifact, tVersion)
          print(tArtifact, strError)
          
          table.insert(atVersions, tVersion)
        end
      end
    end

    tResult = atVersions
    strError = nil
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
