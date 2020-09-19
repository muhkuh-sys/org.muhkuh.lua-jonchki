local t = ...
local strDistId, strDistVersion, strCpuArch = t:get_platform()


-- Copy all jonchki scripts.
t:install{
  ['../jonchki.lua']                                  = '${install_base}/',
  ['../doc/jonchkicfg.xml']                           = '${install_doc}/',
  ['../doc/jonchkireport.xsl']                        = '${install_doc}/',
  ['../doc/jonchkisys.cfg']                           = '${install_doc}/',
  ['../lua/cache/cache.lua']                          = '${install_lua_path}/cache/',
  ['../lua/installer/archives.lua']                   = '${install_lua_path}/installer/',
  ['../lua/installer/installer.lua']                  = '${install_lua_path}/installer/',
  ['../lua/installer/install_helper.lua']             = '${install_lua_path}/installer/',
  ['../lua/platform/platform.lua']                    = '${install_lua_path}/platform/',
  ['../lua/repository_driver/repository_driver.lua']  = '${install_lua_path}/repository_driver/',
  ['../lua/repository_driver/filesystem.lua']         = '${install_lua_path}/repository_driver/',
  ['../lua/repository_driver/url.lua']                = '${install_lua_path}/repository_driver/',
  ['../lua/resolver/policies/policy.lua']             = '${install_lua_path}/resolver/policies/',
  ['../lua/resolver/policies/policy002.lua']          = '${install_lua_path}/resolver/policies/',
  ['../lua/resolver/policies/policy001.lua']          = '${install_lua_path}/resolver/policies/',
  ['../lua/resolver/resolver.lua']                    = '${install_lua_path}/resolver/',
  ['../lua/resolver/resolver_chain.lua']              = '${install_lua_path}/resolver/',
  ['../lua/ArtifactConfiguration.lua']                = '${install_lua_path}/',
  ['../lua/Core.lua']                                 = '${install_lua_path}/',
  ['../lua/DependencyLog.lua']                        = '${install_lua_path}/',
  ['../lua/Hash.lua']                                 = '${install_lua_path}/',
  ['../lua/ProjectConfiguration.lua']                 = '${install_lua_path}/',
  ['../lua/Report.lua']                               = '${install_lua_path}/',
  ['../lua/Version.lua']                              = '${install_lua_path}/',
  ['../lua/SystemConfiguration.lua']                  = '${install_lua_path}/',
  ['${report_path}']                                  = '${install_base}/.jonchki/'
}

-- Install the wrapper.
if strDistId=='windows' then
  t:install('../wrapper/windows/jonchki.bat', '${install_base}/')
elseif strDistId=='ubuntu' then
  -- This is a shell script setting the library search path for the LUA shared object.
  t:install('../wrapper/linux/jonchki', '${install_base}/')
end

-- Create the package file.
t:createPackageFile()

-- Create a hash file.
t:createHashFile()

-- Build the artifact.
t:createArchive('${install_base}/../../../../${default_archive_name}', 'native')

return true

