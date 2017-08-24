local t = ...
local strDistId, strDistVersion, strCpuArch = t:get_platform()
local cLogger = t.cLogger

-- Copy all jonchki scripts.
local atScripts = {
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
  ['../lua/Hash.lua']                                 = '${install_lua_path}/',
  ['../lua/ProjectConfiguration.lua']                 = '${install_lua_path}/',
  ['../lua/Report.lua']                               = '${install_lua_path}/',
  ['../lua/Version.lua']                              = '${install_lua_path}/',
  ['../lua/SystemConfiguration.lua']                  = '${install_lua_path}/'
}
for strSrc, strDst in pairs(atScripts) do
  t:install(strSrc, strDst)
end


local archives = require 'installer.archives'
local Archive = archives(cLogger)
local pl = require'pl.import_into'()

local strArtifact = string.format('jonchki_%s%s_%s', strDistId, strDistVersion, strCpuArch)
local strDiskPath = t:replace_template('${install_base}')
local strArchiveMemberPrefix = 'jonchki'

-- Create a ZIP archive for Windows platforms. Build a "tar.gz" for Linux.
local strArchiveExtension
local tFormat
local atFilter
if strDistId=='windows' then
  strArchiveExtension = 'zip'
  tFormat = Archive.archive.ARCHIVE_FORMAT_ZIP
  atFilter = {}
else
  strArchiveExtension = 'tar.gz'
  tFormat = Archive.archive.ARCHIVE_FORMAT_TAR_GNUTAR
  atFilter = { Archive.archive.ARCHIVE_FILTER_GZIP }
end

-- Create the full path to the archive.
local strArchive = t:replace_template(string.format('${install_base}/../%s.%s', strArtifact, strArchiveExtension))
local tResult = Archive:pack_archive(strArchive, tFormat, atFilter, strDiskPath, strArchiveMemberPrefix)

return tResult