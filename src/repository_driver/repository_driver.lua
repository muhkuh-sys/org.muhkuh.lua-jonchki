--- The base class for all repository drivers.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local RepositoryDriver = class()


--- Initialize a new instance of a repository driver.
-- @param strID The ID used in the the jonchkicfg.xml to reference this instance.
function RepositoryDriver:_init(tLogger, strID)
  self.tLogger = tLogger
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.Version = require 'Version'

  local cHash = require 'Hash'
  self.hash = cHash(tLogger)
end



function RepositoryDriver:get_id()
  return self.strID
end



function RepositoryDriver:replace_path(strGroup, strModule, strArtifact, tVersion, strExtension, strTemplate)
  -- Convert the group to a list of folders.
  local strSlashGroup = self.pl.stringx.replace(strGroup, '.', '/')

  -- Get the version string if there is a version object.
  local strVersion = nil
  if tVersion~=nil then
    strVersion = tVersion:get()
  end

  -- Construct the replace table.
  local atReplace = {
    ['dotgroup'] = strGroup,
    ['group'] = strSlashGroup,
    ['module'] = strModule,
    ['artifact'] = strArtifact,
    ['version'] = strVersion,
    ['extension'] = strExtension
  }

  -- Replace the keywords.
  return string.gsub(strTemplate, '%[(%w+)%]', atReplace)
end



-- scan the repository for available versions.
function RepositoryDriver:get_available_versions(strGroup, strModule, strArtifact)
  error('This is the function "get_available_versions" in the base class "RepositoryDriver". It must be overwritten!')
end



-- retrieve an artifact
function RepositoryDriver:retrieve(tArtifact, strArtifactDestination, strConfigDestination)

end



--- Return the complete configuration as a string.
-- @return The configuration as a string.
function RepositoryDriver:__tostring()
  local strRepr = string.format('RepositoryDriver(id="%s")', self.strID)

  return strRepr
end


return RepositoryDriver
