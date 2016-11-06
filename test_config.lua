-- This test checks the Configuration class.

-- Add the src folder to the search list.
package.path = package.path .. ";src/?.lua;src/?/init.lua;lualogging/?.lua"


-----------------------------------------------------------------------------
--
-- Create a logger.
--

-- TODO: the logger type and level should depend on some command line options.
local Logging = require 'logging'
local cLogger = require 'logging.console'()
cLogger:setLevel(Logging.DEBUG)


-----------------------------------------------------------------------------
--
-- Read the system configuration.
--
local SystemConfiguration = require 'SystemConfiguration'
-- Create a configuration object.
local cSysCfg = SystemConfiguration(cLogger)
-- Read the settings from 'demo.cfg'.
local tResult = cSysCfg:parse_configuration('demo.cfg')
if tResult==nil then
  cLogger:fatal('Failed to parse the system configuration!')
  os.exit(1)
end
-- Check if all paths exist. Try to create them. Clean the depack and the install folders.
local tResult = cSysCfg:initialize_paths()
if tResult==nil then
  cLogger:fatal('Failed to initialize the paths!')
  os.exit(1)
end


-----------------------------------------------------------------------------
--
-- Read the project configuration.
--
local ProjectConfiguration = require 'ProjectConfiguration'
local cPrjCfg = ProjectConfiguration(cLogger)
local tResult = cPrjCfg:parse_configuration('jonchkicfg.xml')
if tResult==nil then
  cLogger:fatal('Failed to parse the project configuration!')
  os.exit(1)
end


-----------------------------------------------------------------------------
--
-- Create the resolver chain.
--
local ResolverChain = require 'resolver.resolver_chain'
local cResolverChain = ResolverChain(cLogger, cSysCfg, 'default')
cResolverChain:set_repositories(cPrjCfg.atRepositories)


-----------------------------------------------------------------------------
--
-- Read the artifact configuration.
--
local ArtifactConfiguration = require 'ArtifactConfiguration'
local cArtifactCfg = ArtifactConfiguration(cLogger)
cArtifactCfg:parse_configuration_file('org.muhkuh.tools-flasher_cli.xml')

-----------------------------------------------------------------------------
--
-- Create the exact resolver.
--
local ResolverExact = require 'resolver.exact'
local tResolver = ResolverExact(cLogger, 'default-exact')

-- Resolve all dependencies.
tResolver:setResolverChain(cResolverChain)
local tStatus = tResolver:resolve(cArtifactCfg)
if tStatus~=true then
  cLogger:error('Failed to resolve all dependencies.')
else
  local atArtifacts = tResolver:get_all_dependencies()

  -- Download and depack all dependencies.
  local tResult = cResolverChain:retrieve_artifacts(atArtifacts)
  if tResult==nil then
    cLogger:error('Failed to retrieve all artifacts.')
  end

  local Installer = require 'installer.installer'
  local cInstaller = Installer(cLogger, cSysCfg)
  local tResult = cInstaller:install_artifacts(atArtifacts)
  if tResult==nil then
    cLogger:error('Failed to install all artifacts.')
  end
end
