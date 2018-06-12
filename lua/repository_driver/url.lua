--- A repository driver for URLs.
-- The repository module provides an abstraction to a number of different
-- repositories. The real work is done by drivers. This is the driver
-- providing access to a repository accessible by URLs like HTTP or HTTPS.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2016 Christoph Thelen

-- Create the class.
local class = require 'pl.class'
local RepositoryDriver = require 'repository_driver.repository_driver'
local RepositoryDriverUrl = class(RepositoryDriver)



function RepositoryDriverUrl:_init(tLogger, tPlatform, strID)
  -- Set the logger, platform and the ID of the repository driver.
  self:super(tLogger, tPlatform, strID)

  -- Get an available curl module.
  self:__get_any_curl()

  self.Version = require 'Version'

  -- Clear the URLs for the configuration and artifact.
  self.fCacheable = nil
  self.ulRescan = nil
  self.strRoot = nil
  self.strVersions = nil
  self.strConfig = nil
  self.strArtifact = nil

  self.atDownloadData = nil
end



function RepositoryDriverUrl:__get_any_curl()
  local curl
  local fFoundCurl = false

  -- No curl found yet.
  self.curl = nil
  self.get_url = nil
  self.download_url = nil

  -- Prefer the LUA module lcurl.
  local tResult, curl = pcall(require, 'lcurl')
  if tResult==true then
    self.tLogger:info('Detected lcurl.')
    -- Get the version.
    local tVersion = curl.version_info()
    if tVersion.version_num<0x00073501 then
      self.tLogger:warn('The version of lcurl is %s. This is older than the recommended version of 7.53.1.', tVersion.version_num)
    end
    if tVersion.protocols['HTTP']~=true then
      self.tLogger:warn('The version of lcurl does not support HTTP. Ignoring lcurl.')
    elseif tVersion.protocols['HTTPS']~=true then
      self.tLogger:warn('The version of lcurl does not support HTTPS. Ignoring lcurl.')
    else
      self.curl = curl
      self.get_url = self.get_url_lcurlv3
      self.download_url = self.download_url_lcurlv3
      fFoundCurl = true

      self.tLogger:info('Using lcurl.')
    end
  end

  if fFoundCurl==false then
    -- Try to use the command line tool.
    -- The detection needs the popen function.
    if io.popen==nil then
      self.tLogger:info('Unable to detect the command line tool "curl": io.popen is not available.')
    else
      -- Try to run "curl".
      local tFile, strError = io.popen('curl --version')
      if tFile==nil then
        self.tLogger:info('Failed to detect the command line tool "curl": %s', strError)
      else
        -- Read all data from curl.
        local strData = tFile:read('*a')
        tFile:close()

        -- Get the version.
        local strVersion = string.match(strData, 'curl ([0-9.]+) ')
        self.tLogger:info('Detected curl version %s', strVersion)
        -- Check for HTTP and HTTPS.
        local strHttp = string.match(string.lower(strData), '%shttp%s')
        local strHttps = string.match(string.lower(strData), '%shttps%s')
        if strHttp==nil then
          self.tLogger:warn('Ignoring the command line version of curl as it does not support HTTP.')
        elseif strHttps==nil then
          self.tLogger:warn('Ignoring the command line version of curl as it does not support HTTPS.')
        else
          self.curl = nil
          self.get_url = self.get_url_clicurl
          self.download_url = self.download_url_clicurl
          fFoundCurl = true

          self.tLogger:info('Using command line curl.')
        end
      end
    end
  end

  if fFoundCurl==false then
    error('No suitable curl found.')
  end
end



-- This is a static member.
function RepositoryDriverUrl.matches_type(strType)
  return strType=='url'
end



function RepositoryDriverUrl:configure(atSettings)
  self.fCacheable = atSettings.cacheable
  self.ulRescan = atSettings.ulRescan
  self.strRoot = atSettings.strRoot
  self.strVersions = atSettings.strVersions
  self.strConfig = atSettings.strConfig
  self.strArtifact = atSettings.strArtifact

  self.tLogger:debug(tostring(self))

  return true
end



function RepositoryDriverUrl:curl_progress(ulDlTotal, ulDlNow)
  tNow = os.time()
  if os.difftime(tNow, self.tLastProgressTime)>3 then
    if ulDlTotal==0 then
      print(string.format('%d/unknown', ulDlNow))
    else
      print(string.format('%d%% (%d/%d)', ulDlNow/ulDlTotal*100, ulDlNow, ulDlTotal))
    end
    self.tLastProgressTime = tNow
  end
  return true
end



function RepositoryDriverUrl:curl_download(aucBuffer)
  table.insert(self.atDownloadData, aucBuffer)
  return true
end



function RepositoryDriverUrl:get_url_lcurlv3(strUrl)
  local tResult = nil
  local tCURL = self.curl.easy()
  local uiHttpResult

  tCURL:setopt_url(strUrl)

  -- Collect the received data in a table.
  self.atDownloadData = {}
  self.tLastProgressTime = 0
  tCURL:setopt(self.curl.OPT_FOLLOWLOCATION, true)
  tCURL:setopt_writefunction(self.curl_download, self)
  tCURL:setopt_noprogress(false)
  tCURL:setopt_progressfunction(self.curl_progress, self)

  local tCallResult, strError = pcall(tCURL.perform, tCURL)
  if tCallResult~=true then
    self.tLogger:error('Failed to retrieve URL "%s": %s', strUrl, strError)
  else
    uiHttpResult = tCURL:getinfo(self.curl.INFO_RESPONSE_CODE)
    if uiHttpResult==200 then
      tResult = table.concat(self.atDownloadData)
    else
      self.tLogger:error('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
    end
  end
  tCURL:close()

  return tResult, uiHttpResult
end



function RepositoryDriverUrl:download_url_lcurlv3(strUrl, strLocalFile)
  local tResult = nil
  local tCURL = self.curl.easy()
  local uiHttpResult

  tCURL:setopt_url(strUrl)

  -- Write the received data to a file.
  local tFile, strError = io.open(strLocalFile, 'wb')
  if tFile==nil then
    self.tLogger:error('Failed to open "%s" for writing: %s', strLocalFile, strError)
  else
    self.tLastProgressTime = 0
    tCURL:setopt(self.curl.OPT_FOLLOWLOCATION, true)
    tCURL:setopt_writefunction(tFile)
    tCURL:setopt_noprogress(false)
    tCURL:setopt_progressfunction(self.curl_progress, self)
    local tCallResult, strError = pcall(tCURL.perform, tCURL)
    if tCallResult~=true then
      self.tLogger:error('Failed to retrieve URL "%s": %s', strUrl, strError)
    else
      uiHttpResult = tCURL:getinfo(self.curl.INFO_RESPONSE_CODE)
      if uiHttpResult==200 then
        tResult = true
      else
        self.tLogger:error('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
      end
    end
    tCURL:close()

    tFile:close()
  end

  return tResult, uiHttpResult
end



function RepositoryDriverUrl:get_url_clicurl(strUrl)
  local tResult = nil


  local tFile, strError = io.popen(string.format('curl --location --silent --fail "%s"', strUrl))
  if tFile==nil then
    self.tLogger:info('Failed to download "%s": %s', strUrl, strError)
  else
    -- Read all data.
    local strData = tFile:read('*a')
    tFile:close()

    tResult = strData
  end

  return tResult
end



function RepositoryDriverUrl:download_url_clicurl(strUrl, strLocalFile)
  local tResult = nil


  local tCurlResult = os.execute(string.format('curl --location --fail --output "%s" "%s"', strLocalFile, strUrl))
  if tCurlResult==0 then
    tResult = true
  end
    
  return tResult
end



function RepositoryDriverUrl:get_available_versions(strGroup, strModule, strArtifact)
  local tResult = nil

  self.uiStatistics_VersionScans = self.uiStatistics_VersionScans + 1

  -- Combine the group, module and artifact to a string for the logger messages.
  local strGMA = string.format('G:%s/M:%s/A:%s', strGroup, strModule, strArtifact)

  -- Replace the artifact placeholder in the versions path.
  local strPathVersions = self:replace_path(strGroup, strModule, strArtifact, nil, nil, nil, self.strVersions)

  -- Append the version folder to the root.
  local strUrlVersions = string.format('%s/%s', self.strRoot, strPathVersions)

  -- Get the protocol.
  local strProtocol = string.match(strUrlVersions, '([^:]+)')
  if strProtocol==nil then
    self.tLogger:warn('Failed to get available versions for %s: can not determine protocol for URL "%s".', strGMA, strUrlVersions)
  else
    strProtocol = string.lower(strProtocol)
    -- Is this HTTP or HTTPS?
    if strProtocol=='http' or strProtocol=='https' then
      -- HTTP or HTTPS provide the list of available versions as a HTML page.

      -- Get the page and extract the versions from the links.
      self.tLogger:debug('Get versions from URL "%s".', strUrlVersions)
      local tGetResult, uiHttpStatus = self:get_url(strUrlVersions)
      if tGetResult==nil then
        if uiHttpStatus==404 then
          -- A 404 status is no error in this case. It simply means that the artifact is not present in this repository.
          self.tLogger:debug('The artifact %s was not found in the repository (404).', strGMA)
          tResult = {}
        else
          self.tLogger:warn('Failed to get available versions for %s.', strGMA)
        end
      else
        local strHtmlPage = tGetResult
        local atVersions = {}

        -- Extract all links.
        for strLink, strText in string.gmatch(strHtmlPage, '<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
          -- Extract the version from the text.
          -- NOTE: The regular expression is not sufficient for a correct
          -- version string, as it accepts any mixture of numbers and dots.
          -- Stricter expressions did not work properly, so the version is
          -- checked for a valid syntax later with the Version class.
          local strVersion = string.match(strText, '[%d%.]+')
          if strVersion~=nil then
            -- Parse the version with the Version class.
            local tVersion = self.Version()
            -- NOTE: the result of this operation is local as a failure just
            --       means that we got a bad match.
            local tParseResult = tVersion:set(strVersion)
            if tParseResult==true then
              -- Extract the versions from the link and compare them to the text version.
              -- NOTE: The link might have more matches as it can contain stuff like "lua51".
              for strVersionLink in string.gmatch(strLink, '[%d%.]+') do
                if strVersionLink==strVersion then
                  self.tLogger:debug('Found %s version %s .', strGMA, strVersion)
                  table.insert(atVersions, tVersion)
                  break
                end
              end
            end
          end
        end

        tResult = atVersions
      end

    else
      -- Unknown protocol.
      self.tLogger:warn('Failed to get available versions for %s: can not handle protocol "%s".', strGMA, strProtocol)
    end
  end

  return tResult
end



function RepositoryDriverUrl:get_configuration(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- Try the platform independent version first.
  local strCurrentPlatform = ''
  local strCfgPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml', self.strConfig)
  local strHashPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml.hash', self.strConfig)
  -- Append the version folder to the root.
  local strCfgUrl = string.format('%s/%s', self.strRoot, strCfgPath)
  local strHashUrl = string.format('%s/%s', self.strRoot, strHashPath)

  -- Get the complete file.
  self.tLogger:debug('Try to get the platform independent configuration from URL "%s".', strCfgUrl)
  local strCfgData = self:get_url(strCfgUrl)
  local strHash
  if strCfgData~=nil then
    -- Get tha hash sum.
    strHash = self:get_url(strHashUrl)
    if strHash~=nil then
      tResult = true
    end
  end

  if tResult~=true then
    -- Try the platform specific version.
    strCurrentPlatform = self.tPlatform:get_platform_id('_')
    strCfgPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml', self.strConfig)
    strHashPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform, 'xml.hash', self.strConfig)
    -- Append the version folder to the root.
    strCfgUrl = string.format('%s/%s', self.strRoot, strCfgPath)
    strHashUrl = string.format('%s/%s', self.strRoot, strHashPath)

    -- Get the complete file.
    self.tLogger:debug('Try to get the platform specific configuration for "%s" from URL "%s".', strCurrentPlatform, strCfgUrl)
    strCfgData = self:get_url(strCfgUrl)
    if strCfgData~=nil then
      -- Get tha hash sum.
      strHash = self:get_url(strHashUrl)
      if strHash~=nil then
        tResult = true
      end
    end
  end

  if tResult~=true then
    self.tLogger:error('No platform independent and platform specific configuration file found for %s.', strGMAV)
    self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
  else
    -- Check the hash sum.
    tResult = self.hash:check_string(strCfgData, strHash, strCfgUrl, strHashUrl)
    if tResult~=true then
      self.tLogger:error('The hash sum of the configuration "%s" does not match.', strCfgUrl)
      self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
      tResult = nil
    else
      local cA = self.ArtifactConfiguration(self.tLogger)
      tResult = cA:parse_configuration(strCfgData, strCfgUrl)
      if tResult~=true then
        self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
        tResult = nil
      else
        -- Compare the GMAV from the configuration with the requested values.
        tResult = cA:check_configuration(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform)
        if tResult~=true then
          self.tLogger:error('%s The configuration for artifact %s does not match the requested group/module/artifact/version.', self.strID, strGMAV)
          self.uiStatistics_GetConfiguration_Error = self.uiStatistics_GetConfiguration_Error + 1
          tResult = nil
        else
          tResult = cA
          self.uiStatistics_GetConfiguration_Success = self.uiStatistics_GetConfiguration_Success + 1
          self.uiStatistics_ServedBytesConfig = self.uiStatistics_ServedBytesConfig + string.len(strCfgData)
          self.uiStatistics_ServedBytesConfigHash = self.uiStatistics_ServedBytesConfigHash + string.len(strHash)
        end
      end
    end
  end

  return tResult
end



function RepositoryDriverUrl:get_artifact(cArtifact, strDestinationFolder)
  local tResult

  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strPlatform = tInfo.strPlatform
  local strExtension = tInfo.strExtension

  -- Construct the artifact path.
  local strArtifactPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, strPlatform, strExtension, self.strArtifact)
  local strHashPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, strPlatform, string.format('%s.hash', strExtension), self.strArtifact)

  -- Append the version folder to the root.
  -- FIXME: First check if the URLs are already absolute. In this case do not append the root folder.
  local strArtifactUrl = string.format('%s/%s', self.strRoot, strArtifactPath)
  local strHashUrl = string.format('%s/%s', self.strRoot, strHashPath)

  -- Get the file name.
  local _, strFileName = self.pl.path.splitpath(strArtifactUrl)

  -- Download the file to the destination folder.
  local strLocalFile = self.pl.path.join(strDestinationFolder, strFileName)
  tResult = self:download_url(strArtifactUrl, strLocalFile)
  if tResult~=true then
    tResult = nil
    self.tLogger:error('Failed to download the URL "%s" to the file %s', strArtifactUrl, strLocalFile)
    self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
  else
    -- Get tha SHA sum.
    tResult = self:get_url(strHashUrl)
    if tResult==nil then
      self.tLogger:error('Failed to get the hash sum of "%s".', strArtifactUrl)
      self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
    else
      local strHash = tResult

      -- Check the hash sum of the local file.
      tResult = self.hash:check_file(strLocalFile, strHash, strHashUrl)
      if tResult~=true then
        self.tLogger:error('The hash sum of the artifact "%s" does not match.', strArtifactUrl)
        tResult = nil
        self.uiStatistics_GetArtifact_Error = self.uiStatistics_GetArtifact_Error + 1
      else
        tResult = strLocalFile
        self.uiStatistics_GetArtifact_Success = self.uiStatistics_GetArtifact_Success + 1
        self.uiStatistics_ServedBytesArtifact = self.uiStatistics_ServedBytesArtifact + self.pl.path.getsize(strLocalFile)
        self.uiStatistics_ServedBytesArtifactHash = self.uiStatistics_ServedBytesArtifactHash + string.len(strHash)
      end
    end
  end

  return tResult
end



function RepositoryDriverUrl:__tostring()
  local tRepr = {}
  table.insert(tRepr, 'RepositoryDriverUrl(')
  table.insert(tRepr, string.format('\tid = "%s"', self.strID))
  table.insert(tRepr, string.format('\tcacheable = "%s"', tostring(self.fCacheable)))
  table.insert(tRepr, string.format('\troot = "%s"', self.strRoot))
  table.insert(tRepr, string.format('\tversions = "%s"', self.strVersions))
  table.insert(tRepr, string.format('\tconfig = "%s"', self.strConfig))
  table.insert(tRepr, string.format('\tartifact = "%s"', self.strArtifact))
  table.insert(tRepr, ')')
  local strRepr = table.concat(tRepr, '\n')

  return strRepr
end

return RepositoryDriverUrl
