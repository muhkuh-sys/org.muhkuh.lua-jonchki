--- A resolver which accepts exact matches only.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Resolver = require 'resolver.resolver'
local ResolverExact = class(Resolver)


--- Initialize a new instance of the exact resolver.
-- @param strID The ID identifies the resolver.
function ResolverExact:_init(strID)
  self:super(strID)

  -- This is a GA->V map of all used artifacts. It is used to check if each GA pair has the same version.
  self.atEnforcement = {}
end



function ResolverExact:add_enforcement(cArtifact, cArtifactParent)
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



function ResolverExact:resolve_process_artifact(cArtifact, cArtifactParent, strSourceID)
  -- Add the current artifact to the GA->V table.
  self:add_to_ga_v(cArtifact, strSourceID)

  -- Add the current version to the enforcement table
  local tResult,tContinue = self:add_enforcement(cArtifact, cArtifactParent)
  if tResult~=true then
    error('Failed to process artifact')
  end

  if tContinue==true then
    -- Loop over all dependencies.
    for _,tDependency in pairs(cArtifact.atDependencies) do
      self:search_artifact(tDependency)
    end
  end
end



function ResolverExact:resolve(cArtifact)
  self:clear_resolve_tables()

  self:resolve_process_artifact(cArtifact, nil, '')
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function ResolverExact:__tostring()
  local strRepr = string.format('ResolverExact(id="%s")', self.strID)

  return strRepr
end


return ResolverExact
