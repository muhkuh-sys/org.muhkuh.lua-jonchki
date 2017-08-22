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
end



function Policy001:select_version_by_constraints(atVersions, strConstraint)
  local tResult = nil

  -- In "exact" mode there must be an exact version number.
  -- Try to parse the constraint as a version.
  local tVersion = self.Version()
  local fResult, strError = tVersion:set(strConstraint)
  if fResult~=true then
    self.tLogger:debug('%sFailed to parse constraint "%s" as a version: %s', self.strLogID, strError)
  else
    -- Look for the exact version string.
    local fFound = false
    for tV,atV in pairs(atVersions) do
      -- Only consider unused or active versions.
      -- FIXME: Use the defines from the resolver class here.
      if atV.eStatus==0 or atV.eStatus==1 then
        if tV:get()==strConstraint then
          fFound = true
          break
        end
      end
    end

    if fFound==true then
      tResult = tVersion
    end
  end

  return tResult
end

return Policy001
