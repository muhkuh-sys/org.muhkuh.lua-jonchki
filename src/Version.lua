--- A version number.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the class.
local class = require 'pl.class'
local Version = class()



function Version:_init()
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()
end



--- Convert a string to a positive integer.
-- This function converts one component of a version from a string to a number.
-- The components of a version are separated by dots ("."). One component must
-- be a positive integer.
-- @param strComponent The string to be converted.
-- @return If an error occured, it returns nil and an error message as a string.
--         If the function succeeded it returns the converted number.
function Version:componentToNumber(strComponent)
  -- Be pessimistic.
  local tResult = nil
  local strError = ''

  -- Try to convert the component to a number.
  local uiNumber = tonumber(strComponent)
  if uiNumber==nil then
    -- Failed to convert the component to a number.
    strError = string.format('"%s" is no number!', strComponent)
  elseif uiNumber<0 then
    -- The component is a negative number. This is invalid!
    strError = string.format('"%s" is negativ!', strComponent)
  else
    -- The component is a positive integer.
    tResult = uiNumber
  end

  return tResult, strError
end



function Version:convertStringToList(strVersion)
  local fOk = true
  local tResult = nil
  local auiComponents = {}


  -- Split the version string by dots.
  local astrComponents = self.pl.stringx.split(strVersion, '.')
  -- Convert all components to numbers.
  for _, strComponent in ipairs(astrComponents) do
    local uiNumber, strError = self:componentToNumber(strComponent)
    if uiNumber==nil then
      fOk = false
      tResult = strError
      break
    else
      table.insert(auiComponents, uiNumber)
    end
  end

  -- Does the list contain at least one version number?
  if table.maxn(auiComponents)==0 then
    fOk = false
    tResult = string.format("Invalid version: the string '%s' contains no version components.", strVersion)
  else
    tResult = auiComponents
  end

  return fOk, tResult
end



function Version:getCleanString(strVersion)
  local fOk = true
  local tResult = nil


  fOk,tResult = self:convertStringToList(strVersion)
  if fOk==true then
    local strCleanVersion = table.concat(tResult, ".")
    tResult = strCleanVersion
  end

  return fOk, tResult
end



function Version:get()
  local strRepr = ''

  if self.atVersion~=nil then
    strRepr = table.concat(self.atVersion, '.')
  end

  return strRepr
end



function Version:set(tVersion)
  local fOk = true
  local strMessage = nil

  -- A parameter of "nil" allows to clear the version.
  if type(tVersion)=='nil' then
    self.atVersion = nil

  elseif type(tVersion)=='string' then
    local fOk, tResult = self:convertStringToList(tVersion)
    if fOk~=true then
      fOk = false
      strMessage = tResult
    else
      self.atVersion = tResult
    end

  elseif type(tVersion)=='table' then
    -- Is this a Version object or a plain version table?
    if type(tVersion.is_a)=='function' and tVersion:is_a(Version)==true then
      self.atVersion = tVersion.atVersion
    else
      local strVersion = table.concat(tVersion, '.')
      local fOk, tResult = self:convertStringToList(strVersion)
      if fOk~=true then
        fOk = false
        strMessage = tResult
      else
        self.atVersion = tResult
      end
    end
  end

  return fOk, strMessage
end



function Version:__tostring()
  return string.format('Version(%s)', self:get())
end



function Version:__len()
  local uiLen

  if self.atVersion==nil then
    uiLen = nil
  else
    uiLen = #self.atVersion
  end

  return uiLen
end


return Version
