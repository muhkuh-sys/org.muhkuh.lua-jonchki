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



function Resolver:resolvtab_create_entry(cArtifact)
  local tResolvEntry = {
    strGroup = cArtifact.tInfo.strGroup,
    strArtifact = cArtifact.tInfo.strArtifact,
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
    for tVersion, atVers in pairs(atVersions) do
      if tNewVersion:get()==tVersion:get() then
        atV = atVers
        break
      end
    end

    if atV==nil then
      atV = {
        cArtifact = nil,                     -- the Artifact object
        ptBlockingConstraint = nil,          -- nil if the artifact is not blocked by one of its direct constraints
        ptBlockingDependency = nil           -- nil if the artifact is not blocked by one of its dependencies. A pointer to the first blocking dependency otherwise.
      }
      atVersions[tNewVersion] = atV
    end
  end
end



function Resolver:resolvetab_add_config_to_version(tResolvEntry, cArtifact)
  -- Get a shortcut to the versions.
  local atVersions = tResolvEntry.atVersions

  -- Get the version from the new configuration.
  local tNewVersion = cArtifact.tInfo.tVersion

  -- Search the version.
  local atV = nil
  for tVersion, atVers in pairs(atVersions) do
    if tNewVersion:get()==tVersion:get() then
      atV = atVers
      break
    end
  end
  if atV==nil then
    error('Try to add an artifact class to a non existing version!')
  elseif atV.cArtifact~=nil then
    error('The version has already an artifact class.')
  else
    atV.cArtifact = cArtifact
    atV.ptBlockingConstraint = nil
    atV.ptBlockingDependency = nil
  end
end



function Resolver:resolvetab_dump()
  -- Dump the resolve table as XML.
end



function Resolver:resolve_set_start_artifact(cArtifact)
  -- Write the artifact to the resolve table.
  local tResolv = self:resolvtab_create_entry(cArtifact)

  -- Add the current version as the constraint.
  self:resolvtab_add_constraint(tResolv, cArtifact.tInfo.tVersion:get(), '')

  -- Add the current version as the available version.
  self:resolvtab_add_versions(tResolv, {cArtifact.tInfo.tVersion})

  -- Add the configuration to the version.
  self:resolvetab_add_config_to_version(tResolv, cArtifact)

  -- Set the new element as the root of the resolve table.
  self.atResolvTab = tResolv

  -- Dump the complete resolve table.
  self:resolvetab_dump()
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function Resolver:__tostring()
  local strRepr = string.format('Resolver(id="%s")', self.strID)

  return strRepr
end



return Resolver
