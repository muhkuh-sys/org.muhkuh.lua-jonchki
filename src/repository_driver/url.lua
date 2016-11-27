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



function RepositoryDriverUrl:_init(tLogger, strID)
  -- Set the logger and the ID of the repository driver.
  self:super(tLogger, strID)

  self.curl = require 'lcurl'
  self.Version = require 'Version'

  -- Clear the URLs for the configuration and artifact.
  self.strRoot = nil
  self.strVersions = nil
  self.strConfig = nil
  self.strArtifact = nil

  self.atDownloadData = nil
end



-- This is a static member.
function RepositoryDriverUrl.matches_type(strType)
  return strType=='url'
end



function RepositoryDriverUrl:configure(atSettings)
  self.strRoot = atSettings.strRoot
  self.strVersions = atSettings.strVersions
  self.strConfig = atSettings.strConfig
  self.strArtifact = atSettings.strArtifact

  self.tLogger:debug(tostring(self))

  return true
end



function RepositoryDriverUrl:curl_progress(ulDlTotal, ulDlNow, ulUpTotal, ulUpNow)
  print('curl_progress', self)
  print(string.format('%d%% (%d/%d)', ulDlTotal/ulDlNow*100, ulDlNow, ulDlTotal))
  return true
end



function RepositoryDriverUrl:curl_download(aucBuffer)
  table.insert(self.atDownloadData, aucBuffer)
  return true
end



function RepositoryDriverUrl:get_url(strUrl)
  local tResult = nil
  local tCURL = self.curl.easy()

  tCURL:setopt_url(strUrl)

  -- Collect the received data in a table.
  self.atDownloadData = {}
  tCURL:setopt(self.curl.OPT_FOLLOWLOCATION, true)
  tCURL:setopt_writefunction(self.curl_download, self)
  tCURL:setopt_progressfunction(self.curl_progress, self)

  local tCallResult, strError = pcall(tCURL.perform, tCURL)
  if tCallResult~=true then
    self.tLogger('Failed to retrieve URL "%s": %s', strUrl, strError)
  else
    local uiHttpResult = tCURL:getinfo(self.curl.INFO_RESPONSE_CODE)
    if uiHttpResult==200 then
      tResult = table.concat(self.atDownloadData)
    else
      self.tLogger('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
    end
  end
  tCURL:close()

  return tResult
end



function RepositoryDriverUrl:download_url(strUrl, strLocalFile)
  local tResult = nil
  local tCURL = self.curl.easy()

  tCURL:setopt_url(strUrl)

  -- Write the received data to a file.
  local tFile, strError = io.open(strLocalFile, 'wb')
  if tFile==nil then
    self.tLogger:error('Failed to open "%s" for writing: %s', strLocalFile, strError)
  else
    tCURL:setopt_writefunction(tFile)
    tCURL:setopt_progressfunction(self.curl_progress, self)
    local tCallResult, strError = pcall(tCURL.perform, tCURL)
    if tCallResult~=true then
      self.tLogger('Failed to retrieve URL "%s": %s', strUrl, strError)
    else
      local uiHttpResult = tCURL:getinfo(self.curl.INFO_RESPONSE_CODE)
      if uiHttpResult==200 then
        tResult = true
      else
        self.tLogger('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
      end
    end
    tCURL:close()

    tFile:close()
  end

  return tResult
end



function RepositoryDriverUrl:get_available_versions(strGroup, strModule, strArtifact)
  local tResult = nil
  local strError = ''

  -- Combine the group, module and artifact to a string for the logger messages.
  local strGMA = string.format('G:%s/M:%s/A:%s', strGroup, strModule, strArtifact)

  -- Replace the artifact placeholder in the versions path.
  local strPathVersions = self:replace_path(strGroup, strModule, strArtifact, nil, self.strVersions)

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
      tResult, strError = self:get_url(strUrlVersions)
      if tResult==nil then
        self.tLogger:warn('Failed to get available versions for %s: %s', strGMA, strError)
      else
        local strHtmlPage = tResult
        local atVersions = {}

        -- Extract all links.
        for strLink, strText in string.gmatch(strHtmlPage, '<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
          -- Found a valid version?
          local fFound = false

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



function RepositoryDriverUrl:get_sha_sum(strMainFile)
  local tResult = nil

  -- Get the SHA1 URL.
  local strShaUrl = string.format('%s.sha1', strMainFile)

  -- Get tha SHA sum.
  self.tLogger:debug('Get the SHA sum from URL "%s".', strShaUrl)
  local strShaRaw, strMsg = self:get_url(strShaUrl)
  if strShaRaw==nil then
    tResult = nil
    self.tLogger.error('Failed to get the SHA file "%s": %s', strShaUrl, strMsg)
  else
    -- Extract the SHA sum.
    local strMatch = string.match(strShaRaw, '%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x')
    if strMatch==nil then
      tResult = nil
      self.tLogger.error('The SHA1 file "%s" does not contain a valid hash.', strShaUrl)
    else
      tResult = strMatch
    end
  end

  return tResult
end



function RepositoryDriverUrl:get_configuration(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  
  -- Replace the artifact placeholder in the configuration path.
  local strCfgPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, self.strConfig)

  -- Append the version folder to the root.
  local strCfgUrl = string.format('%s/%s', self.strRoot, strCfgPath)

  -- Get the complete file.
  self.tLogger:debug('Get the configuration from URL "%s".', strCfgUrl)
  local strCfgData, strError = self:get_url(strCfgUrl)
  if strCfgData==nil then
    self.tLogger:error('Failed to read the configuration file "%s": %s', strCfgUrl, strError)
  else
    -- Get tha SHA sum.
    local strShaRemote = self:get_sha_sum(strCfgUrl)
    if strShaRemote==nil then
      self.tLogger:error('Failed to get the SHA sum of "%s".', strCfgUrl)
    else
      -- Build the local SHA sum.
      local strShaLocal = self.Hash:get_sha1_string(strCfgData)
      if strShaLocal==nil then
        self.tLogger:error('Failed to get the SHA sum of "%s".', strCfgData)
      else
        -- Compare the SHA1 sum from the repository and the local.
        if strShaRemote~=strShaLocal then
          tResult = nil
          self.tLogger:error('The SHA1 sum of the configuration "%s" does not match.', strCfgUrl)
          self.tLogger:error('The local SHA1 sum is  %s .', strShaLocal)
          self.tLogger:error('The remote SHA1 sum is %s .', strShaRemote)
        else
          local cA = self.ArtifactConfiguration()
          cA:parse_configuration(strCfgData)

          tResult = cA
        end
      end
    end
  end

  return tResult
end



function RepositoryDriverUrl:get_artifact(strGroup, strModule, strArtifact, tVersion, strDestinationFolder)
  local tResult = nil

  -- Construct the artifact path.
  local strArtifactPath = self:replace_path(strGroup, strModule, strArtifact, tVersion, self.strArtifact)

  -- Append the version folder to the root.
  local strArtifactUrl = string.format('%s/%s', self.strRoot, strArtifactPath)
  -- Get the file name.
  local _, strFileName = self.pl.path.splitpath(strArtifactUrl)

  -- Download the file to the destination folder.
  local strLocalFile = self.pl.path.join(strDestinationFolder, strFileName)
  local strError
  tResult = self:download_url(strArtifactUrl, strLocalFile)
  if tResult~=true then
    tResult = nil
    self.tLogger:error('Failed to download the URL "%s" to the file %s', strArtifactUrl, strLocalFile)
  else
    -- Get tha SHA sum.
    tResult = self:get_sha_sum(strArtifactUrl)
    if tResult==nil then
      self.tLogger:error('Failed to get the SHA sum of "%s".', strArtifactUrl)
    else
      local strShaRemote = tResult

      -- Compare the SHA sums.
      tResult = self.Hash:check_sha1(strLocalFile, strShaRemote)
      if tResult~=true then
        tResult = nil
        self.tLogger:error('The SHA1 sum of the artifact "%s" does not match.', strArtifactUrl)
      else
        tResult = strLocalFile
      end
    end
  end

  return tResult
end



function RepositoryDriverUrl:__tostring()
  local tRepr = {}
  table.insert(tRepr, 'RepositoryDriverUrl(')
  table.insert(tRepr, string.format('\tid = "%s"', self.strID))
  table.insert(tRepr, string.format('\troot = "%s"', self.strRoot))
  table.insert(tRepr, string.format('\tversions = "%s"', self.strVersions))
  table.insert(tRepr, string.format('\tconfig = "%s"', self.strConfig))
  table.insert(tRepr, string.format('\tartifact = "%s"', self.strArtifact))
  table.insert(tRepr, ')')
  local strRepr = table.concat(tRepr, '\n')

  return strRepr
end

return RepositoryDriverUrl
