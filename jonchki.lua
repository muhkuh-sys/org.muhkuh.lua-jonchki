local function command_install(cCore, tArgs)
  -- Read the system configuration.
  local tResult = cCore:read_system_configuration(tArgs.strSystemConfigurationFile, tArgs.fInstallBuildDependencies)
  if tResult~=nil then

    -- Get the platform ID.
    tResult = cCore:get_platform_id(tArgs.strCpuArchitecture, tArgs.strDistributionId, tArgs.strDistributionVersion)
    if tResult~=nil then

      -- Read the project configuration.
      tResult = cCore:read_project_configuration(tArgs.strProjectConfigurationFile)
      if tResult~=nil then

        -- Create the cache.
        if tArgs.fNoCache==true then
          cLogger:info('Do not use a cache as requested.')
          tResult = true
        else
          tResult = cCore:create_cache()
        end
        if tResult==true then

          -- Create the resolver chain.
          cCore:create_resolver_chain()

          -- Read the artifact configuration.
          tResult = cCore:read_artifact_configuration(tArgs.strInputFile)
          if tResult==true then

            -- Create the resolver.
            tResult = cCore:create_resolver(tArgs.fInstallBuildDependencies)
            if tResult==true then

              -- Resolve all dependencies.
              tResult = cCore:resolve_all_dependencies()
              if tResult==true then

                -- Download and install all artifacts.
                tResult = cCore:download_and_install_all_artifacts(tArgs.fInstallBuildDependencies, not tArgs.fSkipRootArtifact, tArgs.strFinalizerScript)
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



------------------------------------------------------------------------------
--
-- Add some subfolders to the search list.
--
local strJonchkiPath = debug.getinfo(1, "S").source:sub(2)
strJonchkiPath = string.gsub(strJonchkiPath, '\\', '/')
local iLastSlash = nil
for iCnt = string.len(strJonchkiPath), 1, -1 do
  if string.sub(strJonchkiPath, iCnt, iCnt)=='/' then
    iLastSlash = iCnt
    break
  end
end
if iLastSlash==nil then
  strJonchkiPath = '.'
else
  strJonchkiPath = string.sub(strJonchkiPath, 1, iLastSlash - 1)
end
package.path = package.path .. ';' .. strJonchkiPath .. '/lua/?.lua;' .. strJonchkiPath .. '/lua/?/init.lua'
package.cpath = package.cpath .. ';' .. strJonchkiPath .. '/lua_plugins/?.so;' .. strJonchkiPath .. '/lua_plugins/?.dll'


------------------------------------------------------------------------------

local argparse = require 'argparse'
local Logging = require 'logging'
local pl = require'pl.import_into'()


-- Try to read the package file.
local strPackageInfoFile = pl.path.join(strJonchkiPath, '.jonchki', 'package.txt')
local strPackageInfo, strError = pl.utils.readfile(strPackageInfoFile, false)
-- Default to version "unknown".
local strJonchkiVersion = 'unknown'
local strJonchkiVcsVersion = 'unknown'
if strPackageInfo~=nil then
  strJonchkiVersion = string.match(strPackageInfo, 'PACKAGE_VERSION=([0-9.]+)')
  strJonchkiVcsVersion = string.match(strPackageInfo, 'PACKAGE_VCS_ID=([a-zA-Z0-9+]+)')
end


local atLogLevels = {
  debug = Logging.DEBUG,
  info = Logging.INFO,
  warn = Logging.WARN,
  error = Logging.ERROR,
  fatal = Logging.FATAL
}

local tParser = argparse('jonchki', 'A dependency manager for LUA packages.')
  :command_target("strSubcommand")

-- "--version" is special. It behaves like a command and is processed immediately during parsing.
tParser:flag('--version')
  :description('Show the version and exit.')
  :action(function()
    print(string.format('jonchki V%s %s', strJonchkiVersion, strJonchkiVcsVersion))
    os.exit(0)
  end)

-- Add the "install" command and all its options.
local tParserCommandInstall = tParser:command('install i', 'Install an artifact and all dependencies.')
  :target('fCommandInstallSelected')
tParserCommandInstall:argument('input', 'Input file.')
  :target('strInputFile')
tParserCommandInstall:flag('-b --build-dependencies')
  :description('Install the build dependencies.')
  :default(false)
  :target('fInstallBuildDependencies')
tParserCommandInstall:flag('-r --skip-root-artifact')
  :description('Do not install the root artifact but only its dependencies.')
  :default(false)
  :target('fSkipRootArtifact')
tParserCommandInstall:option('-f --finalizer')
  :description('Run the installer script SCRIPT as a finalizer.')
  :argname('<SCRIPT>')
  :default(nil)
  :target('strFinalizerScript')
tParserCommandInstall:flag('-n --no-cache')
  :description('Do not use a cache, even if repositories are marked as cacheable.')
  :default(false)
  :target('fNoCache')
tParserCommandInstall:option('-p --prjcfg')
  :description('Load the project configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkicfg.xml')
  :target('strProjectConfigurationFile')
tParserCommandInstall:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandInstall:option('--cpu-architecture')
  :description('Set the CPU architecture for the installation to ARCH. The default is to autodetect it.')
  :argname('<ARCH>')
  :default(nil)
  :target('strCpuArchitecture')
tParserCommandInstall:option('--distribution-id')
  :description('Set the distribution id for the installation to ID. The default is to autodetect it.')
  :argname('<ID>')
  :default(nil)
  :target('strDistributionId')
tParserCommandInstall:mutex(
  tParserCommandInstall:option('--distribution-version')
    :description('Set the distribution version for the installation to VERSION. The default is to autodetect it.')
    :argname('<VERSION>')
    :default(nil)
    :target('strDistributionVersion'),
  tParserCommandInstall:flag('--empty-distribution-version')
    :description('Set the distribution version for the installation to the empty string. The default is to autodetect it.')
    :target('fEmptyDistributionVersion')
)
tParserCommandInstall:option('-v --verbose')
  :description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(pl.tablex.keys(atLogLevels), ', ')))
  :argname('<LEVEL>')
  :default('warn')
  :convert(atLogLevels)
  :target('tLogLevel')

-- Add the "cache" command and all its options.
local tParserCommandCache = tParser:command('cache c', 'Examine and modify the cache.')
  :target('fCommandCacheSelected')
  :command_target("strCacheSubcommand")
local tParserCommandCacheCheck = tParserCommandCache:command('check', 'Check the complete cache for invalid entries, missing or stray files and total size.')
  :target('fCommandCacheCheckSelected')
tParserCommandCacheCheck:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandCacheCheck:option('-v --verbose')
  :description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(pl.tablex.keys(atLogLevels), ', ')))
  :argname('<LEVEL>')
  :default('warn')
  :convert(atLogLevels)
  :target('tLogLevel')
local tParserCommandCacheClear = tParserCommandCache:command('clear', 'Remove all entries from the cache.')
  :target('fCommandCacheClearSelected')
tParserCommandCacheClear:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandCacheClear:option('-v --verbose')
  :description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(pl.tablex.keys(atLogLevels), ', ')))
  :argname('<LEVEL>')
  :default('warn')
  :convert(atLogLevels)
  :target('tLogLevel')
local tParserCommandCacheShow = tParserCommandCache:command('show', 'Show all contents of the cache.')
  :target('fCommandCacheShowSelected')
tParserCommandCacheShow:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandCacheShow:option('-v --verbose')
  :description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(pl.tablex.keys(atLogLevels), ', ')))
  :argname('<LEVEL>')
  :default('warn')
  :convert(atLogLevels)
  :target('tLogLevel')

local tArgs = tParser:parse()


-- Set the distribution version to empty if requested.
if tArgs.fEmptyDistributionVersion==true then
  tArgs.strDistributionVersion = ''
end


-----------------------------------------------------------------------------
--
-- Create a logger.
--

-- Set the logger level from the command line options.
local cLogger = require 'logging.console'()
cLogger:setLevel(tArgs.tLogLevel)


-----------------------------------------------------------------------------
--
-- Create a report.
--
local Report = require 'Report'
local cReport = Report(cLogger)


-----------------------------------------------------------------------------
--
-- Create a core.
--
local Core = require 'Core'
local cCore = Core(cLogger, cReport, strJonchkiPath)


-----------------------------------------------------------------------------
--
-- Call the core logic.
--
local tResult = nil

-- Is the "install" command active?
if tArgs.fCommandInstallSelected==true then
  tResult = command_install(cCore, tArgs)
  -- Write the report. This is important if an error occured somewhere in the core.
  cReport:write()
elseif tArgs.fCommandCacheSelected==true then
  error('The cache commands are not implemented yet.')
end

-- Exit.
if tResult~=true then
  os.exit(1)
else
  cLogger:info('All OK!')
  os.exit(0)
end
