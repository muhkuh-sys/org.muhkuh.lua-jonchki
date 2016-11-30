--- The install helper class.
-- It is passed as a helper to the installation script of all packages.
-- It provides comfortable routines to copy files to the destination paths.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local InstallHelper = class()


--- Initialize a new instance of the install class.
-- @param strID The ID identifies the resolver.
function InstallHelper:_init(cLogger, cSystemConfiguration, strTargetId, fInstallDev)
  self.cLogger = cLogger

  -- Get the installation paths from the system configuration.
  local atPaths = {}
  atPaths.install_base = cSystemConfiguration.tConfiguration.install_base
  atPaths.install_executables = cSystemConfiguration.tConfiguration.install_executables
  atPaths.install_shared_objects = cSystemConfiguration.tConfiguration.install_shared_objects
  atPaths.install_lua_path = cSystemConfiguration.tConfiguration.install_lua_path
  atPaths.install_lua_cpath = cSystemConfiguration.tConfiguration.install_lua_cpath
  atPaths.install_doc = cSystemConfiguration.tConfiguration.install_doc
  atPaths.install_dev = cSystemConfiguration.tConfiguration.install_dev
  atPaths.install_dev_include = cSystemConfiguration.tConfiguration.install_dev_include
  atPaths.install_dev_lib = cSystemConfiguration.tConfiguration.install_dev_lib
  atPaths.install_dev_cmake = cSystemConfiguration.tConfiguration.install_dev_cmake
  self.atPaths = atPaths

  -- Copy the target ID.
  self.strTargetId = strTargetId

  -- Copy the flag for installation of development components.
  self.fInstallDev = fInstallDev

  -- The "penlight" module is used for various helpers.
  self.pl = require'pl.import_into'()

  -- This is the list of installed files for the complete installation procedure (i.e. over all packages).
  self.atInstalledFiles = {}

  -- This is an identifier string which can be used in error messages.
  -- It is set with the "setId" method. 
  self.strGMAV = ''

  -- The current working folder is the source path if the installation. Here the artifact ZIP is depacked.
  self.strCwd = ''
end



function InstallHelper:setCwd(strCwd)
  -- Set the current working directory.
  self.strCwd = strCwd
  self.cLogger:debug('Using "%s" as the current working folder.', strCwd)
end



function InstallHelper:setId(strGMAV)
  -- Update the identifier.
  self.strGMAV = strGMAV
end



function InstallHelper:get_platform()
  return self.strTargetId
end



function InstallHelper:install_dev(tSrc, strDst)
  if self.fInstallDev==true then
    self:install(tSrc, strDst)
  else
    self.cLogger:info('Not installing debug component "%s".', tostring(tSrc))
  end
end



function InstallHelper:install(tSrc, strDst)
  -- The first argument must be an "Install" class.
  if not(type(self)=='table' and type(self.is_a)=='function' and self:is_a(InstallHelper)==true) then
    self.cLogger:debug('Wrong self argument for the "install" method!')
    self.cLogger:debug('type(self) = "%s".', type(self))
    self.cLogger:debug('type(self.is_a) = "%s"', type(self.is_a))
    self.cLogger:debug('self:is_a(InstallHelper) = %s', tostring(self:is_a(InstallHelper)))
    error('The "install" method was called without a proper "self" argument. Use "t:install(source, destination)" to call the function.')
  end

  -- The second argument must be either a list of strings or a string.
  local astrSrc = nil
  local strSrcType = type(tSrc)
  if strSrcType=='string' then
    astrSrc = { tSrc }
  elseif strSrcType=='table' then
    astrSrc = tSrc
  else
    error(string.format('The "install" method was called with an invalid "tSrc" argument. It must be either a string or a table.'))
  end
  -- Loop over all elements and check their type.
  local astrErrors = {}
  for uiCnt, tValue in pairs(astrSrc) do
    local strType = type(tValue)
    if strType~='string' then
      table.insert(astrErrors, tostring(uiCnt))
    end
  end
  if #astrErrors~=0 then
    error(string.format('The "install" method was called with an invalid "tSrc" argument. The table contains non-string elements at the following indices: %s', table.concat(astrErrors, ', ')))
  end

  -- The third argument must be a string.
  if type(strDst)~='string' then
    error(string.format('The "install" method was called with an invalid "strDst" argument. It must be a string.'))
  end

  -- Replace the ${} strings.
  local atReplacements = {}
  for strKey, strPath in pairs(self.atPaths) do
    atReplacements[strKey] = strPath
  end
  local strDst = string.gsub(strDst, '%${([a-zA-Z0-9_]+)}', atReplacements)

  -- The destination is treated as a directory...
  --   if it ends with a slash or
  --   if the source is a list with more than one element.
  local fDstIsDir = nil
  if string.sub(strDst, -1)=='/' then
    fDstIsDir = true
  elseif #astrSrc>1 then
    fDstIsDir = true
  else
    fDstIsDir = false
  end

  -- Get the directory part of the destination.
  local strDstDirname = nil
  local strDstFilename = nil
  if fDstIsDir==true then
    strDstDirname = strDst
  else
    strDstDirname, strDstFilename = self.pl.path.splitpath(strDst)
  end

  -- Loop over all elements in the source list.
  for _, strSrc in pairs(astrSrc) do
    self.cLogger:info('Installing "%s"...', strSrc)
    -- Get the absolute path for the current source.
    local strSrcAbs = self.pl.path.abspath(strSrc, self.strCwd)

    -- Does the source exist?
    if self.pl.path.exists(strSrcAbs)~=strSrcAbs then
      error(string.format('The source path "%s" does not exist.', strSrcAbs))
    end

    -- Is the source a folder or a file.
    local fIsDir = self.pl.path.isdir(strSrcAbs)
    local fIsFile = self.pl.path.isfile(strSrcAbs)
    if (fIsDir==true) and (fIsFile==true) then
      error(string.format('"%s" is both a file and a directory.', strSrcAbs))
    elseif (fIsDir==false) and (fIsFile==false) then
      error(string.format('"%s" is neither a file nor a directory.', strSrcAbs))
    end

    if fIsFile==true then
      -- Copy one single file.

      -- Get the filename of the source without the directory part.
      local strSrcFilename = self.pl.path.basename(strSrcAbs)

      -- Get the destination path.
      local strDstPath = nil
      if fDstIsDir==true then
        strDstPath = self.pl.path.join(strDstDirname, strSrcFilename)
      else
        strDstPath = self.pl.path.join(strDstDirname, strDstFilename)
      end

      -- FIXME: check if the path is below the install base folder.

      -- Was this file already installed?
      local strPackage = self.atInstalledFiles[strDstPath]
      if strPackage~=nil then
        -- Yes -> refuse to overwrite it.
        error(string.format('The file "%s" was already installed by the artifact %s.', strDstPath, strPackage))
      end
      self.atInstalledFiles[strDstPath] = self.strGMAV

      -- Create the output folder.
      local tResult, strError = self.pl.dir.makepath(strDstDirname)
      if tResult~=true then
        error(string.format('Failed to create the output folder "%s": %s', strDstDirname, strError))
      end

      -- Copy the file.
      local tResult, strError = self:copy(strSrcAbs, strDstPath)
      if tResult~=true then
        error(string.format('Failed to copy "%s" to "%s": %s', strSrcAbs, strDstPath, strError))
      end
    else
      -- Copy a complete directory.

      -- Reconsider the destination path. If the filename is set, add it to the directors.
      if strDstFilename~=nil then
        strDstDirname = self.pl.path.join(strDstDirname, strDstFilename)
        strDstFilename = nil
      end

      for strRoot, astrDirs, astrFiles in self.pl.dir.walk(strSrcAbs, false, true) do
        -- Get the relative path from the depack folder to the current root.
        local strRootRel = self.pl.path.relpath(strRoot, strSrcAbs)

        -- Create the root folder. This is important for empty folders.
        local strDstDir = self.pl.path.join(strDstDirname, strRootRel)
        local tResult, strError = self.pl.dir.makepath(strDstDir)
        if tResult~=true then
          error(string.format('Failed to create the output folder "%s": %s', strDstDir, strError))
        end

        -- Loop over all files and copy them.
        for _, strFile in pairs(astrFiles) do
          local strSrcPath = self.pl.path.join(strRoot, strFile)
          local strDstPath = self.pl.path.join(strDstDir, strFile)

          -- FIXME: check if the path is below the install base folder.

          -- Was this file already installed?
          local strPackage = self.atInstalledFiles[strDstPath]
          if strPackage~=nil then
            -- Yes -> refuse to overwrite it.
            error(string.format('The file "%s" was already installed by the artifact %s.', strDstPath, strPackage))
          end
          self.atInstalledFiles[strDstPath] = self.strGMAV

          -- Copy the file.
          local tResult, strError = self:copy(strSrcPath, strDstPath)
          if tResult~=true then
            error(string.format('Failed to copy "%s" to "%s": %s', strSrcPath, strDstPath, strError))
          end
        end
      end
    end
  end
end



function InstallHelper:copy(strSrc, strDst)
  local tResult
  local strError

  self.cLogger:debug('copy "%s" -> "%s"', strSrc, strDst)

  local tSrc
  local tDst
  tSrc, strError = io.open(strSrc, 'rb')
  if tSrc~=nil then
    tDst, strError = io.open(strDst, 'wb')
    if tDst~=nil then
      repeat
        local strData = tSrc:read(4096)
        if strData~=nil then
          tDst:write(strData)
        end
      until strData==nil

      tSrc:close()
      tDst:close()

      tResult = true
    end
  end

  return tResult, strError
end



return InstallHelper
