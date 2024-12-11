local function command_install(cCore, tArgs, cLog)
  -- Get default for the project root.
  local path = require 'pl.path'
  local strProjectRoot = tArgs.strProjectRoot or path.currentdir()

  -- Read the system configuration.
  local tResult = cCore:read_system_configuration(
    tArgs.strSystemConfigurationFile,
    tArgs.fInstallBuildDependencies,
    strProjectRoot
  )
  if tResult~=nil then

    -- Get the platform ID.
    tResult = cCore:get_platform_id(tArgs.strCpuArchitecture, tArgs.strDistributionId, tArgs.strDistributionVersion)
    if tResult~=nil then

      -- Run the prepare script if there is one.
      local strPrepareScript = tArgs.strPrepareScript
      if strPrepareScript~=nil then
        tResult = cCore:runPrepareScript(strPrepareScript)
      end
      if tResult~=nil then
        -- Read the project configuration.
        tResult = cCore:read_project_configuration(tArgs.strProjectConfigurationFile)
        if tResult~=nil then

          -- Create the cache.
          if tArgs.fNoCache==true then
            cLog.info('Do not use a cache as requested.')
            tResult = true
          else
            tResult = cCore:create_cache()
          end
          if tResult==true then

            -- Create the resolver chain.
            cCore:create_resolver_chain()

            -- Create the resolver.
            tResult = cCore:create_resolver(tArgs.fInstallBuildDependencies, tArgs.strDependencyLogFile)
            if tResult==true then

              -- Resolve the root artifact and all dependencies.
              tResult = cCore:resolve_root_and_dependencies(
                tArgs.strGroup,
                tArgs.strModule,
                tArgs.strArtifact,
                tArgs.strVersion
              )
              if tResult==true then

                -- Download and install all artifacts.
                tResult = cCore:download_and_install_all_artifacts(
                  tArgs.fInstallBuildDependencies,
                  tArgs.fSkipRootArtifact,
                  tArgs.strDependencyLogFile
                )
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



local function command_install_dependencies(cCore, tArgs, cLog)
  -- Get default for the project root.
  local path = require 'pl.path'
  local strProjectRoot = tArgs.strProjectRoot or path.abspath(path.dirname(tArgs.strInputFile))

  -- Process the defines.
  local tResult = true
  local strDefinePrefix = 'define_'
  local atDefines = {}
  for _, strDefine in ipairs(tArgs.astrDefines) do
    local strKey, strValue = string.match(strDefine, '%s*([^ =]+)%s*=%s*([^ =]+)%s*')
    if strKey==nil then
      cLog.error('Define "%s" is invalid.', strDefine)
      tResult = false
    elseif string.sub(strKey, 1, string.len(strDefinePrefix))~=strDefinePrefix then
      cLog.error(
        'Define "%s" has an invalid key of "%s". All defines must start with "%s".',
        strDefine,
        strKey,
        strDefinePrefix
      )
      tResult = false
    elseif atDefines[strKey]~=nil then
      cLog.error('Redefinition of define "%s" from "%s" to "%s".', strKey, strValue, atDefines[strKey])
      tResult = false
    else
      cLog.info('Setting define "%s" = "%s".', strKey, strValue)
      atDefines[strKey] = strValue
    end
  end
  if tResult then
    -- Read the system configuration.
    tResult = cCore:read_system_configuration(
      tArgs.strSystemConfigurationFile,
      tArgs.fInstallBuildDependencies,
      strProjectRoot,
      atDefines
    )
    if tResult~=nil then

      -- Get the platform ID.
      tResult = cCore:get_platform_id(tArgs.strCpuArchitecture, tArgs.strDistributionId, tArgs.strDistributionVersion)
      if tResult~=nil then

        -- Run the prepare script if there is one.
        local strPrepareScript = tArgs.strPrepareScript
        if strPrepareScript~=nil then
          tResult = cCore:runPrepareScript(strPrepareScript)
        end
        if tResult~=nil then

          -- Read the project configuration.
          tResult = cCore:read_project_configuration(tArgs.strProjectConfigurationFile)
          if tResult~=nil then

            -- Create the cache.
            if tArgs.fNoCache==true then
              cLog.info('Do not use a cache as requested.')
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
                tResult = cCore:create_resolver(tArgs.fInstallBuildDependencies, tArgs.strDependencyLogFile)
                if tResult==true then

                  -- Resolve all dependencies.
                  tResult = cCore:resolve_all_dependencies()
                  if tResult==true then

                    -- Download and install all artifacts.
                    tResult = cCore:download_and_install_all_artifacts(
                      tArgs.fInstallBuildDependencies,
                      true,
                      tArgs.strDependencyLogFile
                    )
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



local function command_build(cCore, tArgs)
  -- Get the build matrix.
  local strBuildMatrix = tArgs.strBuildMatrix

  -- Get default for the project root.
  local path = require 'pl.path'
  local strProjectRoot = tArgs.strProjectRoot or path.abspath(path.dirname(strBuildMatrix))

  -- Get the LUA interpreter.
  local strLuaInterpreter = arg[-1]
  local strJonchkiScript = arg[0]
  local tResult = cCore:readBuildMatrixConfiguration(
    strBuildMatrix,
    tArgs.astrBuilds,
    strProjectRoot,
    strLuaInterpreter,
    strJonchkiScript
  )

  return tResult
end

  ------------------------------------------------------------------------------
--
-- Get the path to the application.
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


-- Get the LUA version number in the form major * 100 + minor .
local strMaj, strMin = string.match(_VERSION, '^Lua (%d+)%.(%d+)$')
if strMaj~=nil then
  _G.LUA_VER_NUM = tonumber(strMaj) * 100 + tonumber(strMin)
end

------------------------------------------------------------------------------

local argparse = require 'argparse'
local pl = require'pl.import_into'()


-- Try to read the package file.
local strPackageInfoFile = pl.path.join(strJonchkiPath, '.jonchki', 'package.txt')
local strPackageInfo = pl.utils.readfile(strPackageInfoFile, false)
-- Default to version "unknown".
local strJonchkiVersion = 'unknown'
local strJonchkiVcsVersion = 'unknown'
if strPackageInfo~=nil then
  strJonchkiVersion = string.match(strPackageInfo, 'PACKAGE_VERSION=([0-9.]+)')
  strJonchkiVcsVersion = string.match(strPackageInfo, 'PACKAGE_VCS_ID=([a-zA-Z0-9+]+)')
end


local atLogLevels = {
  'debug',
  'info',
  'warning',
  'error',
  'fatal'
}

local tParser = argparse('jonchki', 'A dependency manager for LUA packages.')
  :command_target("strSubcommand")

-- "--version" is special. It behaves like a command and is processed immediately during parsing.
tParser:flag('--version')
  :description('Show the version and exit.')
  :action(function()
    print(string.format('jonchki V%s %s', strJonchkiVersion, strJonchkiVcsVersion))
    os.exit(0, true)
  end)

-- Add the "install" command and all its options.
local tParserCommandInstall = tParser:command('install i', 'Install an artifact and all dependencies.')
  :target('fCommandInstallSelected')
tParserCommandInstall:argument('group', 'The group of the artifact to install.')
  :target('strGroup')
tParserCommandInstall:argument('module', 'The module of the artifact to install.')
  :target('strModule')
tParserCommandInstall:argument('artifact', 'The name of the aritfact to install.')
  :target('strArtifact')
tParserCommandInstall:argument('version', 'The version of the aritfact to install.')
  :target('strVersion')
tParserCommandInstall:flag('-b --build-dependencies')
  :description('Install the build dependencies.')
  :default(false)
  :target('fInstallBuildDependencies')
tParserCommandInstall:flag('-r --skip-root-artifact')
  :description('Do not install the root artifact but only its dependencies.')
  :default(false)
  :target('fSkipRootArtifact')
tParserCommandInstall:option('--prepare')
  :description('Run the installer script SCRIPT before everything else.')
  :argname('<SCRIPT>')
  :default(nil)
  :target('strPrepareScript')
tParserCommandInstall:option('--project-root')
  :description('Use PATH as the project root. Default is the current working folder.')
  :argname('<PATH>')
  :default(nil)
  :target('strProjectRoot')
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
tParserCommandInstall:option('-d --dependency-log')
  :description('Use the dependency log in FILE.')
  :argname('<FILE>')
  :default('dependency-log.xml')
  :target('strDependencyLogFile')
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
    :description(
      'Set the distribution version for the installation to the empty string. The default is to autodetect it.'
    )
    :target('fEmptyDistributionVersion')
)
tParserCommandInstall:option('-v --verbose')
  :description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
    table.concat(atLogLevels, ', ')
  ))
  :argname('<LEVEL>')
  :default('warning')
  :target('strLogLevel')
tParserCommandInstall:option('-l --logfile')
  :description('Write all output to FILE.')
  :argname('<FILE>')
  :default(nil)
  :target('strLogFileName')
tParserCommandInstall:mutex(
  tParserCommandInstall:flag('--no-console-log')
    :description('Do not print the log to the console. This is useful in combination with a log file.')
    :action("store_true")
    :target('fSuppressConsoleLog'),
  tParserCommandInstall:flag('--color')
    :description('Use colors to beautify the console output. This is the default on Linux.')
    :action("store_true")
    :target('fUseColor'),
  tParserCommandInstall:flag('--no-color')
    :description('Do not use colors for the console output. This is the default on Windows.')
    :action("store_false")
    :target('fUseColor')
)

-- Add the "install-dependencies" command and all its options.
local tParserCommandInstallDependencies = tParser:command(
  'install-dependencies',
  'Install all dependencies of an artifact, but not the artifact itself.'
)
  :target('fCommandInstallDependenciesSelected')
tParserCommandInstallDependencies:argument('input', 'The artifact configuration XML file.')
  :target('strInputFile')
tParserCommandInstallDependencies:flag('-b --build-dependencies')
  :description('Install the build dependencies.')
  :default(false)
  :target('fInstallBuildDependencies')
tParserCommandInstallDependencies:option('--prepare')
  :description('Run the installer script SCRIPT before everything else.')
  :argname('<SCRIPT>')
  :default(nil)
  :target('strPrepareScript')
tParserCommandInstallDependencies:option('--project-root')
  :description('Use PATH as the project root. Default is the path of the artifact configuration.')
  :argname('<PATH>')
  :default(nil)
  :target('strProjectRoot')
tParserCommandInstallDependencies:flag('-n --no-cache')
  :description('Do not use a cache, even if repositories are marked as cacheable.')
  :default(false)
  :target('fNoCache')
tParserCommandInstallDependencies:option('-p --prjcfg')
  :description('Load the project configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkicfg.xml')
  :target('strProjectConfigurationFile')
tParserCommandInstallDependencies:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandInstallDependencies:option('-d --dependency-log')
  :description('Use the dependency log in FILE.')
  :argname('<FILE>')
  :default('dependency-log.xml')
  :target('strDependencyLogFile')
tParserCommandInstallDependencies:option('--cpu-architecture')
  :description('Set the CPU architecture for the installation to ARCH. The default is to autodetect it.')
  :argname('<ARCH>')
  :default(nil)
  :target('strCpuArchitecture')
tParserCommandInstallDependencies:option('--distribution-id')
  :description('Set the distribution id for the installation to ID. The default is to autodetect it.')
  :argname('<ID>')
  :default(nil)
  :target('strDistributionId')
tParserCommandInstallDependencies:mutex(
  tParserCommandInstallDependencies:option('--distribution-version')
    :description('Set the distribution version for the installation to VERSION. The default is to autodetect it.')
    :argname('<VERSION>')
    :default(nil)
    :target('strDistributionVersion'),
  tParserCommandInstallDependencies:flag('--empty-distribution-version')
    :description(
      'Set the distribution version for the installation to the empty string. The default is to autodetect it.'
    )
    :target('fEmptyDistributionVersion')
)
tParserCommandInstallDependencies:option('--define')
  :description('Add a define in the form KEY=VALUE.')
  :count('*')
  :target('astrDefines')
tParserCommandInstallDependencies:option('-v --verbose')
  :description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
    table.concat(atLogLevels, ', ')
  ))
  :argname('<LEVEL>')
  :default('warning')
  :target('strLogLevel')
tParserCommandInstallDependencies:option('-l --logfile')
  :description('Write all output to FILE.')
  :argname('<FILE>')
  :default(nil)
  :target('strLogFileName')
tParserCommandInstallDependencies:mutex(
  tParserCommandInstallDependencies:flag('--no-console-log')
    :description('Do not print the log to the console. This is useful in combination with a log file.')
    :action("store_true")
    :target('fSuppressConsoleLog'),
  tParserCommandInstallDependencies:flag('--color')
    :description('Use colors to beautify the console output. This is the default on Linux.')
    :action("store_true")
    :target('fUseColor'),
  tParserCommandInstallDependencies:flag('--no-color')
    :description('Do not use colors for the console output. This is the default on Windows.')
    :action("store_false")
    :target('fUseColor')
)

-- Add the "build" command and all its options.
local tParserCommandBuild = tParser:command('build', 'Process a build matrix.')
  :target('fCommandBuildSelected')
tParserCommandBuild:argument(
  'builds',
  'Process only the builds with <BUILDID> . The default is to process all default builds.'
)
  :argname('<BUILDID>')
  :args('*')
  :target('astrBuilds')
tParserCommandBuild:option('--build-matrix')
  :description('Use LUA_SCRIPT to define the build matrix.')
  :argname('<LUA_SCRIPT>')
  :default('build_matrix.lua')
  :target('strBuildMatrix')
tParserCommandBuild:option('--project-root')
  :description('Use PATH as the project root. Default is the path of the artifact configuration.')
  :argname('<PATH>')
  :default(nil)
  :target('strProjectRoot')
tParserCommandBuild:option('-v --verbose')
  :description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
    table.concat(atLogLevels, ', ')
  ))
  :argname('<LEVEL>')
  :default('info')
  :target('strLogLevel')
tParserCommandBuild:option('-l --logfile')
  :description('Write all output to FILE.')
  :argname('<FILE>')
  :default(nil)
  :target('strLogFileName')
tParserCommandBuild:mutex(
  tParserCommandBuild:flag('--no-console-log')
    :description('Do not print the log to the console. This is useful in combination with a log file.')
    :action("store_true")
    :target('fSuppressConsoleLog'),
  tParserCommandBuild:flag('--color')
    :description('Use colors to beautify the console output. This is the default on Linux.')
    :action("store_true")
    :target('fUseColor'),
  tParserCommandBuild:flag('--no-color')
    :description('Do not use colors for the console output. This is the default on Windows.')
    :action("store_false")
    :target('fUseColor')
)

-- Add the "cache" command and all its options.
local tParserCommandCache = tParser:command('cache c', 'Examine and modify the cache.')
  :target('fCommandCacheSelected')
  :command_target("strCacheSubcommand")
local tParserCommandCacheCheck = tParserCommandCache:command(
  'check',
  'Check the complete cache for invalid entries, missing or stray files and total size.'
)
  :target('fCommandCacheCheckSelected')
tParserCommandCacheCheck:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandCacheCheck:option('-v --verbose')
  :description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
    table.concat(atLogLevels, ', ')
  ))
  :argname('<LEVEL>')
  :default('warning')
  :target('strLogLevel')
tParserCommandCacheCheck:option('-l --logfile')
  :description('Write all output to FILE.')
  :argname('<FILE>')
  :default(nil)
  :target('strLogFileName')
tParserCommandCacheCheck:mutex(
  tParserCommandCacheCheck:flag('--color')
    :description('Use colors to beautify the console output. This is the default on Linux.')
    :action("store_true")
    :target('fUseColor'),
  tParserCommandCacheCheck:flag('--no-color')
    :description('Do not use colors for the console output. This is the default on Windows.')
    :action("store_false")
    :target('fUseColor')
)
local tParserCommandCacheClear = tParserCommandCache:command('clear', 'Remove all entries from the cache.')
  :target('fCommandCacheClearSelected')
tParserCommandCacheClear:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandCacheClear:option('-v --verbose')
  :description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
    table.concat(atLogLevels, ', ')
  ))
  :argname('<LEVEL>')
  :default('warning')
  :target('strLogLevel')
tParserCommandCacheClear:option('-l --logfile')
  :description('Write all output to FILE.')
  :argname('<FILE>')
  :default(nil)
  :target('strLogFileName')
tParserCommandCacheClear:mutex(
  tParserCommandCacheClear:flag('--color')
    :description('Use colors to beautify the console output. This is the default on Linux.')
    :action("store_true")
    :target('fUseColor'),
  tParserCommandCacheClear:flag('--no-color')
    :description('Do not use colors for the console output. This is the default on Windows.')
    :action("store_false")
    :target('fUseColor')
)
local tParserCommandCacheShow = tParserCommandCache:command('show', 'Show all contents of the cache.')
  :target('fCommandCacheShowSelected')
tParserCommandCacheShow:option('-s --syscfg')
  :description('Load the system configuration from FILE.')
  :argname('<FILE>')
  :default('jonchkisys.cfg')
  :target('strSystemConfigurationFile')
tParserCommandCacheShow:option('-v --verbose')
  :description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
    table.concat(atLogLevels, ', ')
  ))
  :argname('<LEVEL>')
  :default('warning')
  :target('strLogLevel')
tParserCommandCacheShow:option('-l --logfile')
  :description('Write all output to FILE.')
  :argname('<FILE>')
  :default(nil)
  :target('strLogFileName')
tParserCommandCacheShow:mutex(
  tParserCommandCacheShow:flag('--color')
    :description('Use colors to beautify the console output. This is the default on Linux.')
    :action("store_true")
    :target('fUseColor'),
  tParserCommandCacheShow:flag('--no-color')
    :description('Do not use colors for the console output. This is the default on Windows.')
    :action("store_false")
    :target('fUseColor')
)

local tArgs = tParser:parse()

-- Set the distribution version to empty if requested.
if tArgs.fEmptyDistributionVersion==true then
  tArgs.strDistributionVersion = ''
end


-----------------------------------------------------------------------------
--
-- Create a log writer.
--

local fUseColor = tArgs.fUseColor
if fUseColor==nil then
  if pl.path.is_windows==true then
    -- Running on windows. Do not use colors by default as cmd.exe
    -- does not support ANSI on all windows versions.
    fUseColor = false
  else
    -- Running on Linux. Use colors by default.
    fUseColor = true
  end
end

-- Collect all log writers.
local atLogWriters = {}

-- Create the console logger.
if tArgs.fSuppressConsoleLog~=true then
  local tLogWriterConsole
  if fUseColor==true then
    tLogWriterConsole = require 'log.writer.console.color'.new()
  else
    tLogWriterConsole = require 'log.writer.console'.new()
  end
  table.insert(atLogWriters, tLogWriterConsole)
end

-- Create the file logger if requested.
if tArgs.strLogFileName~=nil then
  local tLogWriterFile = require 'log.writer.file'.new{
    log_name = pl.path.basename(tArgs.strLogFileName),
    log_dir = pl.path.dirname(tArgs.strLogFileName)
  }
  table.insert(atLogWriters, tLogWriterFile)
end

-- Combine all writers.
local tLogWriter
if _G.LUA_VER_NUM==501 then
  tLogWriter = require 'log.writer.list'.new(unpack(atLogWriters))
else
  tLogWriter = require 'log.writer.list'.new(table.unpack(atLogWriters))
end

-- Set the logger level from the command line options.
local cLogWriter = require 'log.writer.filter'.new(tArgs.strLogLevel, tLogWriter)
local cLogWriterSystem = require 'log.writer.prefix'.new('[System] ', cLogWriter)
local cLog = require "log".new(
  -- maximum log level
  "trace",
  cLogWriterSystem,
  -- Formatter
  require "log.formatter.format".new()
)


-----------------------------------------------------------------------------
--
-- Create a report.
--
local Report = require 'Report'
local cReport = Report(cLogWriter, strJonchkiPath)


-----------------------------------------------------------------------------
--
-- Create a core.
--
local Core = require 'Core'
local cCore = Core(cLogWriter, cReport)


-----------------------------------------------------------------------------
--
-- Call the core logic.
--
local tResult = nil

-- Is the "install" command active?
if tArgs.fCommandInstallSelected==true then
  tResult = command_install(cCore, tArgs, cLog)
  -- Write the report. This is important if an error occured somewhere in the core.
  cReport:write()

-- Is the "install-dependencies" command active?
elseif tArgs.fCommandInstallDependenciesSelected==true then
  tResult = command_install_dependencies(cCore, tArgs, cLog)
  -- Write the report. This is important if an error occured somewhere in the core.
  cReport:write()

-- Is the "build" command active?
elseif tArgs.fCommandBuildSelected==true then
  tResult = command_build(cCore, tArgs, cLog)

  -- Do not write a report here. It has no useful information.

-- Is the "cache" command active?
elseif tArgs.fCommandCacheSelected==true then
  error('The cache commands are not implemented yet.')
end

-- Exit.
if tResult~=true then
  os.exit(1, true)
else
  cLog.info('All OK!')
  os.exit(0, true)
end
