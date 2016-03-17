local version_resolver = {}


function version_resolver:componentToNumber(strComponent)
  local fOk = true
  local tResult = nil
  local uiNumber = tonumber(strComponent)
  if uiNumber==nil then
    fOk = false
    tResult = string.format("Invalid version: '%s'. Component '%s' at offset %d is no number!", strVersion, strSub, iSearchPosition)
  elseif uiNumber<0 then
    fOk = false
    tResult = string.format("Invalid version: '%s'. Component '%s' at offset %d is negativ!", strVersion, strSub, iSearchPosition)
  else
    tResult = uiNumber
  end

  return fOk, tResult
end



function version_resolver:convertStringToList(strVersion)
  local fOk = true
  local tResult = nil
  local astrComponents = {}
  local iSearchPosition = 1

  repeat
    -- Find the next dot.
    local iStart,iEnd = string.find(strVersion, ".", iSearchPosition, true)
    if iStart~=nil then
      -- There must be at least one char before the dot.
      if iSearchPosition==iStart then
        fOk = false
        tResult = string.format("Invalid version: '%s'. No number before the dot at position %d!", strVersion, iSearchPosition)
        break
      end
      -- Extract the string from the search start up to the dot.
      local strSub = string.sub(strVersion, iSearchPosition, iStart)
      local uiNumber
      fOk,uiNumber = self:componentToNumber(strSub)
      if fOk~=true then
        tResult = uiNumber
        break
      end

      table.insert(astrComponents, uiNumber)

      iSearchPosition = iEnd + 1
    end
  until iStart~=nil

  if iSearchPosition<string.len(strVersion) then
    local strSub = string.sub(strVersion, iSearchPosition)

    local uiNumber
    fOk,uiNumber = self:componentToNumber(strSub)
    if fOk~=true then
      tResult = uiNumber
    else
      table.insert(astrComponents, uiNumber)
      tResult = astrComponents
    end
  end

  -- Does the list contain at least one version number?
  if table.maxn(astrComponents)==0 then
    fOk = false
    tResult = string.format("Invalid version: the string '%s' contains no version components.", strVersion)
  end

  return fOk, tResult
end



function version_resolver:getCleanString(strVersion)
  local fOk = true
  local tResult = nil


  fOk,tResult = self:convertStringToList(strVersion)
  if fOk==true then
    local strCleanVersion = table.concat(tResult, ".")
    tResult = strCleanVersion
  end

  return fOk, tResult
end



function version_resolver:getBestMatch(strVersionConstraint, astrVersions)
  local fOk = true
  local tResult = nil


  print("constraint: " .. strVersionConstraint)
  print("versions: " .. table.concat(astrVersions, ", "))


  fOk = false
  tResult = "This function is not ready yet!"

  return fOk, tResult
end


return version_resolver
