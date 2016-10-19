--- The configuration handler.
-- The configuration handler provides read-only access to the settings from
-- a configuration file.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the configuration class.
local class = require 'pl.class'
local SystemConfiguration = class()



function SystemConfiguration:_init()
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()
  
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
function SystemConfiguration:pretty_string_to_number(strNumber)
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



function SystemConfiguration:is_path_child(strPathRoot, strPathChild)
  -- Get the relative path from the child to the root path.
  local strPath = self.pl.path.relpath(strPathRoot, strPathChild)
  -- If child is really below root, this must start with "..".
  return string.sub(strPath, 1, 2)==".."
end



function SystemConfiguration:parse_configuration(strConfigurationFilename)
  -- The filename of the configuration is a required parameter.
  if strConfigurationFilename==nil then
    error('The SystemConfiguration class expects a filename as a parameter.')
  end

  -- Read the configuration file into a LUA table.
  local tCfg,strError = self.pl.config.read(strConfigurationFilename)
  if tCfg==nil then
    error(string.format('Failed to read the configuration file: %s', strError))
  end

  local atOptions = {
    { key='work',                   required=true,  replacement=true,  default=nil },
    { key='cache',                  required=false, replacement=false, default='${work}/cache' },
    { key='cache_max_size',         required=false, replacement=false, default='512M' },
    { key='depack',                 required=false, replacement=false, default='${work}/depack' },
    { key='install_base',           required=false, replacement=true,  default='${work}/install' },
    { key='install_lua_path',       required=false, replacement=false, default='${install_base}/lua' },
    { key='install_lua_cpath',      required=false, replacement=false, default='${install_base}/lua_plugins' },
    { key='install_shared_objects', required=false, replacement=false, default='${install_base}/shared_objects' },
    { key='install_doc',            required=false, replacement=false, default='${install_base}/doc' }
  }

  -- Check if all required entries are present.
  local atMissing = {}
  for uiCnt,tAttr in ipairs(atOptions) do
    local strKey = tAttr.key
    if tAttr.required==true and tCfg[strKey]==nil then
      table.insert(atMissing, strKey)
    end
  end
  if #atMissing ~= 0 then
    error(string.format('Invalid configuration. The following required keys are not present: %s', table.concat(atMissing, ', ')))
  end

  -- Loop over all configuration entries and check if they are valid.
  local atUnknown = {}
  for strKey,tValue in pairs(tCfg) do
    local fFound = false
    for uiCnt,tAttr in ipairs(atOptions) do
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
    print(string.format('Warning: Ignoring unknown configuration entries: %s', table.concat(atUnknown, ', ')))
  end

  -- Collect all options in a new table.
  local atConfiguration = {}
  -- Collect all replacements in a new table.
  local atReplacements = {}
  
  -- Parse all options.
  for uiCnt,tAttr in ipairs(atOptions) do
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
  local ulValue = self:pretty_string_to_number(strValue)
  if ulValue==nil then
    error(string.format('Invalid value for "cache_max_size": %s', strValue))
  end
  atConfiguration.cache_max_size = ulValue
  
  -- Convert all paths to ablosute.
  atConfiguration.work = self.pl.path.abspath(atConfiguration.work)
  atConfiguration.depack = self.pl.path.abspath(atConfiguration.depack)
  atConfiguration.install_base = self.pl.path.abspath(atConfiguration.install_base)
  atConfiguration.install_lua_path = self.pl.path.abspath(atConfiguration.install_lua_path)
  atConfiguration.install_lua_cpath = self.pl.path.abspath(atConfiguration.install_lua_cpath)
  atConfiguration.install_shared_objects = self.pl.path.abspath(atConfiguration.install_shared_objects)
  atConfiguration.install_doc = self.pl.path.abspath(atConfiguration.install_doc)

  -- install_lua_path must be below install_base.
  if self:is_path_child(atConfiguration.install_base, atConfiguration.install_lua_path)~=true then
    error("The install_lua_path is not below install_base!")
  end
  if self:is_path_child(atConfiguration.install_base, atConfiguration.install_lua_cpath)~=true then
    error("The install_lua_cpath is not below install_base!")
  end
  if self:is_path_child(atConfiguration.install_base, atConfiguration.install_shared_objects)~=true then
    error("The install_shared_objects is not below install_base!")
  end
  if self:is_path_child(atConfiguration.install_base, atConfiguration.install_doc)~=true then
    error("The install_doc is not below install_base!")
  end

  -- Store the configuration.
  self.tConfiguration = atConfiguration
end


--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function SystemConfiguration:__tostring()
  local strCfg = nil
  
  if self.tConfiguration==nil then
    strCfg = 'SystemConfiguration()'
  else
    strCfg = string.format('SystemConfiguration(\n%s\n)', self.pl.pretty.write(self.tConfiguration))
  end
  
  return strCfg
end


return SystemConfiguration
