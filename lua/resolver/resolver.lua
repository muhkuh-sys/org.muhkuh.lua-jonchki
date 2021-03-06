--- The resolver base class.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2017 Christoph Thelen

-- Create the configuration class.
local class = require 'pl.class'
local Resolver = class()


--- Initialize a new instance of the exact resolver.
-- @param strID The ID identifies the resolver.
function Resolver:_init(cLog, cReport, strID, fInstallBuildDependencies)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.Version = require 'Version'

  self.cResolverChain = nil
  self.atRepositoryByID = nil

  self.tDependencyLog = nil

  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[Resolver] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  self.tReport = cReport

  self.fInstallBuildDependencies = fInstallBuildDependencies

  -- This is the state enumeration for a ressolve table entry.
  self.RT_Initialized = 0            -- The structure was initialized, no version picked, no resolving done.
  self.RT_ResolvingDependencies = 1  -- Resolving the dependencies.
  self.RT_GetConfiguration = 2       -- Get the configuration from the repository.
  self.RT_PickDependencyGroup = 3    -- Select the next dependency group.
  self.RT_GetDependencyVersions = 4  -- Get the available versions of all dependencies.
  self.RT_Resolved = 5               -- All dependencies resolved. Ready to use.
  self.RT_Blocked = -1               -- Not possible to use.

  -- This is the state enumeration for a version entry.
  self.V_Unused = 0
  self.V_Active = 1
  self.V_Blocked = 2

  self:clear_resolve_tables()

  self.atPolicies = {}
  self.atPolicyDefaultList = {}
  self.atPolicyOverrides = {}
end



function Resolver:load_policies(cProjectConfiguration)
  -- This is a list of the policies to load. The entries are appended to
  -- "resolver.policies.policy", so that "001" results in
  -- "resolver.policies.policy001".
  -- Note that the entries here must not match the ID of a class.
  local astrPolicyClassID = {
    '001',
    '002'
  }

  -- This table will hold all loaded policies in the form ID -> policy class .
  local atPolicies = {}

  local fResult = true
  for _, strPolicyClassID in ipairs(astrPolicyClassID) do
    -- Create the complete class name.
    local strPolicy = string.format('resolver.policies.policy%s', strPolicyClassID)
    -- Get the class.
    local cPolicy = require(strPolicy)
    -- Create an instance of the class.
    local tPolicy = cPolicy(self.cLog)
    -- Get the ID from the instance.
    local strPolicyID = tPolicy:get_id()
    -- The class must have an ID. Empty IDs are not good.
    if strPolicyID==nil then
      self.tLog.fatal('Failed to load policy from "%s". No ID set.', strPolicy)
      fResult = nil

    -- The ID is used to identify the class, so it has to be unique.
    elseif atPolicies[strPolicyID]~=nil then
      self.tLog.fatal('Failed to load policy from "%s". The ID "%s" is already used.', strPolicy, strPolicyID)
      fResult = nil

    else
      self.tLog.info('Adding policy "%s" from "%s".', strPolicyID, strPolicy)
      atPolicies[strPolicyID] = tPolicy
    end
  end

  if fResult==true then
    self.atPolicies = atPolicies

    -- Set the default policy list.
    local atPolicyDefaultList = self:create_policy_list(cProjectConfiguration.atPolicyListDefault)
    if atPolicyDefaultList==nil then
      fResult = nil

    else
      self.atPolicyDefaultList = atPolicyDefaultList

      -- Parse the overrides here. They are defined in the project configuration.
      for strItem, atOverrides in pairs(cProjectConfiguration.atPolicyListOverrides) do
        local atPolicyList = self:create_policy_list(atOverrides)
        if atPolicyList==nil then
          fResult = nil
          break

        else
          self.atPolicyOverrides[strItem] = atPolicyList
        end
      end
    end
  end

  return fResult
end



function Resolver:create_policy_list(astrPolicyIDs)
  local atPolicyList = {}

  for _, strPolicyID in ipairs(astrPolicyIDs) do
    local tPolicy = self.atPolicies[strPolicyID]
    if tPolicy==nil then
      self.tLog.fatal('Policy "%s" not found!', strPolicyID)
      atPolicyList = nil
      break

    else
      table.insert(atPolicyList, tPolicy)
    end
  end

  return atPolicyList
end



function Resolver:read_dependency_log(strDependencyLogFile)
  local tLog = self.tLog
  local pl = self.pl

  -- Try to read the dependency log.
  if pl.path.exists(strDependencyLogFile)~=strDependencyLogFile then
    tLog.debug('The dependency log file "%s" does not exist.', strDependencyLogFile)
  elseif pl.path.isfile(strDependencyLogFile)~=true then
    tLog.error('The dependency log file "%s" is not a file. Ignoring it for now.', strDependencyLogFile)
  else
    local strDependencyLog, strError = pl.utils.readfile(strDependencyLogFile, false)
    if strDependencyLog==nil then
      tLog.error('Failed to read the dependency log file "%s": %s', strDependencyLogFile, strError)
    else
      local tDependencyLog = require 'DependencyLog'(tLog)
      tDependencyLog:parse_configuration(strDependencyLog, strDependencyLogFile)
      self.tDependencyLog = tDependencyLog
    end
  end
end



function Resolver:clear_resolve_tables()
  -- No resolve table yet.
  self.atResolvTab = nil

  -- Create an empty list of used artifacts.
  self.atUsedArtifacts = {}
end



function Resolver:get_id()
  return self.strID
end



function Resolver:setResolverChain(cResolverChain)
  -- Store the chain.
  self.cResolverChain = cResolverChain
end



function Resolver:_add_to_used_artifacts(tResolvEntry)
  -- Get the group, module and artifact.
  local strGroup = tResolvEntry.strGroup
  local strModule = tResolvEntry.strModule
  local strArtifact = tResolvEntry.strArtifact
  -- Combine them to a key for the list of used artifacts.
  local strKeyGMA = string.format('%s/%s/%s', strGroup, strModule, strArtifact)

  -- Get the active version.
  local atV = tResolvEntry.ptActiveVersion
  if atV==nil then
    error('No active version set!')
  else
    -- Get the current version.
    local tCurrentVersion = atV.tVersion
    local strCurrentVersion = tCurrentVersion:get()

    -- Does the entry for the GMA already exist?
    local atGMA = self.atUsedArtifacts[strKeyGMA]
    if atGMA==nil then
      self.tLog.debug('[RESOLVE] Adding %s to the list of used artifacts.', strKeyGMA)

      atGMA = {}
      atGMA.tVersion = tCurrentVersion
      atGMA.atSources = {}
      table.insert(atGMA.atSources, atV)

      self.atUsedArtifacts[strKeyGMA] = atGMA
    else
      self.tLog.debug('[RESOLVE] %s already exists in the list of used artifacts.', strKeyGMA)

      -- Compare the versions.
      local strExistingVersion = atGMA.tVersion:get()
      if strCurrentVersion~=strExistingVersion then
        self.tLog.error('[RESOLVE] Trying to add version %s of artifact %s, but version %s is already in use.', strCurrentVersion, strKeyGMA, strExistingVersion)
        error('Internal error!')
      else
        -- The version matches, add the version structure to the list of sources.
        table.insert(atGMA.atSources, atV)
      end
    end
  end
end



function Resolver:_collect_used_artifacts(tResolvEntry)
  -- Get the active version.
  local atV = tResolvEntry.ptActiveVersion
  if atV~=nil and tResolvEntry.eStatus~=self.RT_Blocked then
    -- Add the artifact to the list.
    self:_add_to_used_artifacts(tResolvEntry)

    -- Loop over the dependencies.
    local atDependencies = atV.atDependencies
    if atDependencies~=nil then
      for _, tDependency in pairs(atDependencies) do
        self:_collect_used_artifacts(tDependency)
      end
    end
  end
end



function Resolver:_rebuild_used_artifacts()
  -- Clear the list of used artifacts.
  self.atUsedArtifacts = {}

  -- Rebuild the complete table.
  self.tLog.debug('[RESOLVE] Rebuilding the list of used artifacts.')
  self:_collect_used_artifacts(self.atResolvTab)
  self.tLog.debug('[RESOLVE] Finished rebuilding the list of used artifacts.')
end



function Resolver:_get_used_artifact(tResolvEntry)
  local tExistingVersion = nil

  -- Get the group, module and artifact.
  local strGroup = tResolvEntry.strGroup
  local strModule = tResolvEntry.strModule
  local strArtifact = tResolvEntry.strArtifact
  -- Combine them to a key for the list of used artifacts.
  local strKeyGMA = string.format('%s/%s/%s', strGroup, strModule, strArtifact)

  -- Does the entry for the GMA already exist?
  local atGMA = self.atUsedArtifacts[strKeyGMA]
  if atGMA~=nil then
    tExistingVersion = atGMA.tVersion
  end

  return tExistingVersion
end



function Resolver:resolvtab_create_entry(strGroup, strModule, strArtifact, tParentEntry)
  local tResolvEntry = {
    strGroup = strGroup,
    strModule = strModule,
    strArtifact = strArtifact,
    ptParent = nil,
    eStatus = self.RT_Initialized,
    strConstraint = nil,
    atVersions = {},
    ptActiveVersion = nil,
    fIsDouble = nil
  }

  return tResolvEntry
end



function Resolver:resolvtab_set_constraint(tResolvEntry, strConstraint)
  -- Is this constraint already set?
  if tResolvEntry.strConstraint~=nil then
    error('Overwriting an existing constraint.')
  end
  tResolvEntry.strConstraint = strConstraint
end



function Resolver:resolvtab_add_versions(tResolvEntry, atNewVersions)
  -- Get a shortcut to the versions.
  local atVersions = tResolvEntry.atVersions
  for _,tNewVersion in pairs(atNewVersions) do
    -- Is this version already there?
    local atV = nil
    local strNewVersion = tNewVersion:get()
    for tVersion, atVers in pairs(atVersions) do
      if tVersion:get()==strNewVersion then
        atV = atVers
        break
      end
    end

    if atV==nil then
      atV = {
        tVersion = tNewVersion,
        cArtifact = nil,                     -- the Artifact object
        eStatus = self.V_Unused,
        uiCurrentDependencyGroupIndex = nil, -- the index of the dependency group currenty used
        atCurrentDependencyGroup = nil,      -- a link to the current dependency group
        atDependencies = nil,
        ptBlockingConstraint = nil,          -- nil if the artifact is not blocked by one of its direct constraints
        ptBlockingDependency = nil           -- nil if the artifact is not blocked by one of its dependencies. A pointer to the first blocking dependency otherwise.
      }
      atVersions[tNewVersion] = atV
    end
  end
end



function Resolver:add_versions_from_repositories(tResolv)
  local tLog = self.tLog
  local strGroup = tResolv.strGroup
  local strModule = tResolv.strModule
  local strArtifact = tResolv.strArtifact

  local atNewVersions = {}

  -- Was this artifact used before?
  local tExistingVersion = self:_get_used_artifact(tResolv)
  if tExistingVersion~=nil then
    tLog.debug('%s/%s/%s was used before: %s', strGroup, strModule, strArtifact, tExistingVersion:get())

    -- If the artifact was used before, a version is already selected.
    -- Do not change a previously selected version as it might affect the
    -- path leading to the current situation.

    table.insert(atNewVersions, tExistingVersion)
  else
    local tPinnedVersion
    local tDependencyLog = self.tDependencyLog
    if tDependencyLog~=nil then
      tPinnedVersion = tDependencyLog:getVersion(strGroup, strModule, strArtifact)
    end

    if tPinnedVersion~=nil then
      tLog.debug('Found pinned version for %s/%s/%s: %s', strGroup, strModule, strArtifact, tPinnedVersion:get())

      local fFound = false
      -- Check if the fixed version is already present in the cache.
      -- This prevents scanning all repositories for versions.
      fFound = self.cResolverChain:probe_cache(strGroup, strModule, strArtifact, tPinnedVersion)
      if fFound==true then
        tLog.debug('The artifact is in the cache. Add only this version.')
        table.insert(atNewVersions, tPinnedVersion)

      else
        tLog.debug('The artifact was not found in the cache. Scanning the repositories.')

        -- The pinned version is not yet cached, scan the repositories for all
        -- available versions and block all except the pinned version.
        local atAllVersions = self.cResolverChain:get_available_versions(strGroup, strModule, strArtifact)

        local strPinnedVersion = tPinnedVersion:get()
        for _, tVersionCnt in pairs(atAllVersions) do
          local strVersionCnt = tVersionCnt:get()
          if strVersionCnt==strPinnedVersion then
            tLog.debug('Found the pinned version %s.', strVersionCnt)
            table.insert(atNewVersions, tPinnedVersion)
          else
            tLog.debug('Ignoring version %s as it is not the pinned version.', strVersionCnt)
          end
        end
      end
    else
      tLog.debug('%s/%s/%s is not in the dependency log. Do a normal scan.', strGroup, strModule, strArtifact)

      -- The artifact is not part of the dependency log.
      -- Get all available versions from the repositories.
      atNewVersions = self.cResolverChain:get_available_versions(strGroup, strModule, strArtifact)
    end
  end

  -- Append all available versions.
  self:resolvtab_add_versions(tResolv, atNewVersions)
end



function Resolver:resolvetab_pick_version(tResolvEntry, tVersion)
  -- Search the version.
  local atV = nil
  local strVersion = tVersion:get()
  for tV, atVers in pairs(tResolvEntry.atVersions) do
    if tV:get()==strVersion then
      atV = atVers
      break
    end
  end
  if atV==nil then
    error('Try to pick a non existing version!')
  else
    -- Pick the version.
    tResolvEntry.ptActiveVersion = atV

    -- Set the version to active.
    atV.eStatus = self.V_Active

    -- Clear the dependencies for the version.
    atV.uiCurrentDependencyGroupIndex = nil
    atV.atCurrentDependencyGroup = nil
    atV.atDependencies = nil
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil

    -- Add the version to the list of used artifacts.
    self:_add_to_used_artifacts(tResolvEntry)
  end
end



function Resolver:resolvetab_add_config_to_active_version(tResolvEntry, cArtifact)
  -- Get the active version.
  local atV = tResolvEntry.ptActiveVersion
  if atV==nil then
    error('No active version set!')
  elseif atV.cArtifact~=nil then
    error('The version has already an artifact class.')
  else
    atV.cArtifact = cArtifact

    -- Clear the dependencies for the version.
    atV.uiCurrentDependencyGroupIndex = 0
    atV.atCurrentDependencyGroup = nil
    atV.atDependencies = nil
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil
  end
end



function Resolver:resolvetab_get_artifact_configuration(tResolv)
  if tResolv==nil then
    tResolv = self.atResolvTab
  end

  local cA = nil

  -- Get the active version.
  local atV = tResolv.ptActiveVersion
  if atV==nil then
    error('No active version set!')
  else
    -- Get the configuration.
    cA = atV.cArtifact
    if cA==nil then
      error('No artifact configuration set.')
    end
  end

  return cA
end



function Resolver:resolvetab_pick_dependency_group(tResolvEntry)
  local tResult = nil

  -- Get the active version.
  local atV = tResolvEntry.ptActiveVersion
  if atV==nil then
    error('No active version set!')
  else
    -- Get the configuration.
    local cA = atV.cArtifact
    if cA==nil then
      error('No artifact configuration set.')
    end

    local strGMA = string.format('%s/%s/%s', tResolvEntry.strGroup, tResolvEntry.strModule, tResolvEntry.strArtifact)
    local tVersion = atV.tVersion
    self.tLog.debug('[RESOLVE] Pick a dependency group for %s/%s', strGMA, tVersion:get())

    -- Increase the current dependency group index.
    local uiCurrentDependencyGroupIndex = atV.uiCurrentDependencyGroupIndex
    if uiCurrentDependencyGroupIndex==nil then
      error('No current dependency group selected.')
    end
    uiCurrentDependencyGroupIndex = uiCurrentDependencyGroupIndex + 1
    atV.uiCurrentDependencyGroupIndex = uiCurrentDependencyGroupIndex

    local atCurrentDependencyGroup = cA.atDependencies[uiCurrentDependencyGroupIndex]
    atV.atCurrentDependencyGroup = atCurrentDependencyGroup
    if atCurrentDependencyGroup==nil then
      self.tLog.debug('[RESOLVE] No more dependency groups for %s/%s.', strGMA, tVersion:get())
    else
      -- OK, a new dependency group was selected.
      self.tLog.debug('[RESOLVE] Using dependency group %d for %s/%s', uiCurrentDependencyGroupIndex, strGMA, tVersion:get())
      tResult = true
    end
  end

  return tResult
end



function Resolver:resolvetab_get_dependency_versions(tResolvEntry)
  -- Get the active version.
  local atV = tResolvEntry.ptActiveVersion
  if atV==nil then
    error('No active version set!')
  else
    -- Get the configuration.
    local cA = atV.cArtifact
    if cA==nil then
      error('No artifact configuration set.')
    end

    -- Get the current dependency block.
    local uiCurrentDependencyGroupIndex = atV.uiCurrentDependencyGroupIndex
    if uiCurrentDependencyGroupIndex==nil then
      error('No current dependency group selected.')
    end
    local atDependencyGroup = cA.atDependencies[uiCurrentDependencyGroupIndex]
    if atDependencyGroup==nil then
      error('The current dependency group does not exist.')
    end

    local atDependencies
    if self.fInstallBuildDependencies==true then
      atDependencies = atDependencyGroup.atBuildDependencies
    else
      atDependencies = atDependencyGroup.atDependencies
    end

    -- Create a new empty dependency list.
    atV.atDependencies = {}
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil

    -- Loop over all dependencies.
    for _,tDependency in pairs(atDependencies) do
      local strGroup = tDependency.strGroup
      local strModule = tDependency.strModule
      local strArtifact = tDependency.strArtifact
      local tResolv = self:resolvtab_create_entry(strGroup, strModule, strArtifact, tResolvEntry)
      self:add_versions_from_repositories(tResolv)

      -- Set the constraint.
      self:resolvtab_set_constraint(tResolv, tDependency.tVersion:get())

      -- Was this artifact used before?
      local tExistingVersion = self:_get_used_artifact(tResolv)
      if tExistingVersion~=nil then
        -- If the artifact was used before, a version is already selected.
        -- Do not change a previously selected version as it might affect the
        -- path leading to the current situation.

        -- Instead set all available versions except the existing one
        -- to blocked.

        -- The existing version must match the constraint.

        local strExistingVersion = tExistingVersion:get()
        self.tLog.debug('[RESOLVE] The artifact %s/%s/%s is already in use with version %s. Blocking all other available versions.', strGroup, strModule, strArtifact, strExistingVersion)

        local atVMatching
        for tVersionCnt, atVCnt in pairs(tResolv.atVersions) do
          local strVersionCnt = tVersionCnt:get()
          if strVersionCnt==strExistingVersion then
            self.tLog.debug('[RESOLVE] %s is already in use.', strVersionCnt)
            atVMatching = atVCnt
          else
            self.tLog.debug('[RESOLVE] %s -> block', strVersionCnt)
            atVCnt.eStatus = self.V_Blocked
          end
        end

        if atVMatching~=nil then
          local tMatchingVersion = self:select_version(tResolv)
          if tMatchingVersion==nil then
            self.tLog.error('[RESOLVE] %s does not match the constraint -> block', atVMatching.tVersion:get())
            -- The item is now blocked.
            atVMatching.eStatus = self.V_Blocked
          else
            self.tLog.debug('[RESOLVE] The existing version matches the constraint.')
            tResolv.fIsDouble = true
          end
        end
      end

      table.insert(atV.atDependencies, tResolv)
    end
  end
end



function Resolver:resolve_inject_start_gmac(strGroup, strModule, strArtifact, strConstraint)
  -- Count the resolve steps.
  self.uiResolveStepCounter = 0

  -- Write the artifact to the resolve table.
  local tResolv = self:resolvtab_create_entry(strGroup, strModule, strArtifact, nil)
  -- Get all available versions for the artifact.
  self:add_versions_from_repositories(tResolv)

  -- Set the new element as the root of the resolve table.
  self.atResolvTab = tResolv

  -- Add the current version as the constraint.
  self:resolvtab_set_constraint(tResolv, strConstraint)
end



function Resolver:resolve_inject_start_artifact(cArtifact)
  -- Count the resolve steps.
  self.uiResolveStepCounter = 0

  -- Write the artifact to the resolve table.
  local tResolv = self:resolvtab_create_entry(cArtifact.tInfo.strGroup, cArtifact.tInfo.strModule, cArtifact.tInfo.strArtifact, nil)
  -- This is no double for sure.
  tResolv.fIsDouble = false

  -- Set the new element as the root of the resolve table.
  self.atResolvTab = tResolv

  -- Add the current version as the constraint.
  self:resolvtab_set_constraint(tResolv, cArtifact.tInfo.tVersion:get())

  -- Add the current version as the available version.
  self:resolvtab_add_versions(tResolv, {cArtifact.tInfo.tVersion})

  -- Dump the initial resolve table.
--  self.cLogger:log_resolve_status(self, 'This is the initial resolve table with just the start artifact.')

  -- Pick the version.
  self:resolvetab_pick_version(tResolv, cArtifact.tInfo.tVersion)
--  self.cLogger:log_resolve_status(self, 'The initial version was picked.')

  -- Add the configuration to the version.
  self:resolvetab_add_config_to_active_version(tResolv, cArtifact)
--  self.cLogger:log_resolve_status(self, 'Added configuration.')

  -- Pick the next available dependency group.
  local tResult = self:resolvetab_pick_dependency_group(tResolv)
  if tResult==true then
    -- Get the available versions for all dependencies.
    self:resolvetab_get_dependency_versions(tResolv)

    tResolv.eStatus = self.RT_ResolvingDependencies
  else
    tResolv.eStatus = self.RT_Blocked
  end
end



function Resolver:select_version_by_constraints(atVersions, strConstraint)
  error('This is the function "select_version_by_constraints" in the Resolver base class. Overwrite the function!')
end



function Resolver:select_version(tResolv)
  local strGMA = string.format('%s/%s/%s', tResolv.strGroup, tResolv.strModule, tResolv.strArtifact)

  -- Check if another policy list than the default one should be used for this G/M/A combination.
  local atPolicyList = self.atPolicyOverrides[strGMA]
  if atPolicyList==nil then
    atPolicyList = self.atPolicyDefaultList
    self.tLog.debug('[RESOLVE] Using the default policy list.')
  else
    self.tLog.debug('[RESOLVE] Overriding the default policy list.')
  end

  -- Select a version based on the policies.
  -- Loop over all policies until a version was found.
  local tVersion
  for _, tPolicy in ipairs(atPolicyList) do
    local strID = tPolicy:get_id()
    self.tLog.debug('[RESOLVE] Trying policy "%s".', strID)

    tVersion = tPolicy:select_version_by_constraints(tResolv.atVersions, tResolv.strConstraint)
    if tVersion==nil then
      self.tLog.debug('[RESOLVE] No available version found for %s with policy "%s".', strGMA, strID)
    else
      self.tLog.debug('[RESOLVE] Select version %s for %s with policy "%s".', tVersion:get(), strGMA, strID)
      break
    end
  end

  return tVersion
end



function Resolver:is_done(tStatus)
  local fIsDone

  if tStatus==self.RT_Initialized then
    -- Not completely resolved yet.
    fIsDone = false

  elseif tStatus==self.RT_GetConfiguration then
    -- Not completely resolved yet.
    fIsDone = false

  elseif tStatus==self.RT_GetDependencyVersions then
    -- Not completely resolved yet.
    fIsDone = false

  elseif tStatus==self.RT_PickDependencyGroup then
    -- Not completely resolved yet.
    fIsDone = false

  elseif tStatus==self.RT_ResolvingDependencies then
    -- Not completely resolved yet.
    fIsDone = false

  elseif tStatus==self.RT_Resolved then
    -- Completely resolved.
    fIsDone = true

  elseif tStatus==self.RT_Blocked then
    -- Error!
    fIsDone = nil

  else
    -- This is an unknown status from the child resolver.
    error(string.format('Internal error: got strange result from recursive resolve step: %s', tostring(tStatus)))
  end

  return fIsDone
end



function Resolver:resolve_step(tResolv)
  local tLog = self.tLog

  -- If no parameter was given, start at the root of the tree and print the step counter.
  if tResolv==nil then
    tResolv = self.atResolvTab

    -- Increase the step counter.
    local uiResolveStepCounter = self.uiResolveStepCounter
    uiResolveStepCounter = uiResolveStepCounter + 1
    self.uiResolveStepCounter = uiResolveStepCounter

    -- Print the counter.
    tLog.debug('[RESOLVE] **************')
    tLog.debug('[RESOLVE] *  Step %03d  *', uiResolveStepCounter)
    tLog.debug('[RESOLVE] **************')
  end

  local strGMA = string.format('%s/%s/%s', tResolv.strGroup, tResolv.strModule, tResolv.strArtifact)

  local tStatus = tResolv.eStatus
  if tStatus==self.RT_Initialized then
    tLog.debug('[RESOLVE] Select a version for %s', strGMA)
    -- Was the version already selected somewhere else?
    local tVersion = self:_get_used_artifact(tResolv)
    if tVersion==nil then
      -- No version selected yet. Do this now.
      local tVersion = self:select_version(tResolv)
      if tVersion==nil then
        self.tLog.error('[RESOLVE] Failed to select a new version for %s . The item is now blocked.', strGMA)
        -- The item is now blocked.
        tStatus = self.RT_Blocked
      else
        -- This is no double.
        tResolv.fIsDouble = false

        self:resolvetab_pick_version(tResolv, tVersion)

        -- Download the configuration next.
        tStatus = self.RT_GetConfiguration
      end
    else
      -- Check if the version is not blocked.

      -- Search the version.
      local atV = nil
      local strVersion = tVersion:get()
      for tV, atVers in pairs(tResolv.atVersions) do
        if tV:get()==strVersion then
          atV = atVers
          break
        end
      end
      if atV==nil then
        error('Try to use a non existing double!')

      elseif atV.eStatus==self.V_Blocked then
        -- The version was blocked before. Maybe it does not match the constraints.

        -- The item is now blocked.
        tStatus = self.RT_Blocked

      else
        -- The version is already set for this artifact. This is a double.
        tResolv.fIsDouble = true

        -- This item is finished.
        tStatus = self.RT_Resolved
      end
    end

  elseif tStatus==self.RT_GetConfiguration then
    -- Get the GAV parameters.
    local strGroup = tResolv.strGroup
    local strModule = tResolv.strModule
    local strArtifact = tResolv.strArtifact
    local tVersion = tResolv.ptActiveVersion.tVersion

    tLog.debug('[RESOLVE] Get the configuration for %s/%s', strGMA, tVersion:get())

    local tResult = self.cResolverChain:get_configuration(strGroup, strModule, strArtifact, tVersion)
    if tResult==nil then
      -- The configuration file could not be retrieved.
      tLog.info('Failed to get the configuration file for %s/%s.', strGMA, tVersion:get())

      -- This item is now blocked.
      tStatus = self.RT_Blocked
    else
      -- Add the configuration to the active version.
      self:resolvetab_add_config_to_active_version(tResolv, tResult)

      -- Update the status.
      tStatus = self.RT_PickDependencyGroup
    end

  elseif tStatus==self.RT_PickDependencyGroup then
    local tResult = self:resolvetab_pick_dependency_group(tResolv)
    if tResult==true then
      -- Get the versions of all dependencies next.
      tStatus = self.RT_GetDependencyVersions
    else
      -- The item is blocked.
      tStatus = self.RT_Blocked
    end

  elseif tStatus==self.RT_GetDependencyVersions then
    local tVersion = tResolv.ptActiveVersion.tVersion
    tLog.debug('[RESOLVE] Get the available versions for the dependencies for %s/%s', strGMA, tVersion:get())

    self:resolvetab_get_dependency_versions(tResolv)

    -- Update the status.
    tStatus = self.RT_ResolvingDependencies

  elseif tStatus==self.RT_ResolvingDependencies then
    local tVersion = tResolv.ptActiveVersion.tVersion
    tLog.debug('[RESOLVE] Resolve the dependencies for %s/%s', strGMA, tVersion:get())

    -- Loop over all dependencies.
    -- Set the default status to "resolved". This is good for empty lists.
    local tCombinedStatus = self.RT_Resolved
    for _,tDependency in pairs(tResolv.ptActiveVersion.atDependencies) do
      -- Do not process the dependencies again if the artifact was already used.
      if tDependency.fIsDouble==true then
        tLog.debug('[RESOLVE] Already processed %s/%s/%s', tDependency.strGroup, tDependency.strModule, tDependency.strArtifact)
      else
        -- The artifact was not used yet.
        local tChildStatus = self:resolve_step(tDependency)
        local fIsDone = self:is_done(tChildStatus)
        if fIsDone==true then
          -- No change...
        elseif fIsDone==false then
          -- The child is not completely resolved yet.
          tCombinedStatus = self.RT_ResolvingDependencies
          -- Do not process the other children until this one is done.
          break
        else
          -- That's an error. Stop processing the other children.
          tCombinedStatus = self.RT_Blocked
          break
        end
      end
    end

    -- If the combined status is blocked, try another dependency group.
    if tCombinedStatus==self.RT_Blocked then
      -- Pick a new dependency group.
      tStatus = self.RT_PickDependencyGroup
    else
      -- Set the new status for the current object.
      tStatus = tCombinedStatus
    end

  elseif tStatus==self.RT_Resolved then
    -- Pass this up.

  elseif tStatus==self.RT_Blocked then
    -- Pass this up.

  else
    tLog.error('[RESOLVE] %s has an invalid state of %d', strGMA, tStatus)
    error('Internal error!')
  end

  -- Get the old status to detect changes.
  local eOldStatus = tResolv.eStatus

  -- Update the status
  tResolv.eStatus = tStatus

  -- Was the status just changed to "blocked"?
  if eOldStatus~=self.RT_Blocked and tStatus==self.RT_Blocked then
    -- Rebuild the list of used artifacts.
    self:_rebuild_used_artifacts()
  end

  return tStatus
end



function Resolver:resolve_root_and_dependencies(strGroup, strModule, strArtifact, strConstraint)
  local fIsDone

  -- Start with clean resolver tables.
  self:clear_resolve_tables()

  -- Insert the GMAV into the resolve table.
  self:resolve_inject_start_gmac(strGroup, strModule, strArtifact, strConstraint)

  repeat
    -- Execute one resolve step.
    local tStatus = self:resolve_step()

    -- Translate the status to a simple form.
    fIsDone = self:is_done(tStatus)

    local fFinished
    if fIsDone==true then
      fFinished = true
    elseif fIsDone==false then
      fFinished = false
    else
      fFinished = true
    end
  until fFinished==true

  self.tLog.info('[RESOLVE] Finished resolving.')

  return fIsDone
end



function Resolver:resolve(cArtifact)
  local fIsDone

  -- Start with clean resolver tables.
  self:clear_resolve_tables()

  -- Write the artifact to the resolve table.
  self:resolve_inject_start_artifact(cArtifact)

  repeat
    -- Execute one resolve step.
    local tStatus = self:resolve_step()

    -- Translate the status to a simple form.
    fIsDone = self:is_done(tStatus)

    local fFinished
    if fIsDone==true then
      fFinished = true
    elseif fIsDone==false then
      fFinished = false
    else
      fFinished = true
    end
  until fFinished==true

  self.tLog.info('[RESOLVE] Finished resolving.')

  return fIsDone
end



function Resolver:assign_id_recursive(tResolv, uiID, atIdTab, tDependencyLog)
  local strGroup = tResolv.strGroup
  local strModule = tResolv.strModule
  local strArtifact = tResolv.strArtifact
  local strGMA = string.format('%s/%s/%s', strGroup, strModule, strArtifact)

  -- Do not process doubles.
  if tResolv.fIsDouble==false then
    -- Get the active version.
    local atV = tResolv.ptActiveVersion
    if tResolv.fIsDouble==false and atV==nil then
      self.tLog.error('[COLLECT]: %s is no double, but has no active version.', strGMA)
      error('internal error')
    end

    -- The resolv entry must have no ID yet.
    if tResolv.uiID~=nil then
      self.tLog.error('[COUNTING]: %s has already the ID %d.', strGMA, tResolv.uiID)
      error('internal error')
    end

    -- Assign the ID to the resolv entry.
    self.tLog.debug('[COUNTING]: Assign ID %d to %s.', uiID, strGMA)
    tResolv.uiID = uiID
    atIdTab[strGMA] = uiID

    -- Add the item to the dependency log.
    tDependencyLog:addDependency(strGroup, strModule, strArtifact, tResolv.ptActiveVersion.tVersion)

    self.tLog.debug('[COUNTING]: Processing dependencies for %s.', strGMA)
    local atDependencies = atV.atDependencies
    if atDependencies~=nil then
      for _, tDependency in pairs(atDependencies) do
        uiID = uiID + 1
        uiID = self:assign_id_recursive(tDependency, uiID, atIdTab, tDependencyLog)
      end
    end
  end

  return uiID
end



-- Get all dependencies. This is a list of all artifacts except the root in the resolve table.
function Resolver:get_all_dependencies_recursive(tResolv, atArtifacts, atIdTab, fSkipRootArtifact)
  local strGroup = tResolv.strGroup
  local strModule = tResolv.strModule
  local strArtifact = tResolv.strArtifact
  local strGMA = string.format('%s/%s/%s', strGroup, strModule, strArtifact)

  -- Get the active version.
  local atV = tResolv.ptActiveVersion
  if tResolv.fIsDouble==false and atV==nil then
    self.tLog.error('[COLLECT]: %s is no double, but has no active version.', strGMA)
    error('internal error')
  end

  -- Do not add the root artifact if not requested.
  if tResolv.uiID==0 and fSkipRootArtifact==true then
    self.tLog.debug('[COLLECT]: %s is the root artifact. Do not add it to the collect list.', strGMA)

  else
    -- Do not add doubles.
    if tResolv.fIsDouble==true then
      -- TODO: add a reference to the report so that the dependency tree can be displayed correctly.
      self.tLog.debug('[COLLECT]: %s was already processed.', strGMA)

    else
      -- Get the artifact configuration.
      local cArtifact = atV.cArtifact
      local strVersion = cArtifact.tInfo.tVersion:get()

      -- NOTE: This is only a safety check, that no artifact is added twice.
      for _, tAttr in pairs(atArtifacts) do
        local tInfoCnt = tAttr.cArtifact.tInfo
        -- Compare the group, module and artifact.
        if strGroup==tInfoCnt.strGroup and strModule==tInfoCnt.strModule and strArtifact==tInfoCnt.strArtifact then
          -- The GMA is already in the list.

          -- Get the entries version.
          local strEntryVersion = tInfoCnt.tVersion:get()

          self.tLog.error('[COLLECT]: More than one instance found for %s: %s and %s .', strGMA, strVersion, strEntryVersion)
          error('Internal error!')
        end
      end

      self.tLog.debug('[COLLECT]: Found dependency %s/%s.', strGMA, strVersion)

      local tAttr = {
        ['cArtifact'] = cArtifact,
        ['strArtifactPath'] = nil
      }
      table.insert(atArtifacts, tAttr)
    end
  end

  -- Loop over the dependencies of this artifact if this is no double.
  if tResolv.fIsDouble==false then
    self.tLog.debug('[COLLECT]: Processing dependencies for %s.', strGMA)

    local atDependencies = atV.atDependencies
    if atDependencies~=nil then
      for _, tDependency in pairs(atDependencies) do
        self:get_all_dependencies_recursive(tDependency, atArtifacts, atIdTab, fSkipRootArtifact)
      end
    end
  end

  -- Return the list of artifacts.
  return atArtifacts
end



function Resolver:get_all_dependencies(fSkipRootArtifact, tDependencyLog)
  -- Start at the root element of the resolv table.
  local tResolvRoot = self.atResolvTab
  -- Collect all ID assignments in this table.
  local atIdTab = {}

  -- Assign a running number to all used artifacts.
  -- This must be done before building the link chain.
  self:assign_id_recursive(tResolvRoot, 0, atIdTab, tDependencyLog)

  -- Collect all artifacts and build the link information in the report.
  local atArtifacts = self:get_all_dependencies_recursive(tResolvRoot, {}, atIdTab, fSkipRootArtifact)

  return atArtifacts, atIdTab
end



function Resolver:write_artifact_tree_to_report_recursive(tResolv, atIdTab, strParent)
  local strGroup = tResolv.strGroup
  local strModule = tResolv.strModule
  local strArtifact = tResolv.strArtifact
  local strGMA = string.format('%s/%s/%s', strGroup, strModule, strArtifact)

  -- Get the active version.
  local atV = tResolv.ptActiveVersion

  -- Get the entries ID.
  local uiID
  -- Doubles do not have IDs assigned to them.
  if tResolv.fIsDouble==true then
    uiID = atIdTab[strGMA]
    if uiID==nil then
      self.tLog.fatal('[REPORT]: The double %s is not part of the atIdTab.', strGMA)
      error('internal error')
    end
  else
    -- Get the ID from the resolve entry.
    uiID = tResolv.uiID
    if uiID==nil then
      self.tLog.fatal('[REPORT]: The ID of %s is not set and it is not a double.', strGMA)
      error('internal error')
    end
  end
  self.tLog.debug('[REPORT]: Processing %s with ID %d.', strGMA, uiID)
  local strReportPath = string.format('artifacts/artifact@id=%d', uiID)

  -- Set the parent ID.
  -- NOTE: As the "Report" module can only handle unique paths, the ID is set
  --       as the attribute in the path and the leaf value.
  self.tReport:addData(string.format('%s/parent@id=%s', strReportPath, strParent), strParent)

  -- Do not add doubles.
  if tResolv.fIsDouble==false then
    -- Get the artifact configuration.
    local cArtifact = atV.cArtifact

    -- Write the artifact to the report.
    cArtifact:writeToReport(self.tReport, strReportPath)

    -- Loop over the dependencies of this artifact if this is no double.
    self.tLog.debug('[COLLECT]: Processing dependencies for %s.', strGMA)

    local atDependencies = atV.atDependencies
    if atDependencies~=nil then
      for _, tDependency in pairs(atDependencies) do
        self:write_artifact_tree_to_report_recursive(tDependency, atIdTab, tostring(uiID))
      end
    end
  end
end



function Resolver:write_artifact_tree_to_report(atIdTab)
  -- Collect all artifacts and build the link information in the report.
  self:write_artifact_tree_to_report_recursive(self.atResolvTab, atIdTab, 'none')
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function Resolver:__tostring()
  local strRepr = string.format('Resolver(id="%s")', self.strID)

  return strRepr
end



return Resolver
