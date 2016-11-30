--- The resolver base class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Resolver = class()


--- Initialize a new instance of the exact resolver.
-- @param strID The ID identifies the resolver.
function Resolver:_init(cLogger, strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.Version = require 'Version'

  self.cResolverChain = nil
  self.atRepositoryByID = nil

  self.tLogger = cLogger

  -- This is the state enumeration for a ressolve table entry.
  self.RT_Initialized = 0            -- The structure was initialized, no version picked, no resolving done.
  self.RT_ResolvingDependencies = 1  -- Resolving the dependencies.
  self.RT_GetConfiguration = 2       -- Get the configuration from the repository.
  self.RT_GetDependencyVersions = 3  -- Get the available versions of all dependencies.
  self.RT_Resolved = 4               -- All dependencies resolved. Ready to use.
  self.RT_Blocked = -1               -- Not possible to use.

  -- This is the state enumeration for a version entry.
  self.V_Unused = 0
  self.V_Active = 1
  self.V_Blocked = 2

  self:clear_resolve_tables()
end



function Resolver:clear_resolve_tables()
  -- No resolve table yet.
  self.atResolvTab = nil
end



function Resolver:get_id()
  return self.strID
end



function Resolver:setResolverChain(cResolverChain)
  -- Store the chain.
  self.cResolverChain = cResolverChain
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
    ptActiveVersion = nil
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
        atDependencies = nil,
        ptBlockingConstraint = nil,          -- nil if the artifact is not blocked by one of its direct constraints
        ptBlockingDependency = nil           -- nil if the artifact is not blocked by one of its dependencies. A pointer to the first blocking dependency otherwise.
      }
      atVersions[tNewVersion] = atV
    end
  end
end



function Resolver:add_versions_from_repositories(tResolv, strGroup, strModule, strArtifact)
  -- Add all members of the set as new versions.
  local atNewVersions = self.cResolverChain:get_available_versions(strGroup, strModule, strArtifact)
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
    atV.atDependencies = nil
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil

    -- Download the configuration next.
    tResolvEntry.eStatus = self.RT_GetConfiguration
  end
end



function Resolver:resolvetab_add_config_to_active_version(tResolvEntry, cArtifact)
  -- Get the version from the new configuration.
  local tNewVersion = cArtifact.tInfo.tVersion

  -- Get the active version.
  local atV = tResolvEntry.ptActiveVersion
  if atV==nil then
    error('No active version set!')
  elseif atV.cArtifact~=nil then
    error('The version has already an artifact class.')
  else
    atV.cArtifact = cArtifact

    -- Clear the dependencies for the version.
    atV.atDependencies = nil
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil

    -- Get all available versions next.
    tResolvEntry.eStatus = self.RT_GetDependencyVersions
  end
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

    -- Create a new empty dependency list.
    atV.atDependencies = {}
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil

    -- Loop over all dependencies.
    for _,tDependency in pairs(cA.atDependencies) do
      local strGroup = tDependency.strGroup
      local strModule = tDependency.strModule
      local strArtifact = tDependency.strArtifact
      local tResolv = self:resolvtab_create_entry(strGroup, strModule, strArtifact, tResolvEntry)
      self:add_versions_from_repositories(tResolv, strGroup, strModule, strArtifact)
      self:resolvtab_set_constraint(tResolv, tDependency.tVersion:get())
      table.insert(atV.atDependencies, tResolv)
    end

    tResolvEntry.eStatus = self.RT_ResolvingDependencies
  end
end



function Resolver:toxml_resolv(tXml, tResolv)
  -- Get the status.
  local atStatusNames = {
    [self.RT_Initialized] = 'initialized, selecting version...',
    [self.RT_GetConfiguration] = 'get the configuration...',
    [self.RT_GetDependencyVersions] = 'get the available versions for all dependencies...',
    [self.RT_ResolvingDependencies] = 'resolving the dependencies...',
    [self.RT_Resolved] = 'resolved',
    [self.RT_Blocked] = 'blocked'
  }
  local strStatus = atStatusNames[tResolv.eStatus]
  if strStatus==nil then
    strStatus = 'unknown'
  end

  local tAttrib = {
    group = tResolv.strGroup,
    artifact = tResolv.strArtifact,
    status = strStatus
  }
  tXml:addtag('Resolv', tAttrib)

  tXml:addtag('Constraint')
  tXml:text(tResolv.strConstraint)
  tXml:up()

  tXml:addtag('Versions')
  for tVersion, atV in pairs(tResolv.atVersions) do
    local strVersion = tVersion:get()

    local astrStatus = {
      [self.V_Unused] = 'unused',
      [self.V_Active] = 'active',
      [self.V_Blocked] = 'blocked'
    }
    local strStatus = astrStatus[atV.eStatus]
    if strStatus==nil then
      strStatus = 'unknown'
    end
    tXml:addtag('Version', { version=strVersion, status=strStatus })
    local cArtifact = atV.cArtifact
    if cArtifact~=nil then
      cArtifact:toxml(tXml)
    end

    if atV.ptBlockingConstraint~=nil then
      tXml:addtag('BlockingConstraint')
      tXml:up()
    end

    if atV.ptBlockingDependency~=nil then
      tXml:addtag('BlockingDependency')
      tXml:up()
    end

    -- Dump the dependencies.
    if atV.atDependencies~=nil then
      tXml:addtag('Dependencies')
      for _,tDependency in pairs(atV.atDependencies) do
        self:toxml_resolv(tXml, tDependency)
      end
      tXml:up()
    end

    tXml:up()
  end
  tXml:up()

  if tResolv.ptActiveVersion~=nil then
    local atV = tResolv.ptActiveVersion
    local strVersion = atV.tVersion:get()
    tXml:addtag('ActiveVersion', { version=strVersion })
    tXml:up()
  end

  tXml:up()
end



function Resolver:toxml(tXml)
  -- Dump the resolve table as XML.
  tXml:addtag('JonchkiResolvtab')

  -- Dump all entries of the resolve table recursively.
  if self.atResolvTab~=nil then
    self:toxml_resolv(tXml, self.atResolvTab)
  end

  tXml:up()
end



function Resolver:resolve_set_start_artifact(cArtifact)
  -- Start writing dumps with 000.
  self.uiResolveTabDumpCounter = 0

  -- Write the artifact to the resolve table.
  local tResolv = self:resolvtab_create_entry(cArtifact.tInfo.strGroup, cArtifact.tInfo.strModule, cArtifact.tInfo.strArtifact, nil)

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

  -- Get the available versions for all dependencies.
  self:resolvetab_get_dependency_versions(tResolv)
end



function Resolver:select_version_by_constraints(atVersions, strConstraint)
  error('This is the function "select_version_by_constraints" in the Resolver base class. Overwrite the function!')
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
    error(string.format('Internal error: got strange result from recursive resolve step: %s', tostring(tChildStatus)))
  end

  return fIsDone
end



function Resolver:resolve_step(tResolv)
  -- If no parameter was given, start at the root of the tree.
  local tResolv = tResolv or self.atResolvTab

  local tStatus = tResolv.eStatus
  if tStatus==self.RT_Initialized then
    -- Select a version based on the constraints.
    local tVersion, strMessage = self:select_version_by_constraints(tResolv.atVersions, tResolv.strConstraint)
    if tVersion==nil then
      self.tLogger:error('Failed to select a new version for %s/%s/%s: %s', tResolv.strGroup, tResolv.strModule, tResolv.strArtifact, strMessage)
      -- The item is now blocked.
      tResolv.eStatus = self.RT_Blocked
    else
      self:resolvetab_pick_version(tResolv, tVersion)
    end

    -- Update the status.
    tStatus = tResolv.eStatus

  elseif tStatus==self.RT_GetConfiguration then
    -- Get the GAV parameters.
    local strGroup = tResolv.strGroup
    local strModule = tResolv.strModule
    local strArtifact = tResolv.strArtifact
    local tVersion = tResolv.ptActiveVersion.tVersion

    local tResult = self.cResolverChain:get_configuration(strGroup, strModule, strArtifact, tVersion)
    if tResult==nil then
      -- The configuration file could not be retrieved.
      self.tLogger:info('Failed to get the configuration file for %s/%s/%s/%s: %s', strGroup, strModule, strArtifact, tVersion:get(), strMessage)

      -- This item is now blocked.
      tResolv.eStatus = self.RT_Blocked
    else
      -- Add the configuration to the active configuration.
      self:resolvetab_add_config_to_active_version(tResolv, tResult)

      -- Update the status.
      tStatus = self.RT_GetDependencyVersions

    end
  elseif tStatus==self.RT_GetDependencyVersions then
    self:resolvetab_get_dependency_versions(tResolv)

    -- Update the status.
    tStatus = tResolv.eStatus

  elseif tStatus==self.RT_ResolvingDependencies then
    -- Loop over all dependencies.
    -- Set the default status to "resolved". This is good for empty lists.
    local tCombinedStatus = self.RT_Resolved
    for _,tDependency in pairs(tResolv.ptActiveVersion.atDependencies) do
      local tChildStatus = self:resolve_step(tDependency)
      local fIsDone = self:is_done(tChildStatus)
      if fIsDone==true then
        -- No change...
      elseif fIsDone==false then
        -- The child is not completely resolved yet.
        tCombinedStatus = self.RT_ResolvingDependencies
      else
        -- That's an error. Stop processing the other children.
        tCombinedStatus = self.RT_Blocked
        break
      end
    end

    -- Set the new status for the current object.
    tResolv.eStatus = tCombinedStatus
    tStatus = tCombinedStatus

  elseif tStatus==self.RT_Resolved then
    -- Pass this up.

  elseif tStatus==self.RT_Blocked then
    -- Pass this up.

  end

--  self.cLogger:log_resolve_status(self, 'Step.')

  return tStatus
end



function Resolver:resolve_loop(tResolv)
  local fIsDone

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

  return fIsDone
end



-- Get all dependencies. This is a list of all artifacts except the root in the resolve table.
function Resolver:get_all_dependencies(tResolv, atArtifacts, fIsRoot)
  tResolv = tResolv or self.atResolvTab
  atArtifacts = atArtifacts or {}
  -- If no third argument is specified, assume this is the root.
  if fIsRoot==nil then
    fIsRoot = true
  end

  -- Get the active version.
  local atV = tResolv.ptActiveVersion
  if atV==nil then
    error('No active version!')
  end

  -- Do not add the root artifact.
  if fIsRoot==false then
    -- Get the group, artifact and version.
    local strGroup = tResolv.strGroup
    local strModule = tResolv.strModule
    local strArtifact = tResolv.strArtifact
    local tVersion = atV.tVersion
    local strVersion = tVersion:get()

    -- Is the GMA already in the list?
    local fNotThereYet = true
    for _, tAttr in pairs(atArtifacts) do
      -- Yes, there is an entry. Now check the version.
      if strGroup==tAttr.strGroup and strModule==tAttr.strModule and strArtifact==tAttr.strArtifact then
        -- Get the entries version.
        local strEntryVersion = tAttr.tVersion:get()
        -- Compare the version.
        if strVersion==strEntryVersion then
          fNotThereYet = false
        else
          -- The version differs.
          error(string.format('More than one version found for %s/%s: %s and %s .', strGroup, strArtifact, strVersion, strEntryVersion))
        end
      end
    end

    if fNotThereYet==true then
      local atGMAV = {
        ['strGroup'] = strGroup,
        ['strModule'] = strModule,
        ['strArtifact'] = strArtifact,
        ['tVersion'] = tVersion
      }
      table.insert(atArtifacts, atGMAV)
    end
  end

  -- Loop over all dependencies.
  local atDependencies = atV.atDependencies
  if atDependencies~=nil then
    for _, tDependency in pairs(atDependencies) do
      self:get_all_dependencies(tDependency, atArtifacts, false)
    end
  end

  -- Return the list of artifacts.
  return atArtifacts
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function Resolver:__tostring()
  local strRepr = string.format('Resolver(id="%s")', self.strID)

  return strRepr
end



return Resolver
