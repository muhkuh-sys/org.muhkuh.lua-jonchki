local t = ...
local strDistId, strDistVersion, strCpuArch = t:get_platform()
local cLogger = t.cLogger
local tResult
local archives = require 'installer.archives'
local pl = require'pl.import_into'()


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
  ['../lua/SystemConfiguration.lua']                  = '${install_lua_path}/',
  ['${report_path}']                                  = '${install_base}/.jonchki/',
  ['${report_xslt}']                                  = '${install_base}/.jonchki/'
}
for strSrc, strDst in pairs(atScripts) do
  t:install(strSrc, strDst)
end

-- Install the wrapper.
if strDistId=='windows' then
  t:install('../wrapper/windows/jonchki.bat', '${install_base}/')
elseif strDistId=='ubuntu' then
  -- This is a shell script setting the library search path for the LUA shared object.
  t:install('../wrapper/linux/jonchki', '${install_base}/')
end

-- Create the package file.
local strPackageText = t:replace_template([[PACKAGE_NAME=${root_artifact_artifact}
PACKAGE_VERSION=${root_artifact_version}
PACKAGE_VCS_ID=${root_artifact_vcs_id}
HOST_DISTRIBUTION_ID=${platform_distribution_id}
HOST_DISTRIBUTION_VERSION=${platform_distribution_version}
HOST_CPU_ARCHITECTURE=${platform_cpu_architecture}
]])
local strPackagePath = t:replace_template('${install_base}/.jonchki/package.txt')
local tFileError, strError = pl.utils.writefile(strPackagePath, strPackageText, false)
if tFileError==nil then
  cLogger:error('Failed to write the package file "%s": %s', strPackagePath, strError)
else
  local Archive = archives(cLogger)

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

  -- Translate the CPU architecture to bits.
  local atCpuArchToBits = {
    ['x86'] = 32,
    ['x86_64'] = 64
  }
  local uiPlatformBits = atCpuArchToBits[strCpuArch]
  if uiPlatformBits==nil then
    cLogger:error('Failed to translate the CPU architecture "%s" to bits.', strCpuArch)
  else
    local strArtifactVersion = t:replace_template('${root_artifact_artifact}-${root_artifact_version}')
    local strArchive = t:replace_template(string.format('${install_base}/../%s-%s%s_%dbit.%s', strArtifactVersion, strDistId, strDistVersion, uiPlatformBits, strArchiveExtension))
    local strDiskPath = t:replace_template('${install_base}')
    local strArchiveMemberPrefix = strArtifactVersion

    tResult = Archive:pack_archive(strArchive, tFormat, atFilter, strDiskPath, strArchiveMemberPrefix)
  end
end

return tResult
