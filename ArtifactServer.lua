local artifact_server = {}

artifact_server.VersionResolver = require("VersionResolver")

-- Add all drivers.
artifact_server.atDrivers = {}
artifact_server.atDrivers['nexus'] = require("ArtifactServer.nexus")

artifact_server.tDriver = nil


function artifact_server:init(strDriverName, atDriverConfiguration)
  local fOk = true
  local strMsg = nil

  -- No driver found yet.
  local tDriverFound = nil
  -- Search the driver name.
  for strName,tDriver in pairs(self.atDrivers) do
    if strName==strDriverName then
      tDriverFound = tDriver
      break
    end
  end

  if tDriverFound==nil then
    strMsg = string.format("Driver not found: '%s'", strDriverName)
    fOk = false
  else
    -- Set the driver.
    self.tDriver = tDriverFound

    -- Initialize the driver.
    fOk,strMsg = self.tDriver:init(atDriverConfiguration)
  end

  return fOk,strMsg
end


function artifact_server:resolve(strArtifact, strVersionConstraint)
  local fOk = true
  local tResult = nil
  local atArtifacts = nil
  local astrMessages = {}
  strVersionConstraint = strVersionConstraint or ""

  -- This does not work if no driver is set.
  if self.tDriver==nil then
    tResult = "Not initialized! No driver set."
    fOk = false
  else
    -- Search all artifacts.
    fOk,atArtifacts = self.tDriver:search(strArtifact)
    if fOk~=true then
      tResult = atArtifacts
    else
      -- Extract all versions.
      local astrVersions = {}
      local astrVersionLookup = {}
      for iCnt,atArtifact in ipairs(atArtifacts) do
        -- Convert the version to a plain representation.
        fOk,tResult = self.VersionResolver:getCleanString(atArtifact.version)
        -- Is this a valid version string?
        if fOk~=true then
          fOk = false
          tResult = string.format("Artifact %s: '%s' is no valid version: %s", atArtifact.artifactId, atArtifact.version, tResult)
          break
        else
          strCleanVersion = tResult

          -- Does this version exist already?
          if astrVersionLookup[strCleanVersion]~=nil then
            fOk = false
            tResult = string.format("The version %s exists more than once!", strCleanVersion)
            break
          else
            table.insert(astrVersions, strCleanVersion)
            astrVersionLookup[strCleanVersion] = atArtifact
          end
        end
      end

      if fOk==true then
        -- Get the best matching version.
        fOk,tResult,astrMessages = self.VersionResolver:getBestMatch(strVersionConstraint, astrVersions)
        if fOk~=true then
          fOk = false
        elseif tResult==nil then
          fOk = false
          table.insert(astrMessages, "No matching version found!")
        else
          local strBestVersion = table.concat(tResult, ".")

          tResult = astrVersionLookup[strBestVersion]
          if tResult==nil then
            fOk = false
            tResult = "Internal error. The chosen version does not exist!"
          end
        end
      end
    end
  end

  return fOk,tResult,astrMessages
end



-- Download the SHA1 sum, then the artifact. Check the artifact with the SHA1 sum.
function artifact_server:download(atArtifact, strClassifier, strExtension)
  local fOk = true
  local tResult = nil

  -- This does not work if no driver is set.
  if self.tDriver==nil then
    tResult = "Not initialized! No driver set."
    fOk = false
  else
    -- Download the SHA1 sum.
    fOk,tResult = self.tDriver:download(atArtifact, strClassifier, strExtension)
  end

  return fOk, tResult
end


return artifact_server
