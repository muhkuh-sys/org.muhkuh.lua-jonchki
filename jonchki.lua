------------------------------------------------------------------------------
--
-- Add some subfolders to the search list.
--
local strScriptPath = debug.getinfo(1, "S").source:sub(2)
strScriptPath = string.gsub(strScriptPath, '\\', '/')
local iLastSlash = nil
for iCnt = string.len(strScriptPath), 1, -1 do
  if string.sub(strScriptPath, iCnt, iCnt)=='/' then
    iLastSlash = iCnt
    break
  end
end
if iLastSlash~=nil then
  strScriptPath = string.sub(strScriptPath, 1, iLastSlash)
end
package.path = package.path .. ';' .. strScriptPath .. '/src/?.lua;' .. strScriptPath .. '/src/?/init.lua;' .. strScriptPath .. '/lualogging/?.lua;' .. strScriptPath .. '/argparse/?.lua;' .. strScriptPath .. '/penlight/?.lua'


------------------------------------------------------------------------------

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
tParser:flag('-b --build-dependencies')
  :description('Install the build dependencies.')
  :default(false)
  :target('fInstallBuildDependencies')
tParser:option('-f --finalizer')
  :description('Run the installer script SCRIPT as a finalizer.')
  :argname('<SCRIPT>')
  :default(nil)
  :target('strFinalizerScript')
tParser:option('-p --prjcfg')
  :description('Load the project configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkicfg.xml')
  :target('strProjectConfigurationFile')
tParser:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParser:option('--cpu-architecture')
  :description('Set the CPU architecture for the installation to ARCH. The default is to autodetect it.')
  :argname('<ARCH>')
  :default(nil)
  :target('strCpuArchitecture')
tParser:option('--distribution-id')
  :description('Set the distribution id for the installation to ID. The default is to autodetect it.')
  :argname('<ID>')
  :default(nil)
  :target('strDistributionId')
tParser:option('--distribution-version')
  :description('Set the distribution version for the installation to VERSION. The default is to autodetect it.')
  :argname('<VERSION>')
  :default(nil)
  :target('strDistributionVersion')
tParser:option('-v --verbose')
  :description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(pl.tablex.keys(atLogLevels), ', ')))
  :argname('<LEVEL>')
  :default('warn')
  :convert(atLogLevels)
  :target('tLogLevel')
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
-- Create a report.
--
local Report = require 'Report'
local cReport = Report()


-----------------------------------------------------------------------------
--
-- Get the target ID.
--
local strCpuArchitecture = tArgs.strCpuArchitecture
local strDistributionId = tArgs.strDistributionId
local strDistributionVersion = tArgs.strDistributionVersion
local Platform = require 'platform.platform'
local cPlatform = Platform(cLogger, cReport)

-- Detect the host platform.
cPlatform:detect()
cLogger:info('Detected platform: %s', tostring(cPlatform))

-- Override the initial values (empty or from the detection)
if strCpuArchitecture~=nil then
  cPlatform:override_cpu_architecture(strCpuArchitecture)
end
if strDistributionId~=nil then
  cPlatform:override_distribution_id(strDistributionId)
end
if strDistributionVersion~=nil then
  cPlatform:override_distribution_version(strDistributionVersion)
end

local fPlatformInfoIsValid = cPlatform:is_valid()
if fPlatformInfoIsValid~=true then
  -- The platform information is not valid.
  cLogger:fatal('The platform information is not valid!')
  cReport:write()
  os.exit(1)
end


-----------------------------------------------------------------------------
--
-- Read the system configuration.
--
local SystemConfiguration = require 'SystemConfiguration'
-- Create a configuration object.
local cSysCfg = SystemConfiguration(cLogger, cReport, tArgs.fInstallBuildDependencies)
-- Read the settings from 'demo.cfg'.
local tResult = cSysCfg:parse_configuration(tArgs.strSystemConfigurationFile)
if tResult==nil then
  cLogger:fatal('Failed to parse the system configuration!')
  cReport:write()
  os.exit(1)
end
-- Check if all paths exist. Try to create them. Clean the depack and the install folders.
local tResult = cSysCfg:initialize_paths()
if tResult==nil then
  cLogger:fatal('Failed to initialize the paths!')
  cReport:write()
  os.exit(1)
end


-----------------------------------------------------------------------------
--
-- Read the project configuration.
--
local ProjectConfiguration = require 'ProjectConfiguration'
local cPrjCfg = ProjectConfiguration(cLogger, cReport)
local tResult = cPrjCfg:parse_configuration(tArgs.strProjectConfigurationFile)
if tResult==nil then
  cLogger:fatal('Failed to parse the project configuration!')
  cReport:write()
  os.exit(1)
end


-----------------------------------------------------------------------------
--
-- Create the cache.
-- Set the cache ID to "main".
--
local Cache = require 'cache.cache'
local cCache = Cache(cLogger, 'main')
tResult = cCache:configure(cSysCfg.tConfiguration.cache)
if tResult==nil then
  cLogger:fatal('Failed to open the cache!')
  cReport:write()
  os.exit(1)
end


-----------------------------------------------------------------------------
--
-- Create the resolver chain.
--
local ResolverChain = require 'resolver.resolver_chain'
local cResolverChain = ResolverChain(cLogger, cSysCfg, 'default')
cResolverChain:set_cache(cCache)
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
  cReport:write()
  os.exit(1)
end

-----------------------------------------------------------------------------
--
-- Create the resolver.
--
local Resolver = require 'resolver.resolver'
local tResolver = Resolver(cLogger, 'default', tArgs.fInstallBuildDependencies)
-- Create all policy lists.
local tResult = tResolver:load_policies(cPrjCfg)
if tResult~=true then
  cLogger:fatal('Failed to create all policy lists.')
  cReport:write()
  os.exit(1)
else
  -- Resolve all dependencies.
  tResolver:setResolverChain(cResolverChain)
  local tStatus = tResolver:resolve(cArtifactCfg)
  if tStatus~=true then
    cLogger:fatal('Failed to resolve all dependencies.')
    cReport:write()
    os.exit(1)
  else
    local atArtifacts = tResolver:get_all_dependencies()
  
    -- Download and depack all dependencies.
    local tResult = cResolverChain:retrieve_artifacts(atArtifacts)
    if tResult==nil then
      cLogger:fatal('Failed to retrieve all artifacts.')
      cReport:write()
      os.exit(1)
    else
      local Installer = require 'installer.installer'
      local cInstaller = Installer(cLogger, cSysCfg)
      local tResult = cInstaller:install_artifacts(atArtifacts, cPlatform, tArgs.fInstallBuildDependencies, tArgs.strFinalizerScript)
      if tResult==nil then
        cLogger:fatal('Failed to install all artifacts.')
        cReport:write()
        os.exit(1)
      end
    end
  end
end

cLogger:info('All OK!')
cReport:write()
os.exit(0)
