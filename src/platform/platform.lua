--- A class to detect the platform and store the results.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2016 Christoph Thelen

-- Create the platform class.
local class = require 'pl.class'
local Platform = class()

--- Initialize a new instance of the platform class.
function Platform:_init(tLogger)
  self.tLogger = tLogger

  self.strCpuArchitecture = nil
  self.strDistributionId = nil
  self.strDistributionVersion = nil
end



function Platform:__windows_get_cpu_architecture_env()
  local strCpuArchitecture

  local strEnvProcessorArchitecture = os.getenv('PROCESSOR_ARCHITECTURE')
  local strEnvProcessorArchiteW6432 = os.getenv('PROCESSOR_ARCHITEW6432')
  -- See here for details: https://blogs.msdn.microsoft.com/david.wang/2006/03/27/howto-detect-process-bitness/
  if strEnvProcessorArchitecture=='amd64' or strEnvProcessorArchiteW6432=='amd64' then
    strCpuArchitecture = 'x86_64'
  elseif strEnvProcessorArchitecture=='x86' and strEnvProcessorArchiteW6432==nil then
    strCpuArchitecture = 'x86'
  else
    self.tLogger:info('Failed to detect the CPU architecture on Windows with the ENV variables.')
    self.tLogger:debug('PROCESSOR_ARCHITECTURE = %s', tostring(strEnvProcessorArchitecture))
    self.tLogger:debug('PROCESSOR_ARCHITEW6432 = %s', tostring(strEnvProcessorArchiteW6432))
  end

  return strCpuArchitecture
end



-- See here for the output of the "ver" command: https://en.wikipedia.org/wiki/Ver_(command)
function Platform:__windows_get_distribution_ver()
  local strDistributionId
  local strDistributionVersion

  -- The detection needs the popen function.
  if io.popen==nil then
    self.tLogger:info('Unable to detect the Windows version with "ver": io.popen is not available.')
  else
    -- Try to parse the output of the 'ver' command.
    local tFile, strError = io.popen('ver')
    if tFile==nil then
      self.tLogger:info('Failed to get the Windows version with "ver": %s', strError)
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



function Platform:__linux_get_cpu_architecture_lscpu()
  local strCpuArchitecture

  -- The detection needs the popen function.
  if io.popen==nil then
    self.tLogger:info('Unable to detect the CPU architecture with "lscpu": io.popen is not available.')
  else
    -- Try to parse the output of the 'lscpu' command.
    local tFile, strError = io.popen('lscpu')
    if tFile==nil then
      self.tLogger:info('Failed to get the CPU architecture with "lscpu": %s', strError)
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



function Platform:__linux_detect_distribution_etc_lsb_release()
  local strDistributionId
  local strDistributionVersion

  -- Try to open /etc/lsb-release.
  local tFile, strError = io.open('/etc/lsb-release', 'r')
  if tFile==nil then
    self.tLogger:info('Failed to detect the Linux distribution with /etc/lsb-release : %s', strError)
  else
    for strLine in tFile:lines() do
      local tMatch = string.match(strLine, 'DISTRIB_ID=(.+)')
      if tMatch~=nil then
        strDistributionId = string.lower(tMatch)
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



function Platform:detect()
  local strDirectorySeparator = package.config:sub(1,1)
  if strDirectorySeparator=='\\' then
    -- This is windows.

    -- Detect the CPU architecture.
    self.strCpuArchitecture = self.__windows_get_cpu_architecture_env()

    -- Get the version with the 'ver' command.
    self.strDistributionId, self.strDistributionVersion = self.__windows_get_distribution_ver()
  else
    -- This is a Linux.

    -- Detect the CPU architecture.
    self.strCpuArchitecture = self.__linux_get_cpu_architecture_lscpu()

    -- Detect the distribution.
    self.strDistributionId, self.strDistributionVersion = self.__linux_detect_distribution_etc_lsb_release()
  end
end



function Platform:is_valid()
  local fIsValid = true

  if self.strCpuArchitecture==nil then
    fIsValid = false
  elseif self.strDistributionId==nil then
    fIsValid = false
  elseif self.strDistributionVersion==nil then
    fIsValid = false
  end

  return fIsValid
end



function Platform:override_cpu_architecture(strCpuArchitecture)
  self.strCpuArchitecture = strCpuArchitecture
end



function Platform:override_distribution_id(strDistributionId)
  self.strDistributionId = strDistributionId
end



function Platform:override_distribution_version(strDistributionVersion)
  self.strDistributionVersion = strDistributionVersion
end



function Platform:get_cpu_architecture()
  return self.strCpuArchitecture
end



function Platform:get_distribution_id()
  return self.strDistributionId
end



function Platform:get_distribution_version()
  return self.strDistributionVersion
end



--- Return the complete platform information as a string.
-- @return The platform information as a string. 
function Platform:__tostring()
  local strDistributionId = self.strDistributionId or '???'
  local strDistributionVersion = self.strDistributionVersion or '???'
  local strCpuArchitecture = self.strCpuArchitecture or '???'

  return string.format('%s_%s_%s', strDistributionId, strDistributionVersion, strCpuArchitecture)
end


return Platform
