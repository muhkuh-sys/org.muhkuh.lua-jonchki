-- This is the jonchki core file.
-- The core provides the main function blocks which are called according to
-- the selected commands.
-- @author cthelen@hilscher.com
-- @copyright 2018 Hilscher Gesellschaft für Systemautomation mbH

-- Create the core class.
local class = require 'pl.class'
local Core = class()

function Core:_init(cLog, cReport, strJonchkiPath)
  -- The "penlight" module is always useful.
  self.pl = require'pl.import_into'()

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.Cache = require 'cache.cache'
  self.Installer = require 'installer.installer'
  self.Platform = require 'platform.platform'
  self.ProjectConfiguration = require 'ProjectConfiguration'
  self.Resolver = require 'resolver.resolver'
  self.ResolverChain = require 'resolver.resolver_chain'
  self.SystemConfiguration = require 'SystemConfiguration'

  -- Store the logger.
  self.cLog = cLog

  -- Create a new logger object for this module.
  local tLogWriter = require 'log.writer.prefix'.new('[Core] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  -- Store the report.
  self.cReport = cReport

  -- Store the jonchki path.
  self.strJonchkiPath = strJonchkiPath

  -- No system configuration yet.
  self.cSysCfg = nil

  -- No platform yet.
  self.cPlatform = nil

  -- No project configuration yet.
  self.cPrjCfg = nil

  -- No cache yet.
  self.cCache = nil

  -- No resolver chain yet.
  self.cResolverChain = nil

  -- No root artifact yet.
  self.cRootArtifactCfg = nil

  -- No resolver yet.
  self.cResolver = nil

  -- No installer yet.
  self.cInstaller = nil
end


-----------------------------------------------------------------------------
--
-- Read the system configuration.
--
function Core:read_system_configuration(strSystemConfigurationFile, fInstallBuildDependencies)
  -- Create a configuration object.
  local cSysCfg = self.SystemConfiguration(self.cLog, self.strJonchkiPath, fInstallBuildDependencies)
  -- Read the settings from the system configuration file.
  local tResult = cSysCfg:parse_configuration(strSystemConfigurationFile)
  if tResult==nil then
    self.tLog.fatal('Failed to parse the system configuration!')
  else
    -- Check if all paths exist. Try to create them. Clean the depack and the install folders.
    tResult = cSysCfg:initialize_paths()
    if tResult==nil then
      self.tLog.fatal('Failed to initialize the paths!')
    else
      -- Use the new system configuration for the core.
      self.cSysCfg = cSysCfg

      -- Write the report to the working folder.
      self.cReport:setFileName(self.pl.path.join(cSysCfg.tConfiguration.work, 'jonchkireport.xml'))
    end
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Get the platform ID.
--
function Core:get_platform_id(strCpuArchitecture, strDistributionId, strDistributionVersion)
  -- Be pessimistic.
  local tResult = nil

  local cPlatform = self.Platform(self.cLog, self.cReport)

  -- Detect the host platform.
  cPlatform:detect()
  self.tLog.info('Detected platform: %s', tostring(cPlatform))

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
    self.tLog.fatal('The platform information is not valid!')
  else
      -- Use the platform configuration for the core.
      self.cPlatform = cPlatform
      tResult = true
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Read the project configuration.
--
function Core:read_project_configuration(strProjectConfigurationFile)
  local cPrjCfg = self.ProjectConfiguration(self.cLog, self.cReport)
  local tResult = cPrjCfg:parse_configuration(strProjectConfigurationFile)
  if tResult==nil then
    self.tLog.fatal('Failed to parse the project configuration!')
  else
    -- Use the project configuration for the core.
    self.cPrjCfg = cPrjCfg
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Create the cache.
--
function Core:create_cache()
  -- Set the cache ID to "main".
  local strCacheID = 'main'
  local cCache = self.Cache(self.cLog, self.cPlatform, strCacheID)
  local tResult = cCache:configure(self.cSysCfg.tConfiguration.cache, self.cSysCfg.tConfiguration.cache_max_size)
  if tResult~=true then
    self.tLog.fatal('Failed to open the cache!')
  else
    self.cCache = cCache
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Create the resolver chain.
--
function Core:create_resolver_chain()
  local strResolverChainID = 'default'
  local cResolverChain = self.ResolverChain(self.cLog, self.cPlatform, self.cSysCfg, strResolverChainID)
  if self.cCache~=nil then
    cResolverChain:set_cache(self.cCache)
  end
  cResolverChain:set_repositories(self.cPrjCfg.atRepositories)

  self.cResolverChain = cResolverChain
end


-----------------------------------------------------------------------------
--
-- Read the artifact configuration.
--
function Core:read_artifact_configuration(strArtifactConfigurationFile)
  local cArtifactCfg = self.ArtifactConfiguration(self.cLog)
  local tResult = cArtifactCfg:parse_configuration_file(strArtifactConfigurationFile)
  if tResult~=true then
    self.tLog.fatal('Failed to parse the artifact configuration!')
  else
    -- Use the artifact configration as the core's root artifact.
    self.cRootArtifactCfg = cArtifactCfg
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Create the resolver.
--
function Core:create_resolver(fInstallBuildDependencies)
  local strResolverID = 'default'
  local cResolver = self.Resolver(self.cLog, self.cReport, strResolverID, fInstallBuildDependencies)
  -- Create all policy lists.
  local tResult = cResolver:load_policies(self.cPrjCfg)
  if tResult~=true then
    self.tLog.fatal('Failed to create all policy lists.')
  else
    -- Use the resolver for the core.
    self.cResolver = cResolver
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Resolve the root artifact and all dependencies.
--
function Core:resolve_root_and_dependencies(strGroup, strModule, strArtifact, strConstraint)
  local tResult = nil

  self.cResolver:setResolverChain(self.cResolverChain)
  local tStatus = self.cResolver:resolve_root_and_dependencies(strGroup, strModule, strArtifact, strConstraint)
  if tStatus~=true then
    self.tLog.fatal('Failed to resolve the root artifact and all dependencies.')
  else
    -- Set the root artifact configuration.
    self.cRootArtifactCfg = self.cResolver:resolvetab_get_artifact_configuration()

    tResult = true
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Resolve all dependencies.
--
function Core:resolve_all_dependencies()
  local tResult = nil

  self.cResolver:setResolverChain(self.cResolverChain)
  local tStatus = self.cResolver:resolve(self.cRootArtifactCfg)
  if tStatus~=true then
    self.tLog.fatal('Failed to resolve all dependencies.')
  else
    tResult = true
  end

  return tResult
end


-----------------------------------------------------------------------------
--
-- Download and install all artifacts.
--
function Core:download_and_install_all_artifacts(fInstallBuildDependencies, fSkipRootArtifact, strFinalizerScript, strDependencyLogFile)
  local tDependencyLog = require 'DependencyLog'(self.cLog)
  local atArtifacts, atIdTab = self.cResolver:get_all_dependencies(fSkipRootArtifact, tDependencyLog)
  tDependencyLog:writeToFile(strDependencyLogFile)

  local tResult = self.cResolverChain:retrieve_artifacts(atArtifacts)
  if tResult==nil then
    self.tLog.fatal('Failed to retrieve all artifacts.')
  else
    -- Now each atrifact has a source repository set. This was the last missing piece of information.
    self.cResolver:write_artifact_tree_to_report(atIdTab)

    local cInstaller = self.Installer(self.cLog, self.cReport, self.cSysCfg, self.cRootArtifactCfg)
    tResult = cInstaller:install_artifacts(atArtifacts, self.cPlatform, fInstallBuildDependencies)
    if tResult==nil then
      self.tLog.fatal('Failed to install all artifacts.')
    else
      -- Use the installer for the core.
      self.cInstaller = cInstaller

      -- Show some statistics.
      self.cResolverChain:show_statistics(self.cReport)

      -- Write the report.
      self.cReport:write()

      -- Run the finalizer script.
      tResult = self.cInstaller:run_finalizer(strFinalizerScript)
      if tResult==nil then
        self.tLog.fatal('Failed to run the finalizer script "%s".', strFinalizerScript)
      else
        tResult = true
      end
    end
  end

  return tResult
end


return Core
