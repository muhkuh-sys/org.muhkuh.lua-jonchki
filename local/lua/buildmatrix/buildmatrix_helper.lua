local class = require 'pl.class'
local _M = class()


function _M:_init(cLog, strProjectRoot, strLuaInterpreter, strJonchkiScript)
  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[BuildMatrix] ', cLog)
  self.tLog = require "log".new(
    "trace",
    tLogWriter,
    require "log.formatter.format".new()
  )

  self.__fStopAfterFirstError = true

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

  self.__atArtifacts = {}
  self.__atArtifactLookup = {}
end



--- Set a replacement key to a value.
-- A new key can be created or the value of an existing key can be replaced.
function _M:setVar(atEnvironment, tKey, tValue)
  local tLog = self.tLog
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
  local tLog = self.tLog

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
  local tLog = self.tLog

  local atArtifacts = self.__atArtifacts
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
  local tLog = self.tLog
  if fIsActivatedByDefault==nil then
    fIsActivatedByDefault = true
  end

  for _, tArtifact in ipairs(self.__atArtifacts) do
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



function _M:build()
  local tLog = self.tLog
  local compat = require 'pl.compat'
  local dir = require 'pl.dir'
  local path = require 'pl.path'
  local fStopAfterFirstError = self.__fStopAfterFirstError

  local fRunning = true
  local uiArtifactsCnt = #(self.__atArtifacts)
  for uiArtifactIdx, tArtifact in ipairs(self.__atArtifacts) do
    tLog.info('Processing artifact %d/%d "%s"...', uiArtifactIdx, uiArtifactsCnt, tArtifact.id)

    for _, tBuild in ipairs(tArtifact.builds) do
      local strBuildID = tBuild.id
      if tBuild.active~=true then
        tLog.debug('Skipping inactive build "%s".', strBuildID)
      else
        if tBuild.cmd==nil then
          local atResolvedEnv, strError = self:__resolve(tBuild)
          if atResolvedEnv==nil then
            local strMsg = string.format(
              'Failed to get the build command for "%s": %s',
              strBuildID,
              strError
            )
            tLog.error(strMsg)
            error(strMsg)
          end

          tBuild.cmd = atResolvedEnv.jonchki_command
          tBuild.working_folder = atResolvedEnv.working_folder
          tBuild.logfile = atResolvedEnv.jonchki_logfile
        end

        tLog.info('  Building "%s"...', strBuildID)
        local strCmd = tBuild.cmd
        tLog.debug('  Build command for "%s" is: %s', strBuildID, strCmd)
        -- Save the current working folder.
        local strCwdOriginal = path.currentdir()
        -- Change to the working directory. Create it if necessary.
        local strWorkingFolder = tostring(tBuild.working_folder)
        local fCreateWorkingFolder, strErrorCreateWorkingFolder = dir.makepath(strWorkingFolder)
        if fCreateWorkingFolder~=true then
          local strMsg = string.format(
            'Failed to create the working folder "%s": %s',
            strWorkingFolder,
            tostring(strErrorCreateWorkingFolder)
         )
          tLog.error(strMsg)
          error(strMsg)
        end
        tLog.debug('Change to the working folder "%s".', strWorkingFolder)
        local fResultCdWorkingFolder, strErrorCdWorkingFolder = path.chdir(strWorkingFolder)
        if fResultCdWorkingFolder~=true then
          local strMsg = string.format(
            'Failed to change to the build working folder "%s": %s',
            strWorkingFolder,
            tostring(strErrorCdWorkingFolder)
          )
          tLog.error(strMsg)
          error(strMsg)
        end
        local fBuildCmdResult, ulBuildCmdStatus = compat.execute(strCmd)
        tLog.debug('Build finished, change back from the working folder to "%s".', strCwdOriginal)
        local fResultCdBack, strErrorCdBack = path.chdir(strCwdOriginal)
        if fResultCdBack~=true then
          local strMsg = string.format(
            'Failed to change back from the working folder to "%s": %s',
            strCwdOriginal,
            tostring(strErrorCdBack)
          )
          tLog.error(strMsg)
          error(strMsg)
        end
        tBuild.result = fBuildCmdResult
        if fBuildCmdResult then
          tBuild.result = true
          tLog.info('    Success.')
        else
          tLog.error(
            '    Failed, status: %s, logfile: %s',
            tostring(ulBuildCmdStatus),
            tBuild.logfile
          )
          if fStopAfterFirstError then
            tLog.debug('Stopping build after the first failure.')
            fRunning = false
            break
          end
        end
      end
    end

    if fRunning~=true then
      break
    end
  end
end


--- Resolve all replacement variables.
function _M:__resolve(atEnvironment)
  local tLog = self.tLog

  local atEnv = atEnvironment.env
  if atEnv==nil then
    local strMsg = string.format(
      'The environment "%s" has no "env" attribute.',
      atEnvironment.id
    )
    tLog.error(strMsg)
    error(strMsg)
  end

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
  local strError
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
      atCopy = nil
      strError = string.format('Failed to resolve all variables after %d loops. Giving up.', uiLoopMax)
      break
    end
  until fReplacedSomething==false or fReplacementsLeft==false

  return atCopy, strError
end



function _M:dump(atEnvironment, fnPrint)
  local tLog = self.tLog
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
