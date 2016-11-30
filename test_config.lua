-- This test checks the Configuration class.

-- Add the src folder to the search list.
package.path = package.path .. ";src/?.lua;src/?/init.lua;lualogging/?.lua;argparse/?.lua"

local argparse = require 'argparse'
local Logging = require 'logging'
local pl = require'pl.import_into'()


local atLogLevels = {
  debug = Logging.DEBUG,
  info = Logging.INFO,
  warn = Logging.WARN,
  error = Logging.ERROR,
  fatal = Logging.FATAL
}

local tParser = argparse('jonchki', 'A dependency manager for LUA packages.')
tParser:argument('input', 'Input file.')
  :target('strInputFile')
tParser:option('-v --verbose')
  :description(string.format('Set the verbosity level. Possible values are %s.', table.concat(pl.tablex.keys(atLogLevels), ', ')))
  :default('warn')
  :convert(atLogLevels)
  :target('tLogLevel')
tParser:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParser:option('-p --prjcfg')
  :description('Load the project configuration from FILE.')
  :default('jonchkicfg.xml')
  :target('strProjectConfigurationFile')
local tArgs = tParser:parse()


-----------------------------------------------------------------------------
--
-- Create a logger.
--

-- TODO: the logger type and level should depend on some command line options.
local cLogger = require 'logging.console'()
cLogger:setLevel(tArgs.tLogLevel)


-----------------------------------------------------------------------------
--
-- Read the system configuration.
--
local SystemConfiguration = require 'SystemConfiguration'
-- Create a configuration object.
local cSysCfg = SystemConfiguration(cLogger)
-- Read the settings from 'demo.cfg'.
local tResult = cSysCfg:parse_configuration(tArgs.strSystemConfigurationFile)
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
local tResult = cPrjCfg:parse_configuration(tArgs.strProjectConfigurationFile)
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
local tResult = cArtifactCfg:parse_configuration_file(tArgs.strInputFile)
if tResult~=true then
  cLogger:fatal('Failed to parse the artifact configuration!')
  os.exit(1)
end

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
  cLogger:fatal('Failed to resolve all dependencies.')
  os.exit(1)
else
  local atArtifacts = tResolver:get_all_dependencies()

  -- Download and depack all dependencies.
  local tResult = cResolverChain:retrieve_artifacts(atArtifacts)
  if tResult==nil then
    cLogger:fatal('Failed to retrieve all artifacts.')
    os.exit(1)
  else
    local Installer = require 'installer.installer'
    local cInstaller = Installer(cLogger, cSysCfg)
    local tResult = cInstaller:install_artifacts(atArtifacts)
    if tResult==nil then
      cLogger:fatal('Failed to install all artifacts.')
      os.exit(1)
    end
  end
end

cLogger:info('All OK!')
os.exit(0)
