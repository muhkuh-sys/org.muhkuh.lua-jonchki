local t = ...
local strDistId, strDistVersion, strCpuArch = t:get_platform()


-- Copy all jonchki scripts.
t:install{
  ['local/jonchki.lua']                                  = '${install_base}/',
  ['doc/jonchkicfg.xml']                                 = '${install_doc}/',
  ['doc/jonchkireport.xsl']                              = '${install_doc}/',
  ['doc/jonchkisys.cfg']                                 = '${install_doc}/',
  ['local/lua/buildmatrix/buildmatrix_helper.lua']       = '${install_lua_path}/buildmatrix/',
  ['local/lua/cache/cache.lua']                          = '${install_lua_path}/cache/',
  ['local/lua/installer/archives.lua']                   = '${install_lua_path}/installer/',
  ['local/lua/installer/installer.lua']                  = '${install_lua_path}/installer/',
  ['local/lua/installer/install_helper.lua']             = '${install_lua_path}/installer/',
  ['local/lua/lustache.lua']                             = '${install_lua_path}/',
  ['local/lua/lustache/context.lua']                     = '${install_lua_path}/lustache/',
  ['local/lua/lustache/renderer.lua']                    = '${install_lua_path}/lustache/',
  ['local/lua/lustache/scanner.lua']                     = '${install_lua_path}/lustache/',
  ['local/lua/platform/platform.lua']                    = '${install_lua_path}/platform/',
  ['local/lua/prepare/prepare_helper.lua']               = '${install_lua_path}/prepare/',
  ['local/lua/repository_driver/repository_driver.lua']  = '${install_lua_path}/repository_driver/',
  ['local/lua/repository_driver/filesystem.lua']         = '${install_lua_path}/repository_driver/',
  ['local/lua/repository_driver/http.lua']               = '${install_lua_path}/repository_driver/',
  ['local/lua/repository_driver/url.lua']                = '${install_lua_path}/repository_driver/',
  ['local/lua/resolver/policies/policy.lua']             = '${install_lua_path}/resolver/policies/',
  ['local/lua/resolver/policies/policy002.lua']          = '${install_lua_path}/resolver/policies/',
  ['local/lua/resolver/policies/policy001.lua']          = '${install_lua_path}/resolver/policies/',
  ['local/lua/resolver/resolver.lua']                    = '${install_lua_path}/resolver/',
  ['local/lua/resolver/resolver_chain.lua']              = '${install_lua_path}/resolver/',
  ['local/lua/test_description.lua']                     = '${install_lua_path}/',
  ['local/lua/vcs_version.lua']                          = '${install_lua_path}/',
  ['local/lua/ArtifactConfiguration.lua']                = '${install_lua_path}/',
  ['local/lua/Core.lua']                                 = '${install_lua_path}/',
  ['local/lua/DependencyLog.lua']                        = '${install_lua_path}/',
  ['local/lua/Hash.lua']                                 = '${install_lua_path}/',
  ['local/lua/ProjectConfiguration.lua']                 = '${install_lua_path}/',
  ['local/lua/Report.lua']                               = '${install_lua_path}/',
  ['local/lua/Version.lua']                              = '${install_lua_path}/',
  ['local/lua/SystemConfiguration.lua']                  = '${install_lua_path}/',
  ['local/wrapper/jonchki']                              = '${install_base}/',
  ['${report_path}']                                     = '${install_base}/.jonchki/'
}

return true
