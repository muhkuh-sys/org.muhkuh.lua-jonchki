--- The prepare helper class.
-- It is passed as a helper to the prepare script.

local class = require 'pl.class'
local PrepareHelper = class()

--- Initialize a new instance of the install class.
-- @param strID The ID identifies the resolver.
function PrepareHelper:_init(cLog)
  self.cLog = cLog
  local tLogWriter = require 'log.writer.prefix'.new('[Prepare] ', cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  self.luagit2 = require 'luagit2'
  self.pl = require'pl.import_into'()
  self.hash = require 'Hash'
end


function PrepareHelper:getGitDescription(strRepositoryPath)
  local luagit2 = self.luagit2
  local tLog = self.tLog

  -- Get the VCS version.
  luagit2.init()

  local tRepo = luagit2.repository_open(strRepositoryPath)

  local tDescribeWorkdirOptions = {
    show_commit_oid_as_fallback = true
  }
  local tDescribeResult = luagit2.describe_workdir(tRepo, tDescribeWorkdirOptions)

  local tDescribeResultOptions = {
    abbreviated_size = 12,
    always_use_long_format = true,
    dirty_suffix = '+'
  }
  local tBufOutput = luagit2.describe_format(tDescribeResult, tDescribeResultOptions)
  local strGitId = luagit2.buf_details(tBufOutput)
  tLog.debug('GIT description: "%s"', strGitId)

  luagit2.repository_free(tRepo)
  luagit2.shutdown()

  return strGitId
end


--- Parse a GIT description to a short and a long version.
--  GIT description             short version       long version
--  6b95dbdb5cbd                GIT6b95dbdb5cbd     GIT6b95dbdb5cbd
--  6b95dbdb5cbd+               GIT6b95dbdb5cbd+    GIT6b95dbdb5cbd+
--  v0.3.10.2-0-g306110218a64   GITv0.3.10.2        GITv0.3.10.2-306110218a64
--  v0.3.10.2-0-g306110218a64+  GIT306110218a64+    GIT306110218a64+
--  v0.3.10.1-5-g03afd761133f   GIT03afd761133f     GIT03afd761133f
--  v0.3.10.1-5-g03afd761133f+  GIT03afd761133f+    GIT03afd761133f+
function PrepareHelper:parseGitID(strGitId)
  local tLog = self.tLog
  local strProjectVersionVcs = 'unknown'
  local strProjectVersionVcsLong = 'unknown'

  tLog.debug('Parsing GIT description "%s".', strGitId)
  local tMatch = string.match(strGitId, '^%x%x%x%x%x%x%x%x%x%x%x%x%+?$')
  if tMatch~=nil then
    tLog.debug('This is a repository with no tags. Use the hash.')
    strProjectVersionVcs = strGitId
    strProjectVersionVcsLong = strGitId
  else
    local strVersion, strRevsSinceTag, strHash, strDirty = string.match(strGitId, '^v([%d.]+)-(%d+)-g(%x%x%x%x%x%x%x%x%x%x%x%x)(%+?)$')
    if strVersion~=nil then
      local ulRevsSinceTag = tonumber(strRevsSinceTag)
      if ulRevsSinceTag==0 and strDirty=='' then
        tLog.debug('This is a repository which is exactly on a tag without modification. Use the tag name.')
        strProjectVersionVcs = string.format('v%s%s', strVersion, strDirty)
        strProjectVersionVcsLong = string.format('v%s-%s%s', strVersion, strHash, strDirty)
      else
        tLog.debug('This is a repository with commits after the last tag. Use the hash.')
        strProjectVersionVcs = string.format('%s%s', strHash, strDirty)
        strProjectVersionVcsLong = string.format('%s%s', strHash, strDirty)
      end
    else
      tLog.debug('The description has an unknown format.')
      strProjectVersionVcs = strGitId
      strProjectVersionVcsLong = strGitId
    end
  end

  -- Prepend "GIT" to the VCS ID.
  strProjectVersionVcs = 'GIT' .. strProjectVersionVcs
  strProjectVersionVcsLong = 'GIT' .. strProjectVersionVcsLong
  tLog.debug('PROJECT_VERSION_VCS = "%s"', strProjectVersionVcs)
  tLog.debug('PROJECT_VERSION_VCS_LONG = "%s"', strProjectVersionVcsLong)

  return strProjectVersionVcs, strProjectVersionVcsLong
end


function PrepareHelper:testParseGitID()
  local tLog = self.tLog
  local atTestCases = {
    { '6b95dbdb5cbd',                'GIT6b95dbdb5cbd',     'GIT6b95dbdb5cbd' },
    { '6b95dbdb5cbd+',               'GIT6b95dbdb5cbd+',    'GIT6b95dbdb5cbd+' },
    { 'v0.3.10.2-0-g306110218a64',   'GITv0.3.10.2',        'GITv0.3.10.2-306110218a64' },
    { 'v0.3.10.2-0-g306110218a64+',  'GIT306110218a64+',    'GIT306110218a64+' },
    { 'v0.3.10.1-5-g03afd761133f',   'GIT03afd761133f',     'GIT03afd761133f' },
    { 'v0.3.10.1-5-g03afd761133f+',  'GIT03afd761133f+',    'GIT03afd761133f+' },
    { 'v1.6.1-33-g76cda0285c02+',    'GIT76cda0285c02+',    'GIT76cda0285c02+' }
  }
  local tResult = true
  for uiTestCnt, tTestCase in ipairs(atTestCases) do
    tLog.info('Testcase %d: "%s" -> "%s", "%s"', uiTestCnt, tTestCase[1], tTestCase[2], tTestCase[3])
    local strProjectVersionVcs, strProjectVersionVcsLong = parseGitID(tTestCase[1])
    if strProjectVersionVcs==tTestCase[2] and strProjectVersionVcsLong==tTestCase[3] then
      tLog.info('  OK')
    else
      tLog.error('  ERROR: "%s", "%s"', strProjectVersionVcs, strProjectVersionVcsLong)
      tResult = false
    end
  end

  if tResult==true then
    tLog.info('All tests OK.')
  else
    error('The tests failed.')
  end
end


function PrepareHelper:copy(tFilelist)
  local pl = self.pl
  local tLog = self.tLog

  for strSrc, strDst in pairs(tFilelist) do
    local tCopyResult, strErrorCopy = pl.file.copy(strSrc, strDst, true)
    if tCopyResult~=true then
      tLog.error('Failed to copy "%s" to "%s": %s', strSrc, strDst, strErrorCopy)
      error('Failed to copy.')
    end
  end
end


function PrepareHelper:filterVcsId(strRepositorPath, strSourceFile, strDestinationFile)
  local pl = self.pl
  local tLog = self.tLog
  local strRepositoryPathAbs = pl.path.abspath(strRepositorPath)
  local strGitId = self:getGitDescription(strRepositoryPathAbs)
  local strProjectVersionVcs, strProjectVersionVcsLong = self:parseGitID(strGitId)

  -- Read the test template.
  local strTestcaseTemplate, strErrorRead = pl.utils.readfile(strSourceFile, false)
  if strTestcaseTemplate==nil then
    tLog.error('Failed to read "%s": %s', strSourceFile, tostring(strErrorRead))
    error('Failed to read the source file.')
  else
    local atReplace = {
      PROJECT_VERSION_VCS = strProjectVersionVcs,
      PROJECT_VERSION_VCS_LONG = strProjectVersionVcsLong
    }
    local strTestcaseXml = string.gsub(strTestcaseTemplate, '%$%{([a-zA-Z0-9_]+)%}', atReplace)

    -- Write the testcase XML.
    local tResultWrite, strErrorWrite = pl.utils.writefile(strDestinationFile, strTestcaseXml, false)
    if tResultWrite~=true then
      tLog.error('Failed to write "%s": %s', strErrorWrite, tostring(strErrorWrite))
      error('Failed to write the destination file.')
    end
  end
end

return PrepareHelper
