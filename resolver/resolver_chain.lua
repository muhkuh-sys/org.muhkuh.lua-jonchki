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



function ResolverChain:set_repositories(atRepositories)
  -- Create all repository drivers.
  local atResolverChain = {}
  local atMap = {}
  for _, tRepo in pairs(atRepositories) do
    -- Get the repository ID.
    local strID = tRepo.strID
    print(string.format('Creating driver for repository "%s".', strID))
  
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



function ResolverChain:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)
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


return ResolverChain
