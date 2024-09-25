--- The configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local SystemConfiguration = class()



function SystemConfiguration:_init(cLog, fInstallBuildDependencies, strProjectRoot, atDefines)
  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[SystemConfiguration] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  self.fInstallBuildDependencies = fInstallBuildDependencies
  self.strProjectRoot = strProjectRoot
  self.atDefines = atDefines

  -- There is no configuration yet.
  self.tConfiguration = nil
end



--- Convert a string with an optional postfix to a number.
-- Parse a string with an optional postfix to a number.
-- The postfix must be exactly one of the following letters or empty:
--   K, M, G
-- "K" stands for a multiplier of 1024, M for 1024*1024 and G for
-- 1024*1024*1024.
-- @param strNumber The number as a string.
-- @return The converted number.
function SystemConfiguration.pretty_string_to_number(strNumber)
  local atMultiplier = {
    K = 1024,
    M = 1024*1024,
    G = 1024*1024*1024
  }

  local ulNumber = nil
  if string.len(strNumber)~=0 then
    -- Get the last digit of the string.
    local strLast = string.sub(strNumber, -1)
    -- Get the multiplier.
    local ulMultiplier = atMultiplier[strLast]
    if ulMultiplier~=nil then
      -- Cut off the multiplier.
      strNumber = string.sub(strNumber, 1, -2)
    else
      -- No multiplier present, use the default of 1.
      ulMultiplier = 1
    end

    local ulValue = tonumber(strNumber)
    if ulValue~=nil then
      ulNumber = ulValue * ulMultiplier
    end
  end

  return ulNumber
end



function SystemConfiguration.is_path_child_or_equal(strPathRoot, strPathChild)
  local tResult


  if strPathRoot==strPathChild then
    tResult = true
  else
    -- Get the relative path from the child to the root path.
    local path = require 'pl.path'
    local strPath = path.relpath(strPathRoot, strPathChild)
    -- If child is really below root, this must start with "..".
    tResult = (string.sub(strPath, 1, 2) == "..")
  end

  return tResult
end



function SystemConfiguration:parse_configuration(strConfigurationFilename)
  local tLog = self.tLog

  -- Be pessimistic...
  local tResult = nil

  tLog.info('Reading the system configuration from "%s"', strConfigurationFilename)

  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    tLog.fatal('The SystemConfiguration class expects a filename as a parameter.')
  else
    -- Read the configuration file into a LUA table.
    local config = require 'pl.config'
    local tCfg,strError = config.read(strConfigurationFilename)
    if tCfg==nil then
      tLog.fatal('Failed to read the configuration file: %s', strError)
    else
      local atOptions = {
        { key='work',                   required=true,  replacement=true,  default=nil },
        { key='cache',                  required=false, replacement=false, default='${work}/cache' },
        { key='cache_max_size',         required=false, replacement=false, default='512M' },
        { key='depack',                 required=false, replacement=false, default='${work}/depack' },
        { key='build',                  required=false, replacement=true,  default='${work}/build' },
        { key='build_doc',              required=false, replacement=false, default='${build}/doc' },
        { key='install_base',           required=false, replacement=true,  default='${work}/install' },
        { key='install_executables',    required=false, replacement=false, default='${install_base}' },
        { key='install_shared_objects', required=false, replacement=false, default='${install_base}' },
        { key='install_lua_path',       required=false, replacement=false, default='${install_base}/lua' },
        { key='install_lua_cpath',      required=false, replacement=false, default='${install_base}/lua_plugins' },
        { key='install_doc',            required=false, replacement=false, default='${install_base}/doc' },
        { key='install_dev',            required=false, replacement=true,  default='${install_base}/dev' },
        { key='install_dev_include',    required=false, replacement=false, default='${install_dev}/include' },
        { key='install_dev_lib',        required=false, replacement=false, default='${install_dev}/lib' },
        { key='install_dev_cmake',      required=false, replacement=false, default='${install_dev}/cmake' }
      }

      -- Check if all required entries are present.
      local atMissing = {}
      for _,tAttr in ipairs(atOptions) do
        local strKey = tAttr.key
        if tAttr.required==true and tCfg[strKey]==nil then
          table.insert(atMissing, strKey)
        end
      end
      if #atMissing ~= 0 then
        tLog.fatal(
          'Invalid configuration. The following required keys are not present: %s',
          table.concat(atMissing, ', ')
        )
      else
        -- Loop over all configuration entries and check if they are valid.
        local atUnknown = {}
        for strKey,_ in pairs(tCfg) do
          local fFound = false
          for _,tAttr in ipairs(atOptions) do
            if tAttr.key==strKey then
              fFound = true
              break
            end
          end
          if fFound==false then
            table.insert(atUnknown. strKey)
          end
        end
        if #atUnknown ~= 0 then
          tLog.warning('Warning: Ignoring unknown configuration entries: %s', table.concat(atUnknown, ', '))
        end

        -- Collect all options in a new table.
        local atConfiguration = {}
        -- Collect all replacements in a new table.
        local atReplacements = {}

        -- Add the project root.
        local strProjectRoot = self.strProjectRoot
        atConfiguration['prj_root'] = strProjectRoot
        atReplacements['prj_root'] = strProjectRoot

        -- Add the VCS version.
        local tVcsVersion = require 'vcs_version'(self.cLog)
        local strVcsVersion, strVcsVersionLong = tVcsVersion:getVcsVersion(strProjectRoot)
        atConfiguration['prj_version_vcs'] = strVcsVersion
        atConfiguration['prj_version_vcs_long'] = strVcsVersionLong

        -- Add the commandline defines with a "define_" prefix.
        for strDefineKey, strDefineValue in pairs(self.atDefines) do
          atConfiguration[strDefineKey] = strDefineValue
        end

        -- Parse all options.
        for _,tAttr in ipairs(atOptions) do
          -- Get the key.
          local strKey = tAttr.key
          -- Get the value.
          local tValue = tCfg[strKey]
          if tValue==nil then
            -- Get the default value.
            tValue = tAttr.default
          end

          -- Replace.
          local strValue = string.gsub(tValue, '%${([a-zA-Z0-9_]+)}', atReplacements)
          atConfiguration[strKey] = strValue

          if tAttr.replacement==true then
            atReplacements[strKey] = strValue
          end
        end

        -- 'cache_max_size' must be a number.
        local strValue = atConfiguration.cache_max_size
        local ulValue = self.pretty_string_to_number(strValue)
        if ulValue==nil then
          tLog.fatal('Invalid value for "cache_max_size": %s', strValue)
        else
          atConfiguration.cache_max_size = ulValue

          -- Convert all paths to ablosute.
          local path = require 'pl.path'
          atConfiguration.prj_root = path.abspath(path.expanduser(atConfiguration.prj_root))
          atConfiguration.work = path.abspath(path.expanduser(atConfiguration.work))
          atConfiguration.cache = path.abspath(path.expanduser(atConfiguration.cache))
          atConfiguration.depack = path.abspath(path.expanduser(atConfiguration.depack))
          atConfiguration.build = path.abspath(path.expanduser(atConfiguration.build))
          atConfiguration.build_doc = path.abspath(path.expanduser(atConfiguration.build_doc))
          atConfiguration.install_base = path.abspath(path.expanduser(atConfiguration.install_base))
          atConfiguration.install_executables = path.abspath(path.expanduser(atConfiguration.install_executables))
          atConfiguration.install_shared_objects = path.abspath(
            path.expanduser(atConfiguration.install_shared_objects)
          )
          atConfiguration.install_lua_path = path.abspath(path.expanduser(atConfiguration.install_lua_path))
          atConfiguration.install_lua_cpath = path.abspath(path.expanduser(atConfiguration.install_lua_cpath))
          atConfiguration.install_doc = path.abspath(path.expanduser(atConfiguration.install_doc))
          atConfiguration.install_dev = path.abspath(path.expanduser(atConfiguration.install_dev))
          atConfiguration.install_dev_include = path.abspath(path.expanduser(atConfiguration.install_dev_include))
          atConfiguration.install_dev_lib = path.abspath(path.expanduser(atConfiguration.install_dev_lib))
          atConfiguration.install_dev_cmake = path.abspath(path.expanduser(atConfiguration.install_dev_cmake))

          -- install_lua_path must be below install_base.
          local fnCheck = self.is_path_child_or_equal
          if fnCheck(atConfiguration.install_base, atConfiguration.install_lua_path)~=true then
            tLog.fatal("The path install_lua_path is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_lua_cpath)~=true then
            tLog.fatal("The path install_lua_cpath is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_executables)~=true then
            tLog.fatal("The path install_executables is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_shared_objects)~=true then
            tLog.fatal("The path install_shared_objects is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_doc)~=true then
            tLog.fatal("The path install_doc is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_dev)~=true then
            tLog.fatal("The path install_dev is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_dev_include)~=true then
            tLog.fatal("The path install_dev_include is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_dev_lib)~=true then
            tLog.fatal("The path install_dev_lib is not below install_base!")
          elseif fnCheck(atConfiguration.install_base, atConfiguration.install_dev_cmake)~=true then
            tLog.fatal("The path install_dev_cmake is not below install_base!")
          else
            -- Store the configuration.
            self.tConfiguration = atConfiguration

            -- Success!
            tResult = true

            -- Show tht configuration in the debug log.
            tLog.debug('System configuration: %s', tostring(self))
          end
        end
      end
    end
  end

  return tResult
end



function SystemConfiguration:initialize_paths()
  local tLog = self.tLog
  -- Be optimistic!
  local tResult = true
  local strError

  local atPaths = {}
  table.insert(atPaths, { strKey='work',                   fClear=false })
  table.insert(atPaths, { strKey='cache',                  fClear=false })
  table.insert(atPaths, { strKey='depack',                 fClear=true })
  table.insert(atPaths, { strKey='build',                  fClear=true })
  table.insert(atPaths, { strKey='build_doc',              fClear=true })
  table.insert(atPaths, { strKey='install_base',           fClear=true })
  table.insert(atPaths, { strKey='install_executables',    fClear=true })
  table.insert(atPaths, { strKey='install_shared_objects', fClear=true })
  table.insert(atPaths, { strKey='install_lua_path',       fClear=true })
  table.insert(atPaths, { strKey='install_lua_cpath',      fClear=true })
  table.insert(atPaths, { strKey='install_doc',            fClear=true })
  if self.fInstallBuildDependencies==true then
    table.insert(atPaths, { strKey='install_dev',            fClear=true })
    table.insert(atPaths, { strKey='install_dev_include',    fClear=true })
    table.insert(atPaths, { strKey='install_dev_lib',        fClear=true })
    table.insert(atPaths, { strKey='install_dev_cmake',      fClear=true })
  end

  -- Check if all paths exists. Try to create them otherwise.
  for _, tAttr in pairs(atPaths) do
    -- Get the path.
    local strPath = self.tConfiguration[tAttr.strKey]

    -- Check if the path already exists.
    local path = require 'pl.path'
    local dir = require 'pl.dir'
    if path.exists(strPath)~=strPath then
      -- The path does not exist yet. Try to create it.
      tResult, strError = dir.makepath(strPath)
      if tResult~=true then
        tResult = nil
        tLog.fatal('Failed to create the path "%s": %s', strPath, strError)
        break
      end

    else
      -- The path already exists. It must be a folder.
      if path.isdir(strPath)~=true then
        tResult = nil
        tLog.fatal('The path "%s" is no directory!', strPath)
        break
      end

      -- Clear the path.
      if tAttr.fClear==true then
        tResult, strError = dir.rmtree(strPath)
        if tResult~=true then
          tResult = nil
          tLog.fatal('Failed to remove the path "%s": %s', strPath, strError)
          break
        end

        -- Create the path again.
        tResult, strError = dir.makepath(strPath)
        if tResult~=true then
          tResult = nil
          tLog.fatal('Failed to create the path "%s": %s', strPath, strError)
          break
        end
      end
    end
  end

  return tResult
end



--- Return the complete configuration as a string.
-- @return The configuration as a string.
function SystemConfiguration:__tostring()
  local strCfg

  if self.tConfiguration==nil then
    strCfg = 'SystemConfiguration()'
  else
    local pretty = require 'pl.pretty'
    strCfg = string.format('SystemConfiguration(\n%s\n)', pretty.write(self.tConfiguration))
  end

  return strCfg
end


return SystemConfiguration
