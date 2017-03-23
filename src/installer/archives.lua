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

  -- Get a way to handle archives.
  self:_get_archive_handler()
end



function Archive:_get_archive_handler()
  local fFoundHandler = false


  -- Prefer the LUA module archive.
  local tResult, curl = pcall(require, 'archive')
  if tResult==true then
    self.tLogger:info('Detected archive.')
    
    self.depack_archive = self.depack_archive_archive
    -- self.pack_archive = self.pack_archive_archive
    
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



return Archive
