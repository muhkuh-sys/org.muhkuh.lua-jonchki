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

  self.uiStatistics_VersionScans = 0
  self.uiStatistics_GetConfiguration_Success = 0
  self.uiStatistics_GetConfiguration_Error = 0
  self.uiStatistics_GetArtifact_Success = 0
  self.uiStatistics_GetArtifact_Error = 0
  self.uiStatistics_ServedBytesConfig = 0
  self.uiStatistics_ServedBytesConfigHash = 0
  self.uiStatistics_ServedBytesArtifact = 0
  self.uiStatistics_ServedBytesArtifactHash = 0
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



function RepositoryDriver:show_statistics(cReport)
  local strLogID = string.format('[Repository "%s"] ', self:get_id())
  self.tLogger:info('%s Version scans: %d', strLogID, self.uiStatistics_VersionScans)
  self.tLogger:info('%s Configuration requests: %d success / %d error . %d bytes data and %d bytes hash served', strLogID, self.uiStatistics_GetConfiguration_Success, self.uiStatistics_GetConfiguration_Error, self.uiStatistics_ServedBytesConfig, self.uiStatistics_ServedBytesConfigHash)
  self.tLogger:info('%s Artifact requests: %d success / %d error . %d bytes data and %d bytes hash served', strLogID, self.uiStatistics_GetArtifact_Success, self.uiStatistics_GetArtifact_Error, self.uiStatistics_ServedBytesArtifact, self.uiStatistics_ServedBytesArtifactHash)

  cReport:addData(string.format('statistics/repository@id=%s/requests/configuration/success', self.strID), self.uiStatistics_GetConfiguration_Success)
  cReport:addData(string.format('statistics/repository@id=%s/requests/configuration/error', self.strID), self.uiStatistics_GetConfiguration_Error)
  cReport:addData(string.format('statistics/repository@id=%s/served_bytes/configuration', self.strID), self.uiStatistics_ServedBytesConfig)
  cReport:addData(string.format('statistics/repository@id=%s/served_bytes/configuration_hash', self.strID), self.uiStatistics_ServedBytesConfigHash)
  cReport:addData(string.format('statistics/repository@id=%s/requests/artifact/success', self.strID), self.uiStatistics_GetArtifact_Success)
  cReport:addData(string.format('statistics/repository@id=%s/requests/artifact/error', self.strID), self.uiStatistics_GetArtifact_Error)
  cReport:addData(string.format('statistics/repository@id=%s/served_bytes/artifact', self.strID), self.uiStatistics_ServedBytesArtifact)
  cReport:addData(string.format('statistics/repository@id=%s/served_bytes/artifact_hash', self.strID), self.uiStatistics_ServedBytesArtifactHash)
end


return RepositoryDriver
