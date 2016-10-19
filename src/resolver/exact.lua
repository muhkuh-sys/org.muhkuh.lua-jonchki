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
  self:add_to_ga_v(cArtifact.tInfo.strGroup, cArtifact.tInfo.strArtifact, cArtifact.tInfo.tVersion, strSourceID)

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



function ResolverExact:select_version_by_constraints(atVersions, atConstraints)
  local fResult = true
  local tResult = nil
  local strMessage = ''

  -- In "exact" mode there must be one single constraint with an exact version number.
  -- An empty string means any version, first match.
  local strConstraint = nil
  for strC,_ in pairs(atConstraints) do
    if strConstraint==nil then
      -- This is the first constraint.
      strConstraint = strC
    elseif strConstraint=='' and strC~='' then
      -- The current constraint is "anything" and the new constraint is a real one.
      strConstraint = strC
    elseif strC=='' then
      -- '' can be combined with anything as it means any version, first match.
    elseif strConstraint~=strC then
      -- There are several different constraints. This is not possible in "exact" mode.
      fResult = false
      strMessage = 'More than one different constraint!'
      break
    end
  end
  print(string.format('Constraint: %s', strConstraint))

  if fResult==true then
    -- Try to parse the constraint as a version.
    local tVersion = self.Version()
    fResult, strMessage = tVersion:set(strConstraint)
    if fResult==true then
      -- Look for the exact version string.
      local fFound = false
      for tV, atVers in pairs(atVersions) do
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
  end

  return tResult, strMessage
end



function ResolverExact:resolve(cArtifact)
  -- Start with clean resolver tables.
  self:clear_resolve_tables()
  self.atEnforcement = {}

  -- Write the artifact to the resolve table.
  self:resolve_set_start_artifact(cArtifact)

  -- Execute one resolve step.
  self:resolve_step()
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function ResolverExact:__tostring()
  local strRepr = string.format('ResolverExact(id="%s")', self.strID)

  return strRepr
end


return ResolverExact
