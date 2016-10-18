--- The resolver base class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Resolver = class()


--- Initialize a new instance of the exact resolver.
-- @param strID The ID identifies the resolver.
function Resolver:_init(strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.Version = require 'Version'
  
  self.atRepositoryList = nil
  self.atRepositoryByID = nil

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
  -- Create a new GA->V table.
  self.atGA_V = {}
end



function Resolver:get_id()
  return self.strID
end



function Resolver:setRepositories(atRepositoryList)
  -- Store the list.
  self.atRepositoryList = atRepositoryList
  
  -- Create a mapping from the ID -> repository driver.
  local atMap = {}
  for _,tRepository in pairs(atRepositoryList) do
    local strID = tRepository:get_id()
    atMap[strID] = tRepository
  end
  self.atRepositoryByID = atMap
end



function Resolver:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)
  -- Combine the group and artifact.
  local strGA = string.format('%s/%s', strGroup, strArtifact)

  -- Is the GA already registered?
  local atGA = self.atGA_V[strGA]
  if atGA==nil then
    -- No, register GA now.
    atGA = {}
    self.atGA_V[strGA] = atGA
  end

  -- Is the version already registered?
  local strVersion = tVersion:get()
  local atV = atGA[strVersion]
  if atV==nil then
    -- No, register the version now.
    atV = {}
    atGA[strVersion] = atV
  end

  -- Add the source ID.
  local atSrcID = atV[strSourceID]
  if atSrcID==nil then
    atSrcID = {}
    atV[strSourceID] = atSrcID
  end
end



function Resolver:dump_ga_v_table()
  print 'GA_V('

  -- Loop over all GA pairs.
  for strGA, atGA in pairs(self.atGA_V) do
    -- Split the GA pair by the separating slash ('/').
    local aTmp = self.pl.stringx.split(strGA, '/')
    local strGroup = aTmp[1]
    local strArtifact = aTmp[2]
    print(string.format('  G=%s, A=%s', strGroup, strArtifact))

    -- Loop over all versions.
    for tVersion, atV in pairs(atGA) do
      print(string.format('    V=%s:', tVersion))

      -- Loop over all sources.
      print '      sources:'
      for strSrcID,_ in pairs(atV) do
        print(string.format('        %s', strSrcID))
      end
    end
  end
  print ')'
end



function Resolver:search_artifact(tArtifact)
  local strGroup = tArtifact.strGroup
  local strArtifact = tArtifact.strArtifact
  print(string.format("search for %s/%s/%s", strGroup, strArtifact, tArtifact.tVersion:get()))

  -- Loop over the repository list.
  for _, tRepository in pairs(self.atRepositoryList) do
    -- Get the ID of the current repository.
    local strSourceID = tRepository:get_id()
    print(string.format('  ... in repository %s', strSourceID))

    -- Get all available versions in this repository.
    local tResult, strError = tRepository:get_available_versions(strGroup, strArtifact)
    if tResult==nil then
      print(string.format('    failed to scan the repository: %s', strError))
    else
      -- Write all versions to the GA->V table.
      for _, tVersion in pairs(tResult) do
        self:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)
        print(string.format('    %s', tostring(tVersion)))
      end
    end
  end
end



function Resolver:resolvtab_create_entry(strGroup, strArtifact)
  local tResolvEntry = {
    strGroup = strGroup,
    strArtifact = strArtifact,
    eStatus = self.RT_Initialized,
    atConstraints = {},
    atVersions = {},
    ptActiveVersion = nil
  }

  return tResolvEntry
end



function Resolver:resolvtab_add_constraint(tResolvEntry, strConstraint, cDefiningArtifact)
  -- Get a shortcut to the constraints.
  local atConstraints = tResolvEntry.atConstraints

  -- Is this constraint already set?
  local fAlreadyThere = false
  for strC, cA in pairs(atConstraints) do
    if strC==strConstraint and cA==cDefiningArtifact then
      fAlreadyThere = true
      break
    end
  end

  if fAlreadyThere==false then
    atConstraints[strConstraint] = cDefiningArtifact
  end
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



function Resolver:add_versions_from_repositories(tResolv, strGroup, strArtifact)
  local atDuplicateCheck = {}
  local atNewVersions = {}

  -- Loop over the repository list.
  for _, tRepository in pairs(self.atRepositoryList) do
    -- Get the ID of the current repository.
    local strSourceID = tRepository:get_id()

    -- Get all available versions in this repository.
    local tResult, strError = tRepository:get_available_versions(strGroup, strArtifact)
    if tResult==nil then
      print(string.format('Error: failed to scan repository "%s": %s', strSourceID, strError))
    else
      -- Get all unique versions.
      for _, tVersion in pairs(tResult) do
        local strVersion = tVersion:get()
        if atDuplicateCheck[strVersion]==nil then
          atDuplicateCheck[strVersion] = true
          table.insert(atNewVersions, tVersion)
        end
      end
    end
  end

  -- Add all members of the set as new versions.
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
    -- Create a new empty dependency list.
    atV.atDependencies = {}
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil

    -- Loop over all dependencies.
    for _,tDependency in pairs(cA.atDependencies) do
      local strGroup = tDependency.strGroup
      local strArtifact = tDependency.strArtifact
      local tResolv = self:resolvtab_create_entry(strGroup, strArtifact)
      self:add_versions_from_repositories(tResolv, strGroup, strArtifact)
      self:resolvtab_add_constraint(tResolv, tDependency.tVersion:get(), cA)
      table.insert(atV.atDependencies, tResolv)
    end

    tResolvEntry.eStatus = self.RT_ResolvingDependencies
  end
end



function Resolver:resolvetab_dump_resolv(tXml, tResolv)
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

  tXml:addtag('Constraints')
    -- Loop over all constraints.
    for strConstraint, cDefiningArtifact in pairs(tResolv.atConstraints) do
      local strGroup
      local strArtifact
      local strVersion
      if type(cDefiningArtifact)=='table' then
        strGroup = cDefiningArtifact.tInfo.strGroup
        strArtifact = cDefiningArtifact.tInfo.strArtifact
        strVersion = cDefiningArtifact.tInfo.tVersion:get()
      end
      local tAttr = {
          constraint = strConstraint,
          by_group = strGroup,
          by_artifact = strArtifact,
          by_version = strVersion
      }
      tXml:addtag('Constraint', tAttr)
      tXml:up()
    end
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
        self:resolvetab_dump_resolv(tXml, tDependency)
      end
      tXml:up()
    end

    tXml:up()
  end
  tXml:up()

  if tResolv.ptActiveVersion~=nil then
    local atV = tResolv.ptActiveVersion
    local strVersion = atV.cArtifact.tInfo.tVersion:get()
    tXml:addtag('ActiveVersion', { version=strVersion })
    tXml:up()
  end

  tXml:up()
end



function Resolver:resolvetab_dump(strComment)
  -- Dump the resolve table as XML.
  local tXml = self.pl.xml.new('JonchkiResolvtab')

  -- Add the comment.
  if strComment~=nil then
    tXml:addtag('Comment')
    tXml:text(strComment)
    tXml:up()
    tXml:up()
  end

  -- Dump all entries of the resolve table recursively.
  if self.atResolvTab~=nil then
    self:resolvetab_dump_resolv(tXml, self.atResolvTab)
  end

  -- Write the resolve table to a file.
  local strFileName = string.format('jonchki_resolve_tab_%03d.xml', self.uiResolveTabDumpCounter)
  print(string.format('Dump resolve table to %s.', strFileName))
  self.pl.file.write(strFileName, self.pl.xml.tostring(tXml, '', '\t'))
  self.uiResolveTabDumpCounter = self.uiResolveTabDumpCounter + 1
end



function Resolver:resolve_set_start_artifact(cArtifact)
  -- Write the artifact to the resolve table.
  local tResolv = self:resolvtab_create_entry(cArtifact.tInfo.strGroup, cArtifact.tInfo.strArtifact)

  -- Add the current version as the constraint.
  self:resolvtab_add_constraint(tResolv, cArtifact.tInfo.tVersion:get(), '')

  -- Add the current version as the available version.
  self:resolvtab_add_versions(tResolv, {cArtifact.tInfo.tVersion})

  -- Add the configuration to the version.
  self:resolvetab_add_config_to_active_version(tResolv, cArtifact)

  -- Get the available versions for all dependencies.
  self:resolvetab_get_dependency_versions(tResolv)

  -- Set the new element as the root of the resolve table.
  self.atResolvTab = tResolv

  -- Dump the initial resolve table.
  self.uiResolveTabDumpCounter = 0
  self:resolvetab_dump('This is the initial resolve table with just the start artifact.')

  -- Pick the version.
  self:resolvetab_pick_version(tResolv, cArtifact.tInfo.tVersion)
  self:resolvetab_dump('The initial version was picked.')
end



function Resolver:select_version_by_constraints(atVersions, atConstraints)
  error('This is the function "select_version_by_constraints" in the Resolver base class. Overwrite the function!')
end



function Resolver:resolve_step(tResolv)
  -- If no parameter was given, start at the root of the tree.
  local tResolv = tResolv or self.atResolvTab

  local tStatus = tResolv.eStatus
  if tStatus==self.RT_Initialized then
    -- Select a version based on the constraints.
    local tVersion, strMessage = self:select_version_by_constraints(tResolv.atVersions, tResolv.atConstraints)
    if tVersion==nil then
      error('Failed to select a new version: ' .. strMessage)
    else
      self:resolvetab_pick_version(tResolv, tVersion)
    end

    -- Update the status.
    tStatus = tResolv.eStatus

  elseif tStatus==self.RT_GetConfiguration then
    error('Continue here.')
--[[

]]--

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
      if tChildStatus==self.RT_Initialized then
        -- The child is not completely resolved yet.
        tCombinedStatus = self.RT_ResolvingDependencies

      elseif tChildStatus==self.RT_GetConfiguration then
        -- The child is not completely resolved yet.
        tCombinedStatus = self.RT_ResolvingDependencies

      elseif tChildStatus==self.RT_GetDependencyVersions then
        -- The child is not completely resolved yet.
        tCombinedStatus = self.RT_ResolvingDependencies

      elseif tChildStatus==self.RT_ResolvingDependencies then
        -- The child is not completely resolved yet.
        tCombinedStatus = self.RT_ResolvingDependencies

      elseif tChildStatus==self.RT_Resolved then
        -- No change...

      elseif tChildStatus==self.RT_Blocked then
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

  self:resolvetab_dump('Step.')

  return tResultStatus
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function Resolver:__tostring()
  local strRepr = string.format('Resolver(id="%s")', self.strID)

  return strRepr
end



return Resolver
