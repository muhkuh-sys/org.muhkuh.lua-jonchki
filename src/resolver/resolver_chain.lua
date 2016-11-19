--- The resolver chain class.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2016 Christoph Thelen

-- Create the configuration class.
local class = require 'pl.class'
local ResolverChain = class()



--- Initialize a new instance of the resolver chain.
-- @param strID The ID identifies the resolver.
function ResolverChain:_init(cLogger, cSystemConfiguration, strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- The system configuration.
  self.cSystemConfiguration = cSystemConfiguration

  -- Get the logger object from the system configuration.
  self.tLogger = cLogger

  -- Create a new chain.
  self.atResolverChain = {}
  -- Mapping from the repository ID to the member of the resolver chain.
  self.atRepositoryByID = {}

  -- Create a new GA->V table.
  self.atGMA_V = {}

  -- Get all available repository drivers.
  local atRepositoryDriverClasses = {}
  table.insert(atRepositoryDriverClasses, require 'repository_driver.filesystem')
  table.insert(atRepositoryDriverClasses, require 'repository_driver.url')
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



function ResolverChain:set_repositories(atRepositories)
  local tResult = true

  -- Create all repository drivers.
  local atResolverChain = {}
  local atMap = {}
  for _, tRepo in pairs(atRepositories) do
    -- Get the repository ID.
    local strID = tRepo.strID
    -- Get the repository type.
    local strType = tRepo.strType
    self.tLogger:info('Creating driver for repository "%s" with type "%s".', strID, strType)

    -- Does this ID already exist?
    if atMap[strID]~=nil then
      tResult = nil
      self.tLogger:fatal('The ID "%s" is not unique!', strID)
      break
    else
      -- Find the type.
      local tRepositoryDriverClass = self:get_driver_class_by_type(strType)
      if tRepositoryDriverClass==nil then
        tResult = nil
        self.tLogger:fatal('Could not find a repository driver for the type "%s".', tRepo.strType)
        break
      end
  
      -- Create a driver instance.
      local tRepositoryDriver = tRepositoryDriverClass(self.tLogger, strID)
  
      -- Setup the repository driver.
      tResult = tRepositoryDriver:configure(tRepo)
      if tResult~=true then
        tResult = nil
        self.tLogger:fatal('Failed to setup repository driver "%s".', strID)
        break
      end
  
      -- Add the driver to the resolver chain.
      table.insert(atResolverChain, tRepositoryDriver)
  
      -- Create an ID -> repository mapping.
      atMap[strID] = tRepositoryDriver
    end
  end

  if tResult==true then
    -- Use the new resolver chain and the mapping.
    self.atResolverChain = atResolverChain
    self.atRepositoryByID = atMap
  end

  return tResult
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
    local tResult = tRepository:get_available_versions(strGroup, strModule, strArtifact)
    if tResult==nil then
      self.tLogger:warn('Error: failed to scan repository "%s".', strSourceID)
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

  local strGMAV = string.format('G:%s M=%s A=%s V=%s', strGroup, strModule, strArtifact, tVersion:get())

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
      tResult = tDriver:get_configuration(strGroup, strModule, strArtifact, tVersion)
      if tResult==nil then
        self.tLogger:warn('Failed to get %s from repository %s.', strGMAV, strSourceID)
      else
        break
      end
    end
  end

  if tResult==nil then
    self.tLogger:info('No valid configuration found for %s in all available repositories.', strGMAV)
  end

  return tResult
end



function ResolverChain:get_artifact(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil

  local strGMAV = string.format('G:%s M=%s A=%s V=%s', strGroup, strModule, strArtifact, tVersion:get())

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
    if tDriver==nil then
      self.tLogger:warn('No driver found with the ID "%s".', strSourceID)
    else
      tResult = tDriver:get_artifact(strGroup, strModule, strArtifact, tVersion, strDepackFolder)
      if tResult==nil then
        self.tLogger:info('Artifact %s not found in repository "%s".', strGMAV, strSourceID)
      else
        self.tLogger:info('Artifact %s found in repository "%s".', strGMAV, strSourceID)
        break
      end
    end
  end

  if tResult==nil then
    self.tLogger:warn('Artifact %s not found in all available repositories.', strGMAV)
  end

  return tResult
end



function ResolverChain:retrieve_artifacts(atArtifacts)
  local tResult = true

  for _,tGMAV in pairs(atArtifacts) do
    local strGroup = tGMAV.strGroup
    local strModule = tGMAV.strModule
    local strArtifact = tGMAV.strArtifact
    local tVersion = tGMAV.tVersion
    local strVersion = tGMAV.tVersion:get()

    local strGMAV = string.format('%s-%s-%s-%s', strGroup, strModule, strArtifact, strVersion)
    self.tLogger:info('Retrieving %s', strGMAV)

    -- Copy the artifact to the local depack folder.
    tResult = self:get_artifact(strGroup, strModule, strArtifact, tVersion)
    if tResult==nil then
      self.tLogger:error(string.format('Failed to retrieve %s.', strGMAV))
      break
    else
      local strArtifactPath = tResult

      -- Add the artifact path to the attributes.
      tGMAV.strArtifactPath = strArtifactPath
    end
  end

  return tResult
end


return ResolverChain
