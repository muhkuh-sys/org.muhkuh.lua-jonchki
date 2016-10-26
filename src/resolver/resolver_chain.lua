--- The resolver chain class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local ResolverChain = class()



--- Initialize a new instance of the resolver chain.
-- @param strID The ID identifies the resolver.
function ResolverChain:_init(strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()
  -- The "luazip" module is used to depack the archives.
  self.zip = require 'zip'

  -- The system configuration.
  self.cSystemConfiguration = nil

  -- Create a new chain.
  self.atResolverChain = {}
  -- Mapping from the repository ID to the member of the resolver chain.
  self.atRepositoryByID = {}

  -- Create a new GA->V table.
  self.atGA_V = {}

  -- Get all available repository drivers.
  local atRepositoryDriverClasses = {}
  table.insert(atRepositoryDriverClasses, require 'repository_driver.filesystem')
  self.atRepositoryDriverClasses = atRepositoryDriverClasses
end



function ResolverChain:get_driver_class_by_type(strType)
  local tRepositoryDriverClass = nil

  -- Loop over all available repository driver classes.
  for _, tClass in pairs(self.atRepositoryDriverClasses) do
    -- Does the class support the type?
    if tClass.matches_type(strType)==true then
      tRepositoryDriverClass = tClass
      break
    end
  end

  return tRepositoryDriverClass
end



function ResolverChain:get_driver_by_id(strID)
  local tRepositoryDriver = self.atRepositoryByID[strID]

  return tRepositoryDriver
end



function ResolverChain:set_systemconfig(cSysCfg)
  self.cSystemConfiguration = cSysCfg
end



function ResolverChain:set_repositories(atRepositories)
  -- Create all repository drivers.
  local atResolverChain = {}
  local atMap = {}
  for _, tRepo in pairs(atRepositories) do
    -- Get the repository ID.
    local strID = tRepo.strID
    print(string.format('Creating driver for repository "%s".', strID))

    -- Does this ID already exist?
    if atMap[strID]~=nil then
      error(string.format('The ID "%s" is not unique!', strID))
    end

    -- Find the type.
    local tRepositoryDriverClass = self:get_driver_class_by_type(tRepo.strType)
    if tRepositoryDriverClass==nil then
      error(string.format('Could not find a repository driver for the type "%s".', tRepo.strType))
    end

    -- Create a driver instance.
    local tRepositoryDriver = tRepositoryDriverClass(strID)

    -- Setup the repository driver.
    tRepositoryDriver:configure(tRepo)

    -- Add the driver to the resolver chain.
    table.insert(atResolverChain, tRepositoryDriver)

    -- Create an ID -> repository mapping.
    atMap[strID] = tRepositoryDriver
  end

  -- Use the new resolver chain and the mapping.
  self.atResolverChain = atResolverChain
  self.atRepositoryByID = atMap
end



function ResolverChain:get_ga(strGroup, strArtifact)
  -- Combine the group and artifact.
  return string.format('%s/%s', strGroup, strArtifact)
end



function ResolverChain:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)
  -- Combine the group and artifact.
  local strGA = self:get_ga(strGroup, strArtifact)

  -- Is the GA already registered?
  local atGA = self.atGA_V[strGA]
  if atGA==nil then
    -- No, register GA now.
    atGA = {}
    self.atGA_V[strGA] = atGA
  end

  -- Is the version already registered?
  local strVersion = tVersion:get()
  local atV = atGA[strVersion]
  if atV==nil then
    -- No, register the version now.
    atV = {}
    atGA[strVersion] = atV
  end

  -- Does the source ID already exist?
  local fFound = false
  for _, strID in pairs(atV) do
    if strID==strSourceID then
      fFound = true
      break
    end
  end
  if fFound==false then
    -- Add the source ID.
    table.insert(atV, strSourceID)
  end
end



function ResolverChain:get_sources_by_gav(strGroup, strArtifact, tVersion)
  local atSources = nil

  -- Combine the group and artifact.
  local strGA = self:get_ga(strGroup, strArtifact)

  -- Is the GA already registered?
  local atGA = self.atGA_V[strGA]
  if atGA~=nil then
    -- Yes, now look for the version.
    local strVersion = tVersion:get()
    local atV = atGA[strVersion]
    if atV~=nil then
      atSources = atV
    end
  end

  return atSources
end



function ResolverChain:dump_ga_v_table()
  print 'GA_V('

  -- Loop over all GA pairs.
  for strGA, atGA in pairs(self.atGA_V) do
    -- Split the GA pair by the separating slash ('/').
    local aTmp = self.pl.stringx.split(strGA, '/')
    local strGroup = aTmp[1]
    local strArtifact = aTmp[2]
    print(string.format('  G=%s, A=%s', strGroup, strArtifact))

    -- Loop over all versions.
    for tVersion, atV in pairs(atGA) do
      print(string.format('    V=%s:', tVersion))

      -- Loop over all sources.
      print '      sources:'
      for _, strSrcID in pairs(atV) do
        print(string.format('        %s', strSrcID))
      end
    end
  end
  print ')'
end



function ResolverChain:get_available_versions(strGroup, strArtifact)
  local atDuplicateCheck = {}
  local atNewVersions = {}

  -- TODO: Check the GA->V table first.

  -- Loop over the repository list.
  for _, tRepository in pairs(self.atResolverChain) do
    -- Get the ID of the current repository.
    local strSourceID = tRepository:get_id()

    -- Get all available versions in this repository.
    local tResult, strError = tRepository:get_available_versions(strGroup, strArtifact)
    if tResult==nil then
      print(string.format('Error: failed to scan repository "%s": %s', strSourceID, strError))
    else
      -- Loop over all versions found in this repository.
      for _, tVersion in pairs(tResult) do
        -- Register the version in the GA->V table.
        self:add_to_ga_v(strGroup, strArtifact, tVersion, strSourceID)

        -- Is this version unique?
        local strVersion = tVersion:get()
        if atDuplicateCheck[strVersion]==nil then
          atDuplicateCheck[strVersion] = true
          table.insert(atNewVersions, tVersion)
        end
      end
    end
  end

  return atNewVersions
end



function ResolverChain:get_configuration(strGroup, strArtifact, tVersion)
  local tResult = nil
  local strMessage = ''

  -- Check if the GA->V table has already the sources.
  local atGAVSources = self:get_sources_by_gav(strGroup, strArtifact, tVersion)
  if atGAVSources==nil then
    -- No GA->V entries present.
    error('Continue here')
--[[
Loop over all repositories in the chain and try to get the GAV.
Do not store this in the GA->V table as it would look like this is a complete dataset over all available versions.
]]--
  end

  -- Loop over the sources and try to get the configuration.
  for _, strSourceID in pairs(atGAVSources) do
    -- Get the repository with this ID.
    local tDriver = self:get_driver_by_id(strSourceID)
    if tDriver~=nil then
      tResult, strMessage = tDriver:get_configuration(strGroup, strArtifact, tVersion)
      if tResult==nil then
        print(string.format('Failed to get %s/%s/%s from repository %s: %s', strGroup, strArtifact, tVersion:get(), strSourceID, strMessage))
      else
        break
      end
    end
  end

  if tResult==nil then
    strMessage = 'No valid configuration found in all available repositories.'
  end

  return tResult, strMessage
end



function ResolverChain:get_artifact(strGroup, strArtifact, tVersion)
  local tResult = nil
  local strMessage = ''

  -- Check if the GA->V table has already the sources.
  local atGAVSources = self:get_sources_by_gav(strGroup, strArtifact, tVersion)
  if atGAVSources==nil then
    -- No GA->V entries present.
    error('Continue here')
--[[
Loop over all repositories in the chain and try to get the GAV.
Do not store this in the GA->V table as it would look like this is a complete dataset over all available versions.
]]--
  end

  -- Get the depack folder from the system configuration.
  local strDepackFolder = self.cSystemConfiguration.tConfiguration.depack

  -- Loop over the sources and try to get the configuration.
  for _, strSourceID in pairs(atGAVSources) do
    -- Get the repository with this ID.
    local tDriver = self:get_driver_by_id(strSourceID)
    if tDriver~=nil then
      tResult, strMessage = tDriver:get_artifact(strGroup, strArtifact, tVersion, strDepackFolder)
      if tResult~=nil then
        break
      end
    end
  end

  return tResult, strMessage
end



function ResolverChain:install_artifacts(atArtifacts)
  local tResult
  local strError

  -- Collect all arguments for the install scripts in a table.
  local tInstallArgs = {
    install_base = self.cSystemConfiguration.tConfiguration.install_base,
    install_lua_path = self.cSystemConfiguration.tConfiguration.install_lua_path,
    install_lua_cpath = self.cSystemConfiguration.tConfiguration.install_lua_cpath,
    install_shared_objects = self.cSystemConfiguration.tConfiguration.install_shared_objects,
    install_doc = self.cSystemConfiguration.tConfiguration.install_doc
  }


  for _,tGAV in pairs(atArtifacts) do
    local strGroup = tGAV.strGroup
    local strArtifact = tGAV.strArtifact
    local tVersion = tGAV.tVersion
    local strVersion = tGAV.tVersion:get()

    local strGAV = string.format('G:%s,A:%s,V:%s', strGroup, strArtifact, strVersion)
    print(string.format('Installing %s', strGAV))

    -- Copy the artifact to the local depack folder.
    tResult, strError = self:get_artifact(strGroup, strArtifact, tVersion)
    if tResult==nil then
      error(string.format('Failed to install %s: %s', strGAV, strError))
    else
      local strArtifactPath = tResult

      -- Create a unique temporary path for the artifact.
      local strGroupPath = self.pl.stringx.replace(strGroup, '.', self.pl.path.sep)
      local strDepackPath = self.pl.path.join(self.cSystemConfiguration.tConfiguration.depack, strGroupPath, strArtifact, strVersion)

      -- Does the depack path already exist?
      if self.pl.path.exists(strDepackPath)==strDepackPath then
        error(string.format('The unique depack path %s already exists.', strDepackPath))
      else
        tResult, strError = self.pl.dir.makepath(strDepackPath)
        if tResult~=true then
          tResult = nil
          strError = string.format('Failed to create the depack path for %s: %s', strGAV, strError)
        else
          -- Open the artifact as a zip file.
          tResult, strError = self.zip.open(strArtifactPath)
          if tResult==nil then
            error(string.format('Failed to open %s as a ZIP archive: %s', strGAV, strError))
          end
          local tZip = tResult

          -- Loop over all files in the archive.
          for tAttr in tZip:files() do
            local strZipFileName = tAttr.filename
            print(string.format('  extracting "%s"', strZipFileName))
            -- Skip entries ending with a "/".
            if string.sub(strZipFileName, -1)~='/' then
              -- Get the directory part of the filename.
              local strZipFolder = self.pl.path.dirname(strZipFileName)
              local strOutputFolder = self.pl.path.join(strDepackPath, strZipFolder)

              -- The output folder must be below the depack folder.
              local strRel = self.pl.path.relpath(strDepackPath, strOutputFolder)
              if strRel~='' then
                if string.sub(strRel, 1, 2)~='..' then
                  error(string.format('Error depacking %s: the path "%s" leaves the depack folder!', strGAV, strZipFileName))
                end
                -- Create the output folder.
                tResult, strError = self.pl.dir.makepath(strOutputFolder)
              end

              -- Copy the file from the ZIP archive to the destination folder.
              local strOutputFile = self.pl.path.join(strDepackPath, strZipFileName)
              local tFileSrc = tZip:open(strZipFileName)
              if tFileSrc==nil then
                error(string.format('Error depacking %s: failed to extract "%s".', strGAV, strZipFileName))
              end
              local tFileDst = io.open(strOutputFile, 'wb')
              if tFileDst==nil then
                error(string.format('Error depacking %s: failed write to "%s".', strGAV, strOutputFile))
              end
              repeat
                local aucData = tFileSrc:read(4096)
                if aucData~=nil then
                  tFileDst:write(aucData)
                end
              until aucData==nil
              tFileSrc:close()
              tFileDst:close()
            end
          end

          tZip:close()

          -- Get the path to the installation script.
          local strInstallScriptFile = self.pl.path.join(strDepackPath, 'install.lua')
          -- Check if the file exists.
          if self.pl.path.exists(strInstallScriptFile)~=strInstallScriptFile then
            strError = string.format('Error installing %s: the install script "%s" does not exist.', strGAV, strInstallScriptFile)
            error(strError)
          end
          -- Check if the install script is a file.
          if self.pl.path.isfile(strInstallScriptFile)~=true then
            strError = string.format('Error installing %s: the install script "%s" is no file.', strGAV, strInstallScriptFile)
            error(strError)
          end
          -- Call the install script.
          local tResult, strError = self.pl.utils.readfile(strInstallScriptFile, false)
          if tResult==nil then
            strError = string.format('Error installing %s: failed to read the install script "%s": %s', strGAV, strInstallScriptFile, strError)
            error(strError)
          else
            -- Parse the install script.
            local strInstallScript = tResult
            tResult, strError = loadstring(strInstallScript, strInstallScriptFile)
            if tResult==nil then
              strError = string.format('Error installing %s: failed to parse the install script "%s": %s', strGAV, strInstallScriptFile, strError)
              error(strError)
            end
            local fnInstall = tResult

            -- Call the install script.
            tResult, strError = pcall(fnInstall, tInstallArgs)
            if tResult~=true then
              strError = string.format('Error installing %s: failed to run the install script "%s": %s', strGAV, strInstallScriptFile, tostring(strError))
              error(strError)
            end
            -- The second value is the return value.
            if strError~=true then
              strError = string.format('Error installing %s: the install script "%s" returned "%s".', strGAV, strInstallScriptFile, tostring(strError))
              error(strError)
            end
          end
        end
      end
    end
  end
end



return ResolverChain
