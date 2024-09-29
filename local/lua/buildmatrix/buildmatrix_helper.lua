local class = require 'pl.class'
local _M = class()


function _M:_init(cLog, astrBuilds, strProjectRoot, strLuaInterpreter, strJonchkiScript)
  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[BuildMatrix] ', cLog)
  self.tLogSystem = require "log".new(
    "trace",
    tLogWriter,
    require "log.formatter.format".new()
  )
  self.tLog = nil

--  self.__fStopAfterFirstError = true

  self.m_astrBuilds = astrBuilds

  self.atActions = {}

  -- Run all "build_..." actions at level 50.
  self.default_level_for_builds = 50

  local atRootEnv = {
    ['prj_root'] = strProjectRoot,
    ['jonchki_mode'] = 'install-dependencies',
    ['jonchki_log_level'] = 'debug',
    ['jonchki_system_configuration'] = '${prj_root}/jonchki/jonchkisys.cfg',
    ['jonchki_project_configuration'] = '${prj_root}/jonchki/jonchkicfg.xml',
    ['jonchki_command'] = table.concat({
      '${jonchki_lua_interpreter} ${jonchki_lua_script}',
      '${jonchki_mode}',
      '-v ${jonchki_log_level}',
      '--project-root ${prj_root}',
      '--no-console-log',
      '--logfile ${jonchki_logfile}',
      '--syscfg ${jonchki_system_configuration}',
      '--prjcfg ${jonchki_project_configuration}',
      '--dependency-log ${jonchki_dependency_log}',
      '--distribution-id ${platform_distribution_id}',
      '--distribution-version ${platform_distribution_version}',
      '--cpu-architecture ${platform_cpu_architecture}',
      '${define_all}',
      '${jonchki_artifact_configuration}'
    }, ' '),
    ['jonchki_lua_interpreter'] = strLuaInterpreter,
    ['jonchki_lua_script'] = strJonchkiScript,
    ['working_folder'] = table.concat({
      '${prj_root}',
      'targets',
      '${artifact_id}',
      '${platform_distribution_id}_${platform_distribution_version}_${platform_cpu_architecture}'
    }, '/'),
    ['jonchki_dependency_log'] = '${prj_root}/dependency-log-${artifact_id}.xml',
    ['jonchki_logfile'] = '${working_folder}/jonchki.log'
  }
  self.__atEnvironmentRoot = {
    id = 'root',
    env = atRootEnv,
    builds = {}
  }

  self.atArtifacts = {}
  self.__atArtifactLookup = {}
end



--- Set a replacement key to a value.
-- A new key can be created or the value of an existing key can be replaced.
function _M:setVar(atEnvironment, tKey, tValue)
  local tLog = self.tLogSystem
  atEnvironment = atEnvironment or self.__atEnvironmentRoot

  local atEnv = atEnvironment.env
  if atEnv==nil then
    local strMsg = string.format(
      'The environment "%s" has no "env" attribute.',
      atEnvironment.id
    )
    tLog.error(strMsg)
    error(strMsg)
  end

  local strKey = tostring(tKey)
  local strValue = tostring(tValue)

  local strOldValue = atEnv[strKey]
  if strOldValue==nil then
    tLog.debug('Setting new key "%s" to "%s" in environment "%s".', strKey, strValue, atEnvironment.id)
  else
    tLog.debug(
      'Overwriting key "%s" from "%s" to "%s" in environment "%s".',
      strKey,
      strOldValue,
      strValue,
      atEnvironment.id
    )
  end
  atEnv[strKey] = strValue
end



function _M:newArtifact(strEnvironmentID, atEnvironmentBase)
  atEnvironmentBase = atEnvironmentBase or self.__atEnvironmentRoot
  local tLog = self.tLogSystem

  tLog.debug('Creating the new environment "%s" based on "%s".', strEnvironmentID, atEnvironmentBase.id)

  local atEnv = atEnvironmentBase.env
  if atEnv==nil then
    local strMsg = string.format(
      'The environment "%s" has no "env" attribute.',
      atEnvironmentBase.id
    )
    tLog.error(strMsg)
    error(strMsg)
  end

  local atEnvCopy = {}
  local atEnvironmentCopy = {
    id = strEnvironmentID,
    env = atEnvCopy,
    builds = {}
  }

  for strKey, strValue in pairs(atEnv) do
    atEnvCopy[strKey] = strValue
  end

  return atEnvironmentCopy
end



function _M:createArtifacts(astrArtifactIDs)
  local tLog = self.tLogSystem

  local atArtifacts = self.atArtifacts
  local atArtifactLookup = self.__atArtifactLookup

  for _, strArtifactID in ipairs(astrArtifactIDs) do
    if atArtifactLookup[strArtifactID]~=nil then
      local strMsg = string.format(
        'The artifact with the ID "%s" already exists.',
         strArtifactID
      )
      tLog.error(strMsg)
      error(strMsg)
    end

    local atEnvironment = self:newArtifact(strArtifactID)
    self:setVar(atEnvironment, 'artifact_id', strArtifactID)
    table.insert(atArtifacts, atEnvironment)
    atArtifactLookup[strArtifactID] = true
  end
end



function _M:addBuildToAllArtifacts(atVariables, fIsActivatedByDefault)
  local tLog = self.tLogSystem
  if fIsActivatedByDefault==nil then
    fIsActivatedByDefault = true
  end

  for _, tArtifact in ipairs(self.atArtifacts) do
    -- Create a copy of the artifact and the variables.
    local atCopy = {}
    for strKey, strValue in pairs(tArtifact.env) do
      atCopy[strKey] = strValue
    end
    for strKey, strValue in pairs(atVariables) do
      atCopy[strKey] = strValue
    end

    -- Try to guess a build ID.
    local strBuildID = string.format(
      '%s_%s_%s_%s',
      tArtifact.id,
      tostring(atCopy.platform_distribution_id),
      tostring(atCopy.platform_distribution_version),
      tostring(atCopy.platform_cpu_architecture)
    )

    tLog.debug('Adding build "%s" to artifact "%s".', strBuildID, tArtifact.id)
    table.insert(tArtifact.builds, {
      id = strBuildID,
      active_default = fIsActivatedByDefault,
      active = fIsActivatedByDefault,
      env = atCopy,
      cmd = nil,
      working_folder = nil,
      logfile = nil,
      result = nil,
      files = {}
    })
  end
end



function _M:registerAction(strName, fnAction, tUserData, strWorkingPath, uiLevel)
  local tLog = self.tLogSystem

  -- The first argument must be an "Install" class.
  if not(type(self)=='table' and type(self.is_a)=='function' and self:is_a(_M)==true) then
    tLog.debug('Wrong self argument for the "install" method!')
    tLog.debug('type(self) = "%s".', type(self))
    tLog.debug('type(self.is_a) = "%s"', type(self.is_a))
    tLog.debug('self:is_a(InstallHelper) = %s', tostring(self:is_a(_M)))
    error('The "registerAction" method was called without a proper "self" argument. '..
          'Use "t:registerAction(name, function, userdata, working_path, level)" to call the function.')
  end

    -- The second argument must be a string.
    if type(strName)~='string' then
      error('The second argument of the "registerAction" method must be a string.')
    end

  -- The 3rd argument must be a function.
  if type(fnAction)~='function' then
    error('The 3rd argument of the "registerAction" method must be a function.')
  end

  -- The 5th argument must be a string.
  if type(strWorkingPath)~='string' and type(strWorkingPath)~='nil' then
    error('The 5th argument of the "registerAction" method must be a string or nil.')
  end

  -- The 6th argument must be a number.
  if type(uiLevel)~='number' then
    error('The 6th argument of the "registerAction" method must be a number.')
  end

  -- Does the level already exist?
  local atLevel = self.atActions[uiLevel]
  if atLevel==nil then
    -- No, the level does not yet exist. Create it now.
    atLevel = {}
    self.atActions[uiLevel] = atLevel
  end

  -- Append the new action to the level.
  local tAction = {
    name = strName,
    fn = fnAction,
    userdata = tUserData,
    path = strWorkingPath
  }
  table.insert(atLevel, tAction)
end



function _M.actionBuild(tBuildHelper, tBuild)
  local tLog = tBuildHelper.tLog
  local tResult

  local strBuildID = tBuild.id
  tLog.info('Building "%s"...', strBuildID)
  local strCmd = tBuild.cmd
  tLog.debug('Build command for "%s" is: %s', strBuildID, strCmd)

  -- Run the command.
  local compat = require 'pl.compat'
  local fBuildCmdResult, ulBuildCmdStatus = compat.execute(strCmd)
  tBuild.result = fBuildCmdResult
  if fBuildCmdResult then
    tBuild.result = true
    tLog.info('Successfully built %s.', strBuildID)
    tResult = true

  else
    tLog.error(
      'Failed to build %s, status: %s, logfile: %s',
      strBuildID,
      tostring(ulBuildCmdStatus),
      tBuild.logfile
    )
  end

  return tResult
end



function _M.actionGenerateNupFiles(tBuildHelper)
  local tLog = tBuildHelper.tLog
  local tResult = true

  local cjson = require 'cjson.safe'
  local path = require 'pl.path'
  local utils = require 'pl.utils'

  local atAllReleases = {}

  -- Loop over all artifacts.
  for _, tArtifact in ipairs(tBuildHelper.atArtifacts) do
    -- Check several things in one go:
    -- 1) Does the artifact have any default builds?
    -- 2) Check if the artifact is completely build.
    --    "Completely" means that all builds marked as "default" must be successful.
    local fHasDefaultBuilds = false
    local fIsComplete = true
    for _, tBuild in ipairs(tArtifact.builds) do
      -- Look for one or more "true" values.
      fHasDefaultBuilds = fHasDefaultBuilds or tBuild.active_default

      if tBuild.active_default==true then
        fIsComplete = fIsComplete and tBuild.active and tBuild.result
      end
    end
    if tResult==true then
      if fHasDefaultBuilds==true and fIsComplete==true then
        tLog.debug('Generating NUP for complete artifact "%s".', tArtifact.id)

        -- Collect the release lists of all builds.
        cjson.decode_array_with_array_mt(true)
        for _, tBuild in ipairs(tArtifact.builds) do
          local strBuildID = tBuild.id
          -- Process only active builds.
          if tBuild.active~=true then
            tLog.debug('Not adding inactive build %s.', strBuildID)

          else

            -- Does the build have a define for the release list path?
            local strReleaseListPath = tBuild.env['define_release_list_path']
            if strReleaseListPath==nil then
              tLog.error('Build "%s" has no define for the release list path.', strBuildID)
              tResult = nil
              break

            else
              -- Try to read the release list.
              local strReleaseListJson, strReleaseListReadError = utils.readfile(strReleaseListPath, false)
              if strReleaseListJson==nil then
                tLog.error(
                  'Failed to read the release list for build "%s" from "%s": %s',
                  strBuildID,
                  strReleaseListPath,
                  strReleaseListReadError
                )
                tResult = nil
                break
              else
                -- Decode the release list.
                local tReleaseList, strJsonDecodeError = cjson.decode(strReleaseListJson)
                if tReleaseList==nil then
                  tLog.error(
                    'Failed to decode the release list "%s" as JSON: %s',
                    strReleaseListPath,
                    strJsonDecodeError
                  )
                  tResult = nil
                  break
                else
                  -- Check for the NUP repository and get the GAV coordinates with the project root from the
                  -- environment.
                  local strNupRepository = tBuild.env.define_nup_repository
                  local strGroupID = tReleaseList.groupID
                  local strArtifactID = tReleaseList.artifactID
                  local strVersion = tReleaseList.version
                  local strPrjRoot = tBuild.env.prj_root
                  if strNupRepository==nil then
                    tLog.error('Build %s has no define for the NUP repository.', strBuildID)
                    tResult = nil
                    break

                  elseif strGroupID==nil then
                    tLog.error('The release list for build %s has no define for the group ID.', strBuildID)
                    tResult = nil
                    break

                  elseif strArtifactID==nil then
                    tLog.error('The release list for build %s has no define for the artifact ID.', strBuildID)
                    tResult = nil
                    break

                  elseif strVersion==nil then
                    tLog.error('The release list for build %s has no define for the version.', strBuildID)
                    tResult = nil
                    break

                  elseif strPrjRoot==nil then
                    tLog.error('Build %s has no define for the project root.', strBuildID)
                    tResult = nil
                    break

                  else
                    -- Look for a matching section in the releases.
                    local tMatchingRelease
                    for _, tRelease in ipairs(atAllReleases) do
                      if(
                        tRelease.repository==strNupRepository and
                        tRelease.groupID==strGroupID and
                        tRelease.artifactID==strArtifactID and
                        tRelease.version==strVersion and
                        tRelease.prjRoot==strPrjRoot
                      ) then
                        tMatchingRelease = tRelease
                        break
                      end
                    end
                    -- Create a new section if none exists yet.
                    if tMatchingRelease==nil then
                      tMatchingRelease = {
                        repository = strNupRepository,
                        groupID = strGroupID,
                        artifactID = strArtifactID,
                        version = strVersion,
                        prjRoot = strPrjRoot,
                        files = {}
                      }
                      table.insert(atAllReleases, tMatchingRelease)
                    end

                    -- Copy all elements of the release list to the big collection.
                    local atFiles = tMatchingRelease.files
                    for _, tReleaseEntry in ipairs(tReleaseList.files) do
                      table.insert(atFiles, tReleaseEntry)
                    end

                    tLog.debug('Added %d files from build %s.', #tReleaseList.files, strBuildID)
                  end
                end
              end
            end
          end
        end

        if tResult==true then
          -- Loop over all releases and write them to separate NUP files.
          for _, tRelease in ipairs(atAllReleases) do
            -- Construct the output folder of the NUP file.
            local strNupOutputFolder = string.format(
              '%s/targets',
              tRelease.prjRoot
            )

            -- Construct the complete path for the NUP file.
            local strNupPath = string.format(
              '%s/%s-%s.nup',
              strNupOutputFolder,
              tRelease.artifactID,
              tRelease.version
            )

            -- Create a copy of the file list where all paths are relative to the NUP file.
            local atFilesRelative = {}
            for _, tFile in ipairs(tRelease.files) do
              table.insert(atFilesRelative, {
                path = path.relpath(tFile.path, strNupOutputFolder),
                extension = tFile.extension,
                classifier = tFile.classifier
              })
            end

            local tNup = {
              ['$schema'] = 'https://api.hilscher.local/v1/api/schema/get/json/nup/1/nup.schema.json',

              nup = {
                version = '1.0.0'
              },

              releases = {
                repository = tRelease.repository,

                groupID = tRelease.groupID,
                artifactID = tRelease.artifactID,
                version = tRelease.version,

                files = atFilesRelative
              }
            }

            -- Encode the NUP data as JSON.
            local strNupJson = cjson.encode(tNup)

            -- Write the NUP data to a file.
            local fWriteResult, strWriteError = utils.writefile(strNupPath, strNupJson, false)
            if fWriteResult then
              tLog.debug(
                'Wrote the NUP file for %s v%s to %s.',
                tRelease.artifactID,
                tRelease.version,
                strNupPath
              )
            else
              tLog.error(
                'Failed to write the NUP file for %s v%s to %s: %s',
                tRelease.artifactID,
                tRelease.version,
                strNupPath,
                strWriteError
              )
              tResult = nil
              break
            end
          end
        end
      else

        tLog.debug('Skipping NUP generation for "%s".', tArtifact.id)
      end
    end

    if tResult~=true then
      break
    end
  end

  return tResult
end



function _M:use(strTemplateID)
  if strTemplateID=='hilscher_productiontest' then
    -- Set common options in the global environment.
    -- The artifact configuration depends on the artifact ID.
    self:setVar(nil, 'jonchki_artifact_configuration', '${prj_root}/testcase_${artifact_id}.xml')

    -- The test configuration also depends on the artifact ID.
    self:setVar(nil, 'define_test_configuration', '${prj_root}/tests_${artifact_id}.xml')

    -- Build the documentation only for the first build of an artifact.
    -- If an artifact has more than one build, they usually differ only in the CPU architecture. The generated
    -- documentation is the same for all builds in this case, and has even the same filename.
    -- Setting this option to "true" generates the documentation only for the first build and suppresses it for
    -- all other builds.
    -- The main reason for this is cutting down the build time.
    self:setVar(nil, 'define_generate_documentation_only_for_first_build', 'true')

    -- Create a release list for each build.
    self:setVar(nil, 'define_release_list_path', table.concat({
      '${prj_root}',
      'targets',
      '${artifact_id}',
      '${platform_distribution_id}_${platform_distribution_version}_${platform_cpu_architecture}',
      'release_list.json'
    }, '/'))

    -- Set the repository for all NUP files.
    self:setVar(nil, 'define_nup_repository', 'productiontests')

    -- Build NUP files for all complete artifacts.
    self:registerAction(
      'generate_nup_files',
      self.actionGenerateNupFiles,
      nil,
      nil,
      90
    )

  else
    local strMsg = string.format('Unknown template ID "%s".', strTemplateID)
    self.tLog.error('%s', strMsg)
    error(strMsg)
  end
end



function _M:__activate_builds()
  -- By default only the default builds are active.
  -- Change this if build IDs are specified on the command line.
  if #self.m_astrBuilds~=0 then

    -- Create a lookup table for the selected Builds.
    local atBuildLookup = {}
    for _, strBuildID in ipairs(self.m_astrBuilds) do
      atBuildLookup[strBuildID] = true
    end

    -- Loop over all builds in all actions.
    for _, tArtifact in ipairs(self.atArtifacts) do
      for _, tBuild in ipairs(tArtifact.builds) do
        tBuild.active = atBuildLookup[tBuild.id] or false
      end
    end
  end
end



function _M:__add_build_action_for_all_active_builds()
  local tLog = self.tLogSystem

  -- Generate the "build" actions for all active artifacts.
  for _, tArtifact in ipairs(self.atArtifacts) do
    -- A flag indicating that this is the first build of the artifact.
    local fFirstBuildForArtifact = true

    for _, tBuild in ipairs(tArtifact.builds) do
      local strBuildID = tBuild.id
      if tBuild.active~=true then
        tLog.debug('No default build action added to "%s" as it is inactive.', strBuildID)

      else
        tLog.debug('Adding default build action to build "%s".', strBuildID)

        tBuild.first = fFirstBuildForArtifact
        self:setVar(tBuild, 'define_build_is_the_first_one_for_artifact', tostring(fFirstBuildForArtifact))
        fFirstBuildForArtifact = false

        local fResolveResult, strError = self:__resolve(tBuild)
        if fResolveResult~=true then
          local strMsg = string.format(
            'Failed to get the build command for "%s": %s',
            strBuildID,
            strError
          )
          tLog.error(strMsg)
          error(strMsg)
        end

        local tEnv = tBuild.env
        tBuild.cmd = tEnv.jonchki_command
        tBuild.working_folder = tEnv.working_folder
        tBuild.logfile = tEnv.jonchki_logfile

        self:registerAction(
          string.format('build_%s', strBuildID),
          self.actionBuild,
          tBuild,
          tBuild.working_folder,
          self.default_level_for_builds
        )
      end
    end
  end
end



function _M:__run_action(tAction)
  local tLog = self.tLogSystem
  local dir = require 'pl.dir'
  local path = require 'pl.path'
  local tResult = true

  -- Create a log object for the action.
  local tLogAction = require "log".new(
    'trace',
    require 'log.writer.prefix'.new(
      string.format('[%s] ', tAction.name),
      self.cLog
    ),
    require "log.formatter.format".new()
  )
  self.tLog = tLogAction

  -- Save the current working folder.
  local strCwdOriginal = path.currentdir()

  -- Change to the working directory of the action. Create it if necessary.
  local strWorkingFolder = tAction.path
  if strWorkingFolder~=nil then
    local fCreateWorkingFolder, strErrorCreateWorkingFolder = dir.makepath(strWorkingFolder)
    if fCreateWorkingFolder~=true then
      tLog.error(
        'Failed to create the working folder "%s": %s',
        strWorkingFolder,
        tostring(strErrorCreateWorkingFolder)
      )
      tResult = nil

    else
      tLog.debug('Change to the working folder "%s".', strWorkingFolder)
      local fResultCdWorkingFolder, strErrorCdWorkingFolder = path.chdir(strWorkingFolder)
      if fResultCdWorkingFolder~=true then
        tLog.error(
          'Failed to change to the build working folder "%s": %s',
          strWorkingFolder,
          tostring(strErrorCdWorkingFolder)
        )
        tResult = nil
      end
    end
  end

  if tResult==true then
    local tPcallResult, tFnResult = pcall(tAction.fn, self, tAction.userdata)

    if strWorkingFolder~=nil then
      tLog.debug('Action finished, change back from the working folder to "%s".', strCwdOriginal)
      local fResultCdBack, strErrorCdBack = path.chdir(strCwdOriginal)
      if fResultCdBack~=true then
        tLog.error(
          'Failed to change back from the working folder to "%s": %s',
          strCwdOriginal,
          tostring(strErrorCdBack)
        )
        tResult = nil
      end
    end

    if tResult==true then
      if tPcallResult==nil then
        tLog.error('Error running action script "%s": %s', tAction.name, tostring(tFnResult))
        tResult = nil

      elseif tFnResult~=true then
        tLog.error('The action script "%s" returned %s', tAction.name, tostring(tFnResult))
        tResult = nil
      end
    end
  end

  return tResult
end



function _M:build()
  local tLog = self.tLogSystem
  local atActions = self.atActions
  local tResult = true

  self:__activate_builds()
  self:__add_build_action_for_all_active_builds()

  -- Count all actions.
  local uiActionsTotal = 0
  for _, tLevel in pairs(atActions) do
    uiActionsTotal = uiActionsTotal + #tLevel
  end

  -- Run all build actions.
  local uiActionsExecuted = 0
  local tablex = require 'pl.tablex'
  for uiLevel, atLevel in tablex.sort(atActions) do
    tLog.debug('Running actions for level %d.', uiLevel)
    for _, tAction in ipairs(atLevel) do
      uiActionsExecuted = uiActionsExecuted + 1
      tLog.info('Running action %d/%d "%s".', uiActionsExecuted, uiActionsTotal, tAction.name)
      local tActionResult = self:__run_action(tAction)
      if tActionResult~=true then
        tLog.error('Failed to run action "%s"', tAction.name)
        tResult = false
        break
      end
    end
  end

  return tResult
end



--- Resolve all replacement variables.
function _M:__resolve(atEnvironment)
  local tLog = self.tLogSystem
  local tResult = true
  local strError

  local atEnv = atEnvironment.env
  if atEnv==nil then
    strError = string.format(
      'The environment "%s" has no "env" attribute.',
      atEnvironment.id
    )
    tResult = nil
  else

    -- Make a copy of all entries and collect all defines.
    local atCopy = {}
    local atDefines = {}
    local strDefinePrefix = 'define_'
    for strKey, strValue in pairs(atEnv) do
      atCopy[strKey] = strValue
      if string.sub(strKey, 1, string.len(strDefinePrefix))==strDefinePrefix then
        table.insert(atDefines, string.format('--define %s=%s', strKey, strValue))
      end
    end
    -- Add the special replacement "define_all" which contains all defines.
    atCopy['define_all'] = table.concat(atDefines, ' ')

    -- Resolve all replacements until no replacements are left or nothing can be replaced anymore.
    local uiLoopMax = 128
    local uiLoopCnt = 0
    repeat
      local fReplacedSomething = false
      local fReplacementsLeft = false
      local atCopyNext = {}
      for strKey, strValue in pairs(atCopy) do
        -- Try to replace something.
        local strValueReplaced = string.gsub(strValue, '%${([%w_]+)}', atCopy)
        atCopyNext[strKey] = strValueReplaced
        -- Check if something was replaced.
        if strValue~=strValueReplaced then
          fReplacedSomething = true
        end
        -- Check if replacements are left.
        -- This happens if a replacement text contained replacements itself.
        if string.match(strValueReplaced, '%${([%w_]+)}')~=nil then
          fReplacementsLeft = true
        end
      end
      atCopy = atCopyNext

      -- Break after a reasonable number of rounds.
      -- This prevents endless loops in case of circular dependencies.
      uiLoopCnt = uiLoopCnt + 1
      if uiLoopCnt>uiLoopMax then
        tResult = nil
        strError = string.format('Failed to resolve all variables after %d loops. Giving up.', uiLoopMax)
        break
      end
    until fReplacedSomething==false or fReplacementsLeft==false

    if tResult then
      atEnvironment.env = atCopy
    end
  end

  return tResult, strError
end



function _M:dump(atEnvironment, fnPrint)
  local tLog = self.tLogSystem
  fnPrint = fnPrint or tLog.debug

  -- Get all keys of the variables and sort them.
  local atSortedKeys = require 'pl.tablex'.keys(atEnvironment)
  table.sort(atSortedKeys)

  -- Get the maximum length of the keys.
  local uiKeySizeMax = 0
  for _, strKey in ipairs(atSortedKeys) do
    local uiKeySize = string.len(strKey)
    if uiKeySize>uiKeySizeMax then
      uiKeySizeMax = uiKeySize
    end
  end

  -- Pretty-print the vars.
  for _, strKey in ipairs(atSortedKeys) do
    fnPrint(
      '${%s}%s = "%s"',
      strKey,
      string.rep(' ', uiKeySizeMax - string.len(strKey)),
      atEnvironment[strKey]
    )
  end
end



return _M
