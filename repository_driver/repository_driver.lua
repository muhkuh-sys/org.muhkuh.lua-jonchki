--- The base class for all repository drivers.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local RepositoryDriver = class()


--- Initialize a new instance of a repository driver.
-- @param strID The ID used in the the jonchkicfg.xml to reference this instance.
function RepositoryDriver:_init(strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.Version = require 'Version'
end



function RepositoryDriver:get_id()
  return self.strID
end



-- scan the repository for available versions.
function RepositoryDriver:get_available_versions(tArtifact)
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
