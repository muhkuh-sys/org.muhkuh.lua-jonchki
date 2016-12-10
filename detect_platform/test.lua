-- Try to detect a set of parameters which define the target platform for a
-- package.
--
--  * The platform should be defined in a way that compiled code from package
--    X runs on platforms in category Y.
--    Example: All 64Bit code from MinGW64 should run on 64Bit windows systems.
--
--  * The LUA interpreter with its version.
--    Is it important to distinguish the normal LUA interpreter and LUAJIT?
--    Examples: "Lua 5.1" or "LuaJit 5.1"


-- LUA and LUAJIT compatibility
--
-- It seems to be possible to use all LUA modules also with LUAJIT.
-- On Ubuntu the module must be in the correct folder, on my system it is
-- /usr/lib/x86_64-linux-gnu/lua/5.1


local function windows_get_cpu_architecture()
  local strCpuArchitecture

  local strEnvProcessorArchitecture = os.getenv('PROCESSOR_ARCHITECTURE')
  local strEnvProcessorArchiteW6432 = os.getenv('PROCESSOR_ARCHITEW6432')
  -- See here for details: https://blogs.msdn.microsoft.com/david.wang/2006/03/27/howto-detect-process-bitness/
  if strEnvProcessorArchitecture=='amd64' or strEnvProcessorArchiteW6432=='amd64' then
    strCpuArchitecture = 'x86_64'
  elseif strEnvProcessorArchitecture=='x86' and strEnvProcessorArchiteW6432==nil then
    strCpuArchitecture = 'x86'
  end

  return strCpuArchitecture
end



-- See here for the output of the "ver" command: https://en.wikipedia.org/wiki/Ver_(command)
local function windows_get_distribution()
  local strDistributionId
  local strDistributionVersion

  -- The detection needs the popen function.
  if io.popen==nil then
    print('Unable to detect the Windows version with "ver": io.popen is not available.')
  else
    -- Try to parse the output of the 'ver' command.
    local tFile, strError = io.popen('ver')
    if tFile==nil then
      print(string.format('Failed to get the Windows version with "ver": %s', strError))
    else
      for strLine in tFile:lines() do
        local tMatch = string.match(strLine, '%d+%.%d+%.%d+')
        if tMatch~=nil then
          strDistributionId = 'windows'
          strDistributionVersion = tMatch
          break
        end
      end
      tFile:close()
    end
  end

  return strDistributionId, strDistributionVersion
end



local function linux_get_cpu_architecture_lscpu()
  local strCpuArchitecture

  -- The detection needs the popen function.
  if io.popen==nil then
    print('Unable to detect the CPU architecture with "lscpu": io.popen is not available.')
  else
    -- Try to parse the output of the 'lscpu' command.
    local tFile, strError = io.popen('lscpu')
    if tFile==nil then
      print(string.format('Failed to get the CPU architecture with "lscpu": %s', strError))
    else
      for strLine in tFile:lines() do
        local tMatch = string.match(strLine, 'Architecture: *([^ ]+)')
        if tMatch~=nil then
          strCpuArchitecture = tMatch
          break
        end
      end
      tFile:close()
    end
  end

  return strCpuArchitecture
end



local function linux_detect_distribution_etc_lsb_release()
  local strDistributionId
  local strDistributionVersion

  -- Try to open /etc/lsb-release.
  local tFile, strError = io.open('/etc/lsb-release', 'r')
  if tFile==nil then
    print('No /etc/lsb-release found.')
  else
    for strLine in tFile:lines() do
      local tMatch = string.match(strLine, 'DISTRIB_ID=(.+)')
      if tMatch~=nil then
        strDistributionId = tMatch
      end
      tMatch = string.match(strLine, 'DISTRIB_RELEASE=(.+)')
      if tMatch~=nil then
        strDistributionVersion = tMatch
      end
    end

    tFile:close()
  end

  -- Return both components or none.
  if strDistributionId==nil or strDistributionVersion==nil then
    strDistributionId = nil
    strDistributionVersion = nil
  end

  return strDistributionId, strDistributionVersion
end


local strCpuArchitecture
local strDistributionId
local strDistributionVersion

local strDirectorySeparator = package.config:sub(1,1)
if strDirectorySeparator=='\\' then
  -- This is windows.

  -- Detect the CPU architecture.
  strCpuArchitecture = windows_get_cpu_architecture()

  -- Get the version with the 'ver' command.
  strDistributionId, strDistributionVersion = windows_get_distribution()
else
  -- This is a Linux.

  -- Detect the CPU architecture.
  strCpuArchitecture = linux_get_cpu_architecture_lscpu()

  -- Detect the distribution.
  strDistributionId, strDistributionVersion = linux_detect_distribution_etc_lsb_release()
end

if strCpuArchitecture==nil then
  error('Failed to detect the CPU architecture.')
elseif strDistributionId==nil then
  error('Failed to detect the distribution ID.')
elseif strDistributionVersion==nil then
  error('Failed to detect the distribution version.')
end

print(string.format('%s_%s_%s', strDistributionId, strDistributionVersion, strCpuArchitecture))
