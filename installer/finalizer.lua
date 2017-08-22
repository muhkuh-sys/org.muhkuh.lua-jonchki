local t = ...
local strDistId, strDistVersion, strCpuArch = t:get_platform()
local cLogger = t.cLogger

-- Copy all jonchki scripts.
local atScripts = {
  ['../jonchki.lua']                                  = '${install_base}/',
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


local tResult = true
local archive = require 'archive'
local pl = require'pl.import_into'()

local strArtifact = string.format('jonchki_%s%s_%s', strDistId, strDistVersion, strCpuArch)
local strDiskPath = t:replace_template('${install_base}')
local strArchiveMemberPrefix = 'jonchki'

local tReader = archive.ArchiveReadDisk()
local tArcResult = tReader:set_standard_lookup()
if tArcResult~=0 then
  cLogger:error('Failed to set standard lookup: %s', tReader:error_string())
  tResult = nil
end

local uiBehavior = 0
tArcResult = tReader:set_behavior(uiBehavior)
if tArcResult~=0 then
  cLogger:error('Failed to set the standard behaviour: %s', tReader:error_string())
  tResult = nil
end

-- Create a new archive.
local tArchive = archive.ArchiveWrite()

-- Create a ZIP archive for Windows platforms. Build a "tar.gz" for Linux.
local strArchiveExtension
if strDistId=='windows' then
  strArchiveExtension = 'zip'

  tArcResult = tArchive:set_format_zip()
  if tArcResult~=0 then
    cLogger:error('Failed to set the archive format to ZIP: %s', tArchive:error_string())
    tResult = nil
  end
else
  strArchiveExtension = 'tar.gz'

  tArcResult = tArchive:set_format_gnutar()
  if tArcResult~=0 then
    cLogger:error('Failed to set the archive format to GNU TAR: %s', tArchive:error_string())
    tResult = nil
  else
    tArcResult = tArchive:add_filter_gzip()
    if tArcResult~=0 then
      cLogger:error('Failed to add GZIP filter: %s', tArchive:error_string())
      tResult = nil
    end
  end
end

if tResult==true then
  -- Create the full path to the archive.
  local strArchive = t:replace_template(string.format('${install_base}/../%s.%s', strArtifact, strArchiveExtension))

  -- Remove any existing archive.
  if pl.path.exists(strArchive)==strArchive then
    pl.file.delete(strArchive)
  end

  tArcResult = tArchive:open_filename(strArchive)
  if tArcResult~=0 then
    cLogger:error('Failed to open the archive "%s": %s', strArchive, tArchive:error_string())
    tResult = nil
  else
    tArcResult = tReader:open(strDiskPath)
    if tArcResult~=0 then
      cLogger:error('Failed to open the path "%s": %s', strDiskPath, tReader:error_string())
      tResult = nil
    else
      cLogger:debug('Compressing "%s" to archive "%s"...', strDiskPath, strArchive)

      for tEntry in tReader:iter_header() do
        -- Cut off the root path of the archive from the entry path.
        local strPath = tEntry:pathname()
        local strRelPath = pl.path.join(strArchiveMemberPrefix, pl.path.relpath(strPath, strDiskPath))
        if strRelPath~='' then
          tEntry:set_pathname(strRelPath)

          cLogger:debug('  %s', strRelPath)

          tArcResult = tArchive:write_header(tEntry)
          if tArcResult~=0 then
            cLogger:error('Failed to write the header for archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
            tResult = nil
            break
          else
            for strData in tReader:iter_data(16384) do
              tArcResult = tArchive:write_data(strData)
              if tArcResult~=0 then
                cLogger:error('Failed to write a chunk of data to archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
                tResult = nil
                break
              end
            end
            if tArcResult~=0 then
              break
            else
              tArcResult = tArchive:finish_entry()
              if tArcResult~=0 then
                cLogger:error('Failed to finish archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
                tResult = nil
                break
              elseif tReader:can_descend()~=0 then
                tArcResult = tReader:descend()
                if tArcResult~=0 then
                  cLogger:error('Failed to descend on path "%s": %s', tEntry:pathname(), tReader:error_string())
                  tResult = nil
                  break
                end
              end
            end
          end
        end
      end
    end

    tArcResult = tArchive:close()
    if tArcResult~=0 then
      cLogger:error('Failed to close the archive "%s": %s', strArchive, tArchive:error_string())
      tResult = nil
    end
    tArcResult = tReader:close()
    if tArcResult~=0 then
      cLogger:error('Failed to close the reader: %s', tReader:error_string())
      tResult = nil
    end
  end
end

return tResult
