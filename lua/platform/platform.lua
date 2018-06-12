--- A class to detect the platform and store the results.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2016 Christoph Thelen

-- Create the platform class.
local class = require 'pl.class'
local Platform = class()

--- Initialize a new instance of the platform class.
function Platform:_init(tLogger, tReport)
  self.tLogger = tLogger
  self.tReport = tReport

  self.strHostCpuArchitecture = nil
  self.strHostDistributionId = nil
  self.strHostDistributionVersion = nil
  self.strHostModuleExtension = nil

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
  local astrReplacements = {
    ['i386'] = 'x86',
    ['i486'] = 'x86',
    ['i586'] = 'x86',
    ['i686'] = 'x86'
  }

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
          -- Replace the CPU architectures found in the list.
          local strReplacement = astrReplacements[strCpuArchitecture]
          if strReplacement~=nil then
            strCpuArchitecture = strReplacement
          end
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
    self.strHostCpuArchitecture = self:__windows_get_cpu_architecture_env()

    -- Get the version with the 'ver' command.
    self.strHostDistributionId, self.strHostDistributionVersion = self:__windows_get_distribution_ver()

    -- Windows modules have a ".dll" extension.
    self.strHostModuleExtension = 'dll'
  else
    -- This is a Linux.

    -- Detect the CPU architecture.
    self.strHostCpuArchitecture = self:__linux_get_cpu_architecture_lscpu()

    -- Detect the distribution.
    self.strHostDistributionId, self.strHostDistributionVersion = self:__linux_detect_distribution_etc_lsb_release()

    -- Linux modules have a ".so" extension.
    self.strHostModuleExtension = 'so'
  end

  -- Copy the host values to the working values.
  self.strCpuArchitecture = self.strHostCpuArchitecture
  self.strDistributionId = self.strHostDistributionId
  self.strDistributionVersion = self.strHostDistributionVersion

  -- Add the results to the report.
  self.tReport:addData('system/platform/host/cpu_architecture', self.strHostCpuArchitecture)
  self.tReport:addData('system/platform/host/distribution_id', self.strHostDistributionId)
  self.tReport:addData('system/platform/host/distribution_version', self.strHostDistributionVersion)
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
  self.tReport:addData('system/platform/override/cpu_architecture', strCpuArchitecture)
end



function Platform:override_distribution_id(strDistributionId)
  self.strDistributionId = strDistributionId
  self.tReport:addData('system/platform/override/distribution_id', strDistributionId)
end



function Platform:override_distribution_version(strDistributionVersion)
  self.strDistributionVersion = strDistributionVersion
  self.tReport:addData('system/platform/override/distribution_version', strDistributionVersion)
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



function Platform:get_host_id()
  local strHostDistributionId = self.strHostDistributionId or 'unknown'
  local strHostDistributionVersion = self.strHostDistributionVersion or 'unknown'
  local strHostCpuArchitecture = self.strHostCpuArchitecture or 'unknown'

  return string.format('%s-%s-%s', strHostDistributionId, strHostDistributionVersion, strHostCpuArchitecture)
end



function Platform:get_platform_id(strSeparator)
  strSeparator = strSeparator or '-'
  local strDistributionId = self.strDistributionId or 'unknown'
  local strDistributionVersion = self.strDistributionVersion or 'unknown'
  local strCpuArchitecture = self.strCpuArchitecture or 'unknown'

  return string.format('%s%s%s%s%s', strDistributionId, strSeparator, strDistributionVersion, strSeparator, strCpuArchitecture)
end



--- Return the complete platform information as a string.
-- @return The platform information as a string.
function Platform:__tostring()
  return self:get_platform_id()
end


return Platform
