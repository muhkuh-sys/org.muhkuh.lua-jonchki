--- Policy 001
-- Policy 001 only accepts exact matches.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2017 Christoph Thelen

-- Create the configuration class.
local class = require 'pl.class'
local Policy = require 'resolver.policies.policy'
local Policy001 = class(Policy)


--- Initialize a new instance of a Policy001.
function Policy001:_init(cLogger)
  self:super(cLogger, '001')

  -- This is a GA->V map of all used artifacts. It is used to check if each GA pair has the same version.
  self.atEnforcement = {}
end



function Policy001:add_enforcement(cArtifact, cArtifactParent)
  local tResult = nil
  local tContinue = nil

  -- Combine the group and artifact.
  local strGA = string.format('%s/%s', cArtifact.tInfo.strGroup, cArtifact.tInfo.strArtifact)

  -- Get the artifact version.
  local strVersionArtifact = tostring(cArtifact.tInfo.tVersion)

  -- Is the GA already registered?
  local atGA = self.atEnforcement[strGA]
  if atGA==nil then
    -- No, register GA->V now.
    atGA = {
      version = strVersionArtifact,
      required_by = { cArtifactParent }
    }
    self.atEnforcement[strGA] = atGA

    tResult = true
    tContinue = true
  else
    -- Yes -> compare the versions.

    -- Get the version.
    local strVersionRegistered = atGA.version
    -- Do the versions match?
    if strVersionRegistered==strVersionArtifact then
      -- Yes, that's OK.
      table.insert(atGA.required_by, cArtifactParent)
      tResult = true
      tContinue = false
    else
      -- This is an error!
      tResult = false
      tContinue = false
    end
  end

  return tResult, tContinue
end



function Policy001:select_version_by_constraints(atVersions, strConstraint)
  local tResult = nil

  -- In "exact" mode there must be an exact version number.
  -- Try to parse the constraint as a version.
  local tVersion = self.Version()
  local fResult, strMessage = tVersion:set(strConstraint)
  if fResult==true then
    -- Look for the exact version string.
    local fFound = false
    for tV, _ in pairs(atVersions) do
      if tV:get()==strConstraint then
        fFound = true
        break
      end
    end

    if fFound==true then
      tResult = tVersion
    else
      strMessage = string.format('No matching version found for exact constraint "%s".', strConstraint)
    end
  end

  return tResult, strMessage
end

return Policy001
