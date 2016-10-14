-- This test checks the Configuration class.


-- Create a configuration object and read the settings from 'demo.cfg'.
local SystemConfiguration = require 'SystemConfiguration'
local cSysCfg = SystemConfiguration()
cSysCfg:parse_configuration('demo.cfg')
print(cSysCfg)

-- Read the project configuration.
local ProjectConfiguration = require 'ProjectConfiguration'
local cPrjCfg = ProjectConfiguration()
cPrjCfg:parse_configuration('jonchkicfg.xml')
print(cPrjCfg)

-- Get all available repository drivers.
local atRepositoryDrivers = {}
table.insert(atRepositoryDrivers, require 'repository_driver.filesystem')

-- Create all repository drivers.
local atRepositoryList = {}
for uiCnt, tRepo in pairs(cPrjCfg.atRepositories) do
  print(string.format('Creating driver for repository "%s".', tRepo.strID))
  
  -- Find the type.
  local tRepositoryDriverClass = nil
  local strType = tRepo.strType
  for uiCnt2, tDriver in pairs(atRepositoryDrivers) do
    if tDriver.matches_type(strType)==true then
      tRepositoryDriverClass = tDriver
      break
    end
  end
  if tRepositoryDriverClass==nil then
    error(string.format('Could not find a repository driver for the type "%s".', strType))
  end
  
  -- Create a driver instance.
  local tRepositoryDriver = tRepositoryDriverClass(tRepo.strID)

  -- Setup the repository driver.
  tRepositoryDriver:configure(tRepo)
  
  -- Add the driver to the resolver chain.
  table.insert(atRepositoryList, tRepositoryDriver)
end

-- Read the artifact configuration.
local ArtifactConfiguration = require 'ArtifactConfiguration'
local cArtifactCfg = ArtifactConfiguration()
cArtifactCfg:parse_configuration('org.muhkuh.tools-flasher_cli.xml')
print(cArtifactCfg)

-- Create the exact resolver.
local ResolverExact = require 'resolver.exact'
local tResolver = ResolverExact('default-exact')
print(tResolver)

-- Resolve all dependencies.
tResolver:setRepositories(atRepositoryList)
tResolver:resolve(cArtifactCfg)

--[[
  local tArtifact = {
    ['strGroup'] = 'org.muhkuh.tools',
    ['strArtifact'] = 'flasher',
    ['version'] = '1.3.0'
  }
  a,b = tRepositoryDriver:get_available_versions(tArtifact)
  if a==nil then
    error(b)
  else
    print('Found versions:')
    for _,tVersion in pairs(a) do
      print(tVersion)
    end
  end
]]--

