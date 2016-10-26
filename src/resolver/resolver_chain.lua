--- The resolver chain class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local ResolverChain = class()



--- Initialize a new instance of the resolver chain.
-- @param strID The ID identifies the resolver.
function ResolverChain:_init(strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- The system configuration.
  self.cSystemConfiguration = nil

  -- Create a new chain.
  self.atResolverChain = {}
  -- Mapping from the repository ID to the member of the resolver chain.
  self.atRepositoryByID = {}

  -- Create a new GA->V table.
  self.atGA_V = {}

  -- Get all available repository drivers.
  local atRepositoryDriverClasses = {}
  table.insert(atRepositoryDriverClasses, require 'repository_driver.filesystem')
  self.atRepositoryDriverClasses = atRepositoryDriverClasses
end



function ResolverChain:get_driver_class_by_type(strType)
  local tRepositoryDriverClass = nil

  -- Loop over all available repository driver classes.
  for _, tClass in pairs(self.atRepositoryDriverClasses) do
    -- Does the class support the type?
    if tClass.matches_type(strType)==true then
      tRepositoryDriverClass = tClass
      break
    end
  end

  return tRepositoryDriverClass
end



function ResolverChain:get_driver_by_id(strID)
  local tRepositoryDriver = self.atRepositoryByID[strID]

  return tRepositoryDriver
end



function ResolverChain:set_systemconfig(cSysCfg)
  self.cSystemConfiguration = cSysCfg
end



function ResolverChain:set_repositories(atRepositories)
  -- Create all repository drivers.
  local atResolverChain = {}
  local atMap = {}
  for _, tRepo in pairs(atRepositories) do
    -- Get the repository ID.
    local strID = tRepo.strID
    print(string.format('Creating driver for repository "%s".', strID))

    -- Does this ID already exist?
    if atMap[strID]~=nil then
      error(string.format('The ID "%s" is not unique!', strID))
    end

    -- Find the type.
    local tRepositoryDriverClass = self:get_driver_class_by_type(tRepo.strType)
    if tRepositoryDriverClass==nil then
      error(string.format('Could not find a repository driver for the type "%s".', tRepo.strType))
    end

    -- Create a driver instance.
    local tRepositoryDriver = tRepositoryDriverClass(strID)

    -- Setup the repository driver.
    tRepositoryDriver:configure(tRepo)

    -- Add the driver to the resolver chain.
    table.insert(atResolverChain, tRepositoryDriver)

    -- Create an ID -> repository mapping.
    atMap[strID] = tRepositoryDriver
  end

  -- Use the new resolver chain and the mapping.
  self.atResolverChain = atResolverChain
  self.atRepositoryByID = atMap
end



function ResolverChain:get_ga(strGroup, strArtifact)
  -- Combine the group and artifact.
  return string.format('%s/%s', strGroup, strArtifact)
end



function ResolverChain:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)
  -- Combine the group and artifact.
  local strGA = self:get_ga(strGroup, strArtifact)

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

  -- Does the source ID already exist?
  local fFound = false
  for _, strID in pairs(atV) do
    if strID==strSourceID then
      fFound = true
      break
    end
  end
  if fFound==false then
    -- Add the source ID.
    table.insert(atV, strSourceID)
  end
end



function ResolverChain:get_sources_by_gav(strGroup, strArtifact, tVersion)
  local atSources = nil

  -- Combine the group and artifact.
  local strGA = self:get_ga(strGroup, strArtifact)

  -- Is the GA already registered?
  local atGA = self.atGA_V[strGA]
  if atGA~=nil then
    -- Yes, now look for the version.
    local strVersion = tVersion:get()
    local atV = atGA[strVersion]
    if atV~=nil then
      atSources = atV
    end
  end

  return atSources
end



function ResolverChain:dump_ga_v_table()
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
      for _, strSrcID in pairs(atV) do
        print(string.format('        %s', strSrcID))
      end
    end
  end
  print ')'
end



function ResolverChain:get_available_versions(strGroup, strArtifact)
  local atDuplicateCheck = {}
  local atNewVersions = {}

  -- TODO: Check the GA->V table first.

  -- Loop over the repository list.
  for _, tRepository in pairs(self.atResolverChain) do
    -- Get the ID of the current repository.
    local strSourceID = tRepository:get_id()

    -- Get all available versions in this repository.
    local tResult, strError = tRepository:get_available_versions(strGroup, strArtifact)
    if tResult==nil then
      print(string.format('Error: failed to scan repository "%s": %s', strSourceID, strError))
    else
      -- Loop over all versions found in this repository.
      for _, tVersion in pairs(tResult) do
        -- Register the version in the GA->V table.
        self:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)

        -- Is this version unique?
        local strVersion = tVersion:get()
        if atDuplicateCheck[strVersion]==nil then
          atDuplicateCheck[strVersion] = true
          table.insert(atNewVersions, tVersion)
        end
      end
    end
  end

  return atNewVersions
end



function ResolverChain:get_configuration(strGroup, strArtifact, tVersion)
  local tResult = nil
  local strMessage = ''

  -- Check if the GA->V table has already the sources.
  local atGAVSources = self:get_sources_by_gav(strGroup, strArtifact, tVersion)
  if atGAVSources==nil then
    -- No GA->V entries present.
    error('Continue here')
--[[
Loop over all repositories in the chain and try to get the GAV.
Do not store this in the GA->V table as it would look like this is a complete dataset over all available versions.
]]--
  end

  -- Loop over the sources and try to get the configuration.
  for _, strSourceID in pairs(atGAVSources) do
    -- Get the repository with this ID.
    local tDriver = self:get_driver_by_id(strSourceID)
    if tDriver~=nil then
      tResult, strMessage = tDriver:get_configuration(strGroup, strArtifact, tVersion)
      if tResult==nil then
        print(string.format('Failed to get %s/%s/%s from repository %s: %s', strGroup, strArtifact, tVersion:get(), strSourceID, strMessage))
      else
        break
      end
    end
  end

  if tResult==nil then
    strMessage = 'No valid configuration found in all available repositories.'
  end

  return tResult, strMessage
end



function ResolverChain:get_artifact(strGroup, strArtifact, tVersion)
  local tResult = nil
  local strMessage = ''

  -- Check if the GA->V table has already the sources.
  local atGAVSources = self:get_sources_by_gav(strGroup, strArtifact, tVersion)
  if atGAVSources==nil then
    -- No GA->V entries present.
    error('Continue here')
--[[
Loop over all repositories in the chain and try to get the GAV.
Do not store this in the GA->V table as it would look like this is a complete dataset over all available versions.
]]--
  end

  -- Get the depack folder from the system configuration.
  local strDepackFolder = self.cSystemConfiguration.tConfiguration.depack

  -- Loop over the sources and try to get the configuration.
  for _, strSourceID in pairs(atGAVSources) do
    -- Get the repository with this ID.
    local tDriver = self:get_driver_by_id(strSourceID)
    if tDriver~=nil then
      tResult, strMessage = tDriver:get_artifact(strGroup, strArtifact, tVersion, strDepackFolder)
      if tResult~=nil then
        break
      end
    end
  end

  return tResult, strMessage
end



function ResolverChain:install_artifacts(atArtifacts)
  local tResult
  local strError

  for _,tGAV in pairs(atArtifacts) do
    local strGroup = tGAV.strGroup
    local strArtifact = tGAV.strArtifact
    local tVersion = tGAV.tVersion
    local strVersion = tGAV.tVersion:get()

    local strGAV = string.format('G:%s,A:%s,V:%s', strGroup, strArtifact, strVersion)
    print(string.format('Installing %s', strGAV))

    -- Copy the artifact to the local depack folder.
    tResult, strError = self:get_artifact(strGroup, strArtifact, tVersion)
    if tResult==nil then
      error(string.format('Failed to install %s: %s', strGAV, strError))
    else
      -- Create a unique temporary path for the artifact.
      local strGroupPath = self.pl.stringx.replace(strGroup, '.', self.pl.path.sep)
      local strDepackPath = self.pl.path.join(self.cSystemConfiguration.tConfiguration.depack, strGroupPath, strArtifact, strVersion)

      -- Does the depack path already exist?
      if self.pl.path.exists(strDepackPath)==strDepackPath then
        error(string.format('The unique depack path %s already exists.', strDepackPath))
      else
        tResult, strError = self.pl.dir.makepath(strDepackPath)
        if tResult~=true then
          tResult = nil
          strError = string.format('Failed to create the depack path for %s: %s', strGAV, strError)
        else
          print(strDepackPath)
        end
      end
    end
  end
end



return ResolverChain
