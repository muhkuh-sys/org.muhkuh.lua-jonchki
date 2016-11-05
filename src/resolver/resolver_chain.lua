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
  self.atGMA_V = {}

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



function ResolverChain:get_gma(strGroup, strModule, strArtifact)
  -- Combine the group, module and artifact.
  return string.format('%s/%s/%s', strGroup, strModule, strArtifact)
end



function ResolverChain:add_to_ga_v(strGroup, strModule, strArtifact, tVersion, strSourceID)
  -- Combine the group, module and artifact.
  local strGMA = self:get_gma(strGroup, strModule, strArtifact)

  -- Is the GMA already registered?
  local atGMA = self.atGMA_V[strGMA]
  if atGMA==nil then
    -- No, register GMA now.
    atGMA = {}
    self.atGMA_V[strGMA] = atGMA
  end

  -- Is the version already registered?
  local strVersion = tVersion:get()
  local atV = atGMA[strVersion]
  if atV==nil then
    -- No, register the version now.
    atV = {}
    atGMA[strVersion] = atV
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



function ResolverChain:get_sources_by_gmav(strGroup, strModule, strArtifact, tVersion)
  local atSources = nil

  -- Combine the group, module and artifact.
  local strGMA = self:get_gma(strGroup, strModule, strArtifact)

  -- Is the GA already registered?
  local atGMA = self.atGMA_V[strGMA]
  if atGMA~=nil then
    -- Yes, now look for the version.
    local strVersion = tVersion:get()
    local atV = atGMA[strVersion]
    if atV~=nil then
      atSources = atV
    end
  end

  return atSources
end



function ResolverChain:dump_ga_v_table()
  print 'GMA_V('

  -- Loop over all GA pairs.
  for strGMA, atGMA in pairs(self.atGMA_V) do
    -- Split the GA pair by the separating slash ('/').
    local aTmp = self.pl.stringx.split(strGMA, '/')
    local strGroup = aTmp[1]
    local strModule = aTmp[2]
    local strArtifact = aTmp[3]
    print(string.format('  G=%s, M=%s, A=%s', strGroup, strModule, strArtifact))

    -- Loop over all versions.
    for tVersion, atV in pairs(atGMA) do
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



function ResolverChain:get_available_versions(strGroup, strModule, strArtifact)
  local atDuplicateCheck = {}
  local atNewVersions = {}

  -- TODO: Check the GA->V table first.

  -- Loop over the repository list.
  for _, tRepository in pairs(self.atResolverChain) do
    -- Get the ID of the current repository.
    local strSourceID = tRepository:get_id()

    -- Get all available versions in this repository.
    local tResult, strError = tRepository:get_available_versions(strGroup, strModule, strArtifact)
    if tResult==nil then
      print(string.format('Error: failed to scan repository "%s": %s', strSourceID, strError))
    else
      -- Loop over all versions found in this repository.
      for _, tVersion in pairs(tResult) do
        -- Register the version in the GA->V table.
        self:add_to_ga_v(strGroup, strModule, strArtifact, tVersion, strSourceID)

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



function ResolverChain:get_configuration(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local strMessage = ''

  -- Check if the GA->V table has already the sources.
  local atGMAVSources = self:get_sources_by_gmav(strGroup, strModule, strArtifact, tVersion)
  if atGMAVSources==nil then
    -- No GMA->V entries present.
    error('Continue here')
--[[
Loop over all repositories in the chain and try to get the GAV.
Do not store this in the GMA->V table as it would look like this is a complete dataset over all available versions.
]]--
  end

  -- Loop over the sources and try to get the configuration.
  for _, strSourceID in pairs(atGMAVSources) do
    -- Get the repository with this ID.
    local tDriver = self:get_driver_by_id(strSourceID)
    if tDriver~=nil then
      tResult, strMessage = tDriver:get_configuration(strGroup, strModule, strArtifact, tVersion)
      if tResult==nil then
        print(string.format('Failed to get %s/%s/%s/%s from repository %s: %s', strGroup, strModule, strArtifact, tVersion:get(), strSourceID, strMessage))
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



function ResolverChain:get_artifact(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local strMessage = ''

  -- Check if the GMA->V table has already the sources.
  local atGMAVSources = self:get_sources_by_gmav(strGroup, strModule, strArtifact, tVersion)
  if atGMAVSources==nil then
    -- No GMA->V entries present.
    error('Continue here')
--[[
Loop over all repositories in the chain and try to get the GMAV.
Do not store this in the GMA->V table as it would look like this is a complete dataset over all available versions.
]]--
  end

  -- Get the depack folder from the system configuration.
  local strDepackFolder = self.cSystemConfiguration.tConfiguration.depack

  -- Loop over the sources and try to get the configuration.
  for _, strSourceID in pairs(atGMAVSources) do
    -- Get the repository with this ID.
    local tDriver = self:get_driver_by_id(strSourceID)
    if tDriver~=nil then
      tResult, strMessage = tDriver:get_artifact(strGroup, strModule, strArtifact, tVersion, strDepackFolder)
      if tResult~=nil then
        break
      end
    end
  end

  return tResult, strMessage
end



function ResolverChain:retrieve_artifacts(atArtifacts)
  local tResult = true
  local strError = ''

  for _,tGMAV in pairs(atArtifacts) do
    local strGroup = tGMAV.strGroup
    local strModule = tGMAV.strModule
    local strArtifact = tGMAV.strArtifact
    local tVersion = tGMAV.tVersion
    local strVersion = tGMAV.tVersion:get()

    local strGMAV = string.format('%s-%s-%s-%s', strGroup, strModule, strArtifact, strVersion)
    print(string.format('Retrieving %s', strGMAV))

    -- Copy the artifact to the local depack folder.
    tResult, strError = self:get_artifact(strGroup, strModule, strArtifact, tVersion)
    if tResult==nil then
      strError = string.format('Failed to install %s: %s', strGMAV, strError)
      break
    else
      local strArtifactPath = tResult

      -- Add the artifact path to the attributes.
      tGMAV.strArtifactPath = strArtifactPath
    end
  end

  return tResult, strError
end


return ResolverChain
