--- The installer class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Installer = class()


--- Initialize a new instance of the installer.
function Installer:_init(cLog, cReport, cSystemConfiguration, cRootArtifactConfiguration)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- The "archives" module is a wrapper for LUA modules and CLI tools to
  -- create and depack archives.
  local cArchives = require 'installer.archives'
  self.archives = cArchives(cLog)

  -- Create an empty list of post triggers.
  self.atActions = {}

  -- The install helper class.
  self.InstallHelper = require 'installer.install_helper'
  self.tCurrentInstallHelper = nil

  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[Installer] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )
  self.cReport = cReport

  -- The system configuration.
  self.cSystemConfiguration = cSystemConfiguration

  -- The configuration object for the root artifact.
  self.cRootArtifactConfiguration = cRootArtifactConfiguration

  self.ulDefaultLevel = 50
  local atDefaultLevels = {
    ['finalizer'] = 75,
    ['pack'] = 80,
    ['create_release_list'] = 90
  }
  self.atDefaultLevels = atDefaultLevels
  self.atDefaultActions = {
    {
      name = 'pack',
      code = [[
        local t = ...

        t:createPackageFile()
        t:createHashFile()
        local strArchivePath, strRealExtension = t:createArchive('${prj_root}/targets/${default_archive_name}')
        t:add_replacement('root_artifact_path', strArchivePath)
        t:add_replacement('root_artifact_extension_real', strRealExtension)

        return true
      ]],
      path = '${install_base}',
      level = atDefaultLevels['pack']
    },
    {
      name = 'create_release_list',
      code = [[
        local t = ...
        local tResult
        local tLog = t.tLog
        local pl = t.pl

        -- Does a define exist for the release list?
        local strReleaseListDefine = 'define_release_list_path'
        local strReleaseListPath = t:get_replacement(strReleaseListDefine)
        if strReleaseListPath==nil then
          tLog.info('Not creating a relelase list as the define "%s" is not set.', strReleaseListDefine)
          tResult = true

        else
          -- Create a release list with the root artifact.
          local atFiles = {}
          local atReleaseList = {
            repository = t:replace_template('${define_nup_repository}'),
            groupID = t:replace_template('${root_artifact_group}'),
            moduleID = t:replace_template('${root_artifact_module}'),
            artifactID = t:replace_template('${root_artifact_artifact}'),
            version = t:replace_template('${root_artifact_version}'),
            files = atFiles
          }

          table.insert(atFiles, {
            path = t:replace_template('${root_artifact_path}'),
            extension = t:replace_template('${root_artifact_extension_real}'),
            classifier = t:replace_template(
              '${platform_distribution_id}${conditional_platform_distribution_version_separator}' ..
              '${platform_distribution_version}_${platform_cpu_architecture}'
            )
          })
          -- Does a documentation exist?
          local strDocumentationPath = t:get_replacement('documentation_path')
          if strDocumentationPath~=nil then
            -- Get the extension of the documentation. Cut off any leading dot.
            local strDocumentationExtension = pl.path.extension(strDocumentationPath)
            if string.sub(strDocumentationExtension, 1, 1)=='.' then
              strDocumentationExtension = string.sub(strDocumentationExtension, 2)
            end

            -- Add the documentation to the release list.
            table.insert(atFiles, {
              path = strDocumentationPath,
              extension = strDocumentationExtension,
              classifier = ''
            })
          end

          -- Encode the release list as a JSON string.
          local strReleaseListJson = t.cjson.encode(atReleaseList)

          -- Write the release list to a file.
          local fWriteResult, strWriteError = pl.utils.writefile(strReleaseListPath, strReleaseListJson, false)
          if fWriteResult~=true then
            tLog.error(
              'Failed to write the release list to "%s": %s',
              strReleaseListPath,
              tostring(strWriteError)
            )
          else
            tResult = true
          end
        end

        return tResult
      ]],
      path = '${install_base}',
      level = atDefaultLevels['create_release_list']
    }
  }
end



function Installer:run_install_script(strInstallScriptFile, strDepackPath, strGMAV)
  local tResult

  -- Get the current install helper.
  local cInstallHelper = self.tCurrentInstallHelper

  -- Get the path to the installation script.
  self.tLog.info('Running the install script "%s".', strInstallScriptFile)
  -- Check if the file exists.
  if self.pl.path.exists(strInstallScriptFile)~=strInstallScriptFile then
    tResult = nil
    self.tLog.error('The install script "%s" does not exist.', strInstallScriptFile)
  else
    -- Check if the install script is a file.
    if self.pl.path.isfile(strInstallScriptFile)~=true then
      tResult = nil
      self.tLog.error('The install script "%s" is no file.', strInstallScriptFile)
    else
      -- Call the install script.
      local strError
      tResult, strError = self.pl.utils.readfile(strInstallScriptFile, false)
      if tResult==nil then
        tResult = nil
        self.tLog.error('Failed to read the install script "%s": %s', strInstallScriptFile, strError)
      else
        -- Parse the install script.
        local strInstallScript = tResult
        local loadstring = loadstring or load
        tResult, strError = loadstring(strInstallScript, strInstallScriptFile)
        if tResult==nil then
          tResult = nil
          self.tLog.error('Failed to parse the install script "%s": %s', strInstallScriptFile, strError)
        else
          local fnInstall = tResult

          -- Set the artifact's depack path as the current working folder.
          cInstallHelper:setCwd(strDepackPath)

          -- Set the current artifact identification for error messages.
          cInstallHelper:setId(strGMAV)

          -- Call the install script.
          tResult, strError = pcall(fnInstall, cInstallHelper)
          if tResult~=true then
            tResult = nil
            self.tLog.error('Failed to run the install script "%s": %s', strInstallScriptFile, tostring(strError))

          -- The second value is the return value.
          elseif strError~=true then
            tResult = nil
            self.tLog.error('The install script "%s" returned "%s".', strInstallScriptFile, tostring(strError))
          end
        end
      end
    end
  end

  return tResult
end



function Installer:install_artifacts(atArtifacts, cPlatform, fInstallBuildDependencies)
  local tResult = true
  local pl = self.pl
  local tLog = self.tLog

  -- Create the installation helper.
  local cInstallHelper = self.InstallHelper(self.cLog, fInstallBuildDependencies, self.atActions)

  -- Add replacement variables.
  local tConfiguration = self.cSystemConfiguration.tConfiguration
  local tInfo = self.cRootArtifactConfiguration.tInfo
  local atReplacements = {
    ['prj_root'] = tConfiguration.prj_root,
    ['prj_version_vcs'] = tConfiguration.prj_version_vcs,
    ['prj_version_vcs_long'] = tConfiguration.prj_version_vcs_long,

    ['build'] = tConfiguration.build,
    ['build_doc'] = tConfiguration.build_doc,

    ['install_base'] = tConfiguration.install_base,
    ['install_executables'] = tConfiguration.install_executables,
    ['install_shared_objects'] = tConfiguration.install_shared_objects,
    ['install_lua_path'] = tConfiguration.install_lua_path,
    ['install_lua_cpath'] = tConfiguration.install_lua_cpath,
    ['install_doc'] = tConfiguration.install_doc,
    ['install_dev'] = tConfiguration.install_dev,
    ['install_dev_include'] = tConfiguration.install_dev_include,
    ['install_dev_lib'] = tConfiguration.install_dev_lib,
    ['install_dev_cmake'] = tConfiguration.install_dev_cmake,

    ['platform_cpu_architecture'] = cPlatform:get_cpu_architecture(),
    ['platform_distribution_id'] = cPlatform:get_distribution_id(),
    ['platform_distribution_version'] = cPlatform:get_distribution_version(),
    ['platform_distribution_version_separator'] = '-',

    ['root_artifact_group'] = tInfo.strGroup,
    ['root_artifact_module'] = tInfo.strModule,
    ['root_artifact_artifact'] = tInfo.strArtifact,
    ['root_artifact_version'] = tInfo.tVersion:get(),
    ['root_artifact_vcs_id'] = tInfo.strVcsId,
    ['root_artifact_extension'] = tInfo.strExtension,
    ['root_artifact_license'] = tInfo.strLicense,
    ['root_artifact_author_name'] = tInfo.strAuthorName,
    ['root_artifact_author_url'] = tInfo.strAuthorUrl,
    ['root_artifact_description'] = tInfo.strDescription,

    ['report_path'] = self.cReport:getFileName()
  }
  for strKey, strValue in pairs(atReplacements) do
    if strValue~=nil then
      tResult = cInstallHelper:add_replacement(strKey, strValue)
      if tResult~=true then
        tLog.error('Failed to add the replacement variable "%s".', strKey)
        break
      end
    end
  end
  if tResult==true then
    -- Add all defines.
    local strDefinePrefix = 'define_'
    for strKey, strValue in pairs(tConfiguration) do
      if string.sub(strKey, 1, string.len(strDefinePrefix))==strDefinePrefix then
        tResult = cInstallHelper:add_replacement(strKey, strValue)
        if tResult~=true then
          tLog.error('Failed to add the replacement variable "%s".', strKey)
          break
        end
      end
    end
  end

  if tResult==true then
    -- Register all actions.
    for _, tAction in ipairs(self.cRootArtifactConfiguration.atActions) do
      -- Get the name.
      local strName = tAction.strName
      -- Get the level.
      local ulLevel = tAction.ulLevel
      if ulLevel==nil then
        -- Get the default level if the test has a name.
        if strName~=nil then
          ulLevel = self.atDefaultLevels[strName]
        end
        -- Assign the default level as the last fallback.
        if ulLevel==nil then
          ulLevel = self.ulDefaultLevel
        end
      end
      -- Get the code.
      local fnAction
      local strWorkingPath
      if tAction.strFile~=nil then
        -- Read the code from a file.

        -- Get the absolute path for the script.
        local strPath = cInstallHelper:replace_template(tAction.strFile)
        local strScriptAbs = pl.path.abspath(strPath)

        -- Check if the file exists.
        if pl.path.exists(strScriptAbs)~=strScriptAbs then
          tResult = nil
          tLog.error('The file for action script "%s" does not exist: %s', strName, strScriptAbs)
          break

        -- Check if the action script is a file.
        elseif pl.path.isfile(strScriptAbs)~=true then
          tResult = nil
          tLog.error('The path for action script "%s" is no file: %s', strName, strScriptAbs)
          break

        else
          -- Read the action script.
          local strActionScript, strFileError = pl.utils.readfile(strScriptAbs, false)
          if strActionScript==nil then
            tResult = nil
            tLog.error('Failed to read action script "%s" from file %s: %s', strName, strScriptAbs, strFileError)
            break

          else
            -- Parse the install script.
            local loadstring = loadstring or load
            local strParseError
            fnAction, strParseError = loadstring(strActionScript, string.format('action script %s', strName))
            if fnAction==nil then
              tResult = nil
              tLog.error('Failed to parse the action script "%s" from file %s: %s', strName, strScriptAbs, strParseError)
              break

            else
              -- Get the working path of the script. Use the "path" attribute. If it is not set, get the path component of the script.
              strWorkingPath = tAction.strPath
              if strWorkingPath==nil then
                strWorkingPath = pl.path.dirname(strScriptAbs)
              end
            end
          end
        end
      else

        -- Parse the install script.
        local loadstring = loadstring or load
        local strParseError
        fnAction, strParseError = loadstring(tAction.strCode, strScriptAbs)
        if fnAction==nil then
          tResult = nil
          tLog.error('Failed to parse the action script "%s" from embedded code: %s', strName, strParseError)
          break

        else
          -- Get the working path of the script. Use the "path" attribute. If it is not set, use the project root.
          strWorkingPath = tAction.strPath
          if strWorkingPath==nil then
            strWorkingPath = '${prj_root}'
          end
        end
      end

      cInstallHelper:register_action(strName, fnAction, cInstallHelper, strWorkingPath, ulLevel)
    end
  end

  if tResult==true then
    self.tCurrentInstallHelper = cInstallHelper

    for _,tAttr in pairs(atArtifacts) do
      local tInfo = tAttr.cArtifact.tInfo
      local strGroup = tInfo.strGroup
      local strModule = tInfo.strModule
      local strArtifact = tInfo.strArtifact
      local strVersion = tInfo.tVersion:get()
      local strArtifactPath = tAttr.strArtifactPath

      local strGMAV = string.format('%s-%s-%s-%s', strGroup, strModule, strArtifact, strVersion)
      tLog.info('Installing %s for target %s', strGMAV, tostring(cPlatform))

      -- Create a unique temporary path for the artifact.
      local strGroupPath = pl.stringx.replace(strGroup, '.', self.pl.path.sep)
      local strDepackPath = pl.path.join(self.cSystemConfiguration.tConfiguration.depack, strGroupPath, strModule, strArtifact, strVersion)

      -- Does the depack path already exist?
      if pl.path.exists(strDepackPath)==strDepackPath then
        tResult = nil
        tLog.error('The unique depack path %s already exists.', strDepackPath)
        break
      else
        local strError
        tResult, strError = pl.dir.makepath(strDepackPath)
        if tResult~=true then
          tResult = nil
          tLog.error('Failed to create the depack path for %s: %s', strGMAV, strError)
          break
        else
          -- Add the depack path and the version to the replacement list.
          local strVariableArtifactPath = string.format('artifact_path_%s.%s.%s', strGroup, strModule, strArtifact)
          tResult = cInstallHelper:add_replacement(strVariableArtifactPath, strArtifactPath)
          if tResult~=true then
            tLog.error('Failed to add the artifact path variable for %s.', strGMAV)
            break
          else
            local strVariableNameDepackPath = string.format('depack_path_%s.%s.%s', strGroup, strModule, strArtifact)
            tResult = cInstallHelper:add_replacement(strVariableNameDepackPath, strDepackPath)
            if tResult~=true then
              tLog.error('Failed to add the depack path variable for %s.', strGMAV)
              break
            else
              local strVariableNameVersion = string.format('version_%s.%s.%s', strGroup, strModule, strArtifact)
              tResult = cInstallHelper:add_replacement(strVariableNameVersion, strVersion)
              if tResult~=true then
                tLog.error('Failed to add the version variable for %s.', strGMAV)
                break
              else
                tResult = self.archives:depack_archive(strArtifactPath, strDepackPath)
                if tResult==nil then
                  tLog.error('Error depacking %s .', strGMAV)
                  break
                end

                local strInstallScriptFile = pl.path.join(strDepackPath, 'install.lua')
                tResult = self:run_install_script(strInstallScriptFile, strDepackPath, strGMAV)
                if tResult==nil then
                  tLog.error('Error installing %s .', strGMAV)
                  break
                end
              end
            end
          end
        end
      end
    end

    if tResult==true then
      -- Add all missing default actions.
      for _, tDefaultAction in ipairs(self.atDefaultActions) do
        local strName = tDefaultAction.name

        -- Does an action with this name already exist?
        local fFound = false
        for _, atLevel in pairs(self.atActions) do
          for _, tAction in ipairs(atLevel) do
            if tAction.name==strName then
              fFound = true
              break
            end
          end
          if fFound==true then
            break
          end
        end
        if fFound~=true then
          tLog.info('Using default action script for "%s".', strName)
          -- Parse the action code.
          local loadstring = loadstring or load
          local fnAction, strParseError = loadstring(tDefaultAction.code, string.format('default action script %s', strName))
          if fnAction==nil then
            tResult = nil
            tLog.error('Failed to parse the action script "%s" from embedded code: %s', strName, strParseError)
            break

          else
            -- Register the action.
            cInstallHelper:register_action(strName, fnAction, cInstallHelper, tDefaultAction.path, tDefaultAction.level)
          end
        end
      end

      -- Run all action scripts.
      self.tLog.debug('Running action scripts.')
      for uiLevel, atLevel in self.pl.tablex.sort(self.atActions) do
        self.tLog.debug('Running actions for level %d.', uiLevel)
        for _, tAction in ipairs(atLevel) do
          -- Set the artifact's depack path as the current working folder.
          local strPath = cInstallHelper:replace_template(tAction.path)
          cInstallHelper:setCwd(strPath)

          -- Set the current artifact identification for error messages.
          cInstallHelper:setId(tAction.name)

          local tPcallResult, tFnResult = pcall(tAction.fn, tAction.userdata, cInstallHelper)
          if tPcallResult==nil then
            tResult = nil
            tLog.error('Error running action script "%s": %s', tAction.name, tostring(tFnResult))
            break
          elseif tFnResult~=true then
            tResult = nil
            tLog.error('The action script "%s" returned %s', tAction.name, tostring(tFnResult))
            break
          end
        end

        if tResult~=true then
          break
        end
      end
    end
  end

  return tResult
end

return Installer
