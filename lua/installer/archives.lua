--- Create and depack archives.
-- @author cthelen@hilscher.com
-- @copyright 2017 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Archive = class()


--- Initialize a new instance of the "Archive" class.
function Archive:_init(cLogger)
  -- The "penlight" module is always useful.
  self.pl = require'pl.import_into'()

  self.tLogger = cLogger

  -- LFS is there with penlight.
  self.lfs = require 'lfs'

  -- Get a way to handle archives.
  self.archive = nil
  self:_get_archive_handler()
end



function Archive:_get_archive_handler()
  local fFoundHandler = false


  -- Prefer the LUA module archive.
  local tResult, archive = pcall(require, 'archive')
  if tResult==true then
    self.tLogger:info('Detected archive.')

    self.archive = archive
    self.depack_archive = self.depack_archive_archive
    self.pack_archive = self.pack_archive_archive

    fFoundHandler = true
  end

  if fFoundHandler~=true then
    -- Try to use the command line tools.
    -- The detection needs the popen function.
    if io.popen==nil then
      self.tLogger:info('Unable to detect the command line tools: io.popen is not available.')
    else
      -- Try to run "tar".
      local tFile, strError = io.popen('tar --version')
      if tFile==nil then
        self.tLogger:info('Failed to detect the command line tool "tar": %s', strError)
      else
        -- Read all data.
        local strData = tFile:read('*a')
        tFile:close()

        -- Try to run "7z".
        local tFile, strError = io.popen('7z')
        if tFile==nil then
          self.tLogger:info('Failed to detect the command line tool "7z": %s', strError)
        else
          -- Read all data.
          local strData = tFile:read('*a')
          tFile:close()

          self.tLogger:info('Detected command line tools.')

          self.depack_archive = self.depack_archive_cli
          -- self.pack_archive = self.pack_archive_cli

          fFoundHandler = true
        end
      end
    end
  end

  if fFoundHandler~=true then
    error('No archive handler found.')
  end
end



function Archive:depack_archive_archive(strArchivePath, strDepackPath)
  local tResult = true

  local tArc = self.archive.ArchiveRead()
  tArc:support_filter_all()
  tArc:support_format_all()

  local iExtractFlags = self.archive.ARCHIVE_EXTRACT_SECURE_SYMLINKS + self.archive.ARCHIVE_EXTRACT_SECURE_NODOTDOT + self.archive.ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS

  -- Keep the old working directory for later.
  local strOldWorkingDir = self.lfs.currentdir()
  -- Move to the extract folder.
  local tLfsResult, strError = self.lfs.chdir(strDepackPath)
  if tLfsResult~=true then
    self.tLogger:error('Failed to change to the depack path "%s": %s', strDepackPath, strError)
    tResult = nil
  else
    self.tLogger:debug('Extracting archive "%s".', strArchivePath)
    local r = tArc:open_filename(strArchivePath, 16384)
    if r~=0 then
      self.tLogger:error('Failed to open the archive "%s": %s', strArchivePath, tArc:error_string())
      tResult = nil
    else
      for tEntry in tArc:iter_header() do
        self.tLogger:debug('Processing entry "%s".', tEntry:pathname())

        local iResult = tArc:extract(tEntry, iExtractFlags)
        if iResult~=0 then
          self.tLogger:error('Failed to extract entry "%s" from archive "%s".', tEntry:pathname(), strArchivePath)
          tResult = nil
          break
        end
      end
    end

    -- Restore the old working directory.
    local tLfsResult, strError = self.lfs.chdir(strOldWorkingDir)
    if tLfsResult~=true then
      self.tLogger:error('Failed to restore the working directory "%s" after depacking: %s', strOldWorkingDir, strError)
      tResult = nil
    end
  end

  return tResult
end



-- This table assigns a depack command to a specific file suffix.
Archive.atCliFormats = {
    ['.tar.gz'] = { depack='tar --extract --directory %OUTPATH% --file %ARCHIVE% --gzip' },
    ['.tar.bz2'] = { depack='tar --extract --directory %OUTPATH% --file %ARCHIVE% --bzip2' },
    ['.tar.xz'] = { depack='tar --extract --directory %OUTPATH% --file %ARCHIVE% --xz' },
    ['.7z'] = { depack='7z x -o%OUTPATH% %ARCHIVE%' },
    ['.zip'] = { depack='7z x -o%OUTPATH% %ARCHIVE%' }
}



function Archive:_get_cli_attributes(strArchive)
  local tAttr = nil


  for strExt, atAttr in pairs(self.atCliFormats) do
    local sizExt = string.len(strExt)
    if strExt==string.sub(strArchive, -sizExt) then
      self.tLogger:debug('Found extension "%s".', strExt)
      tAttr = atAttr
      break
    end
  end

  return tAttr
end



function Archive:depack_archive_cli(strArchivePath, strDepackPath)
  local tResult = nil


  -- Get the extension of the archive.
  local tAttr = self:_get_cli_attributes(strArchivePath)
  if tAttr==nil then
    self.tLogger:error('Failed to guess the archive format from the file name "%s".', strArchivePath)
  else
    -- Process the template for the debug command.
    local atReplace = {ARCHIVE=strArchivePath, OUTPATH=strDepackPath}
    local strCmd = string.gsub(tAttr.depack, '%%(%w+)%%', atReplace)
    local tCliResult = os.execute(strCmd)
    if tCliResult==0 then
      tResult = true
    end
  end

  return tResult
end



function Archive:pack_archive_archive(strArchivePath, tFormat, atFilter, strSourcePath, strArchiveMemberPrefix)
  local tResult = true

  -- Create a new reader.
  local tReader = self.archive.ArchiveReadDisk()
  local tArcResult = 0
  if self.pl.path.is_windows~=true then
    tArcResult = tReader:set_standard_lookup()
  end
  if tArcResult~=0 then
    self.tLogger:error('Failed to set standard lookup: %s', tReader:error_string())
    tResult = nil
  else
    local uiBehavior = 0
    tArcResult = tReader:set_behavior(uiBehavior)
    if tArcResult~=0 then
      self.tLogger:error('Failed to set the standard behaviour: %s', tReader:error_string())
      tResult = nil
    else
      -- Create a new archive.
      local tArchive = archive.ArchiveWrite()

      tArcResult = tArchive:set_format(tFormat)
      if tArcResult~=0 then
        self.tLogger:error('Failed to set the archive format to ID %d: %s', tFormat, tArchive:error_string())
        tResult = nil
      else
        for _, tFilter in ipairs(atFilter) do
          tArcResult = tArchive:add_filter(tFilter)
          if tArcResult~=0 then
            self.tLogger:error('Failed to add filter with ID %d: %s', tFilter, tArchive:error_string())
            tResult = nil
            break
          end
        end

        if tResult==true then
          -- Remove any existing archive.
          if self.pl.path.exists(strArchivePath)==strArchivePath then
            local tFsResult, strError = self.pl.file.delete(strArchivePath)
            if tFsResult==nil then
              self.tLogger:error('Failed to delete the old archive "%s": %s', strArchivePath, strError)
              tResult = nil
            end
          end

          if tResult==true then
            tArcResult = tArchive:open_filename(strArchivePath)
            if tArcResult~=0 then
              self.tLogger:error('Failed to open the archive "%s": %s', strArchivePath, tArchive:error_string())
              tResult = nil
            else
              tArcResult = tReader:open(strSourcePath)
              if tArcResult~=0 then
                self.tLogger:error('Failed to open the path "%s": %s', strSourcePath, tReader:error_string())
                tResult = nil
              else
                self.tLogger:debug('Compressing "%s" to archive "%s"...', strSourcePath, strArchivePath)

                for tEntry in tReader:iter_header() do
                  -- Cut off the root path of the archive from the entry path.
                  local strPath = tEntry:pathname()
                  local strRelPath = self.pl.path.join(strArchiveMemberPrefix, self.pl.path.relpath(strPath, strSourcePath))
                  if strRelPath~='' then
                    tEntry:set_pathname(strRelPath)

                    self.tLogger:debug('  %s', strRelPath)

                    tArcResult = tArchive:write_header(tEntry)
                    if tArcResult~=0 then
                      self.tLogger:error('Failed to write the header for archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
                      tResult = nil
                      break
                    else
                      for strData in tReader:iter_data(16384) do
                        tArcResult = tArchive:write_data(strData)
                        if tArcResult~=0 then
                          self.tLogger:error('Failed to write a chunk of data to archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
                          tResult = nil
                          break
                        end
                      end
                      if tArcResult~=0 then
                        break
                      else
                        tArcResult = tArchive:finish_entry()
                        if tArcResult~=0 then
                          self.tLogger:error('Failed to finish archive member "%s": %s', tEntry:pathname(), tArchive:error_string())
                          tResult = nil
                          break
                        elseif tReader:can_descend()~=0 then
                          tArcResult = tReader:descend()
                          if tArcResult~=0 then
                            self.tLogger:error('Failed to descend on path "%s": %s', tEntry:pathname(), tReader:error_string())
                            tResult = nil
                            break
                          end
                        end
                      end
                    end
                  end
                end

                tArcResult = tReader:close()
                if tArcResult~=0 then
                  self.tLogger:error('Failed to close the reader: %s', tReader:error_string())
                  tResult = nil
                end
              end

              tArcResult = tArchive:close()
              if tArcResult~=0 then
                self.tLogger:error('Failed to close the archive "%s": %s', strArchive, tArchive:error_string())
                tResult = nil
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



return Archive
