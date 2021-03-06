--- Policy 002
-- Policy 002 picks the highest version starting with a prefix.
--
-- Example: the version constraint is 5.3.1
-- The following versions are available: 5.2.9, 5.3, 5.3.1, 5.3.1.2, 5.3.1.3 and 5.3.3.1
-- The policy will pick 5.3.1.3 . The following list shows why:
-- 
--   5.2.9 is ignored as it does not start with the constraint 5.3.1 .
--   5.3 is also ignored as it has too less components for the constraint Version 5.3.1.
--   5.3.1 matches, but it will looses against 5.3.1.2 in the next step.
--   5.3.1.2 matches and wins over 5.3.1, but it looses agains 5.3.1.3 in the next step.
--   5.3.1.3 matches and wins over 5.3.1.2 . This will be the best candidate.
--   5.3.3.1 is ignored as it does not start with the constraint 5.3.1 .
-- 
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2017 Christoph Thelen

-- Create the configuration class.
local class = require 'pl.class'
local Policy = require 'resolver.policies.policy'
local Policy002 = class(Policy)
local Version = require 'Version'


--- Initialize a new instance of a Policy002.
function Policy002:_init(cLog)
  self:super(cLog, '002')
end



function Policy002:select_version_by_constraints(atVersions, strConstraint)
  local tResult = nil

  -- Try to parse the constraint as a version.
  local tVersionConstraint = self.Version()
  local fResult, strError = tVersionConstraint:set(strConstraint)
  if fResult~=true then
    self.tLog.debug('Failed to parse constraint "%s" as a version: %s', strConstraint, strError)
  else
    -- Access the version components directly.
    local atVCConstraint = tVersionConstraint.atVersion
    local sizVCConstraint = #atVCConstraint

    -- No best version found yet.
    local tVBest = nil
    for tV,atV in pairs(atVersions) do
      -- Only consider unused or active versions.
      -- FIXME: Use the defines from the resolver class here.
      if atV.eStatus==0 or atV.eStatus==1 then
        local atVCVersion = tV.atVersion
        local sizVCVersion = #atVCVersion

        -- The version must have at least as much digits as the constraint.
        if sizVCVersion<sizVCConstraint then
          self.tLog.debug('Ignoring version %s as it has too less components for the constraint %s.', tostring(tV), tostring(tVersionConstraint))
        else
          -- Check if the version has the same start as the constraint.
          local fStartsWithConstraint = true
          for uiCnt=1,sizVCConstraint do
            if atVCConstraint[uiCnt]~=atVCVersion[uiCnt] then
              fStartsWithConstraint = false
              break
            end
          end
          if fStartsWithConstraint~=true then
            self.tLog.debug('Ignoring version %s as it does not start with the constraint %s.', tostring(tV), tostring(tVersionConstraint))
          elseif tVBest==nil then
            self.tLog.debug('Starting with version %s.', tostring(tV), tostring(tVersionConstraint))
            tVBest = tV
          elseif Version.compare(tV, tVBest)>0 then
            self.tLog.debug('Version %s wins over %s.', tostring(tV), tostring(tVBest))
            tVBest = tV
          end
        end
      end
    end

    if tVBest==nil then
      self.tLog.debug('No matching version found.')
    else
      self.tLog.debug('Winner: %s', tostring(tVBest))
      tResult = tVBest
    end
  end

  return tResult
end

return Policy002
