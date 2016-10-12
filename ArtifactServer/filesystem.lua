--- A repository driver for a filesystem.
-- The repository module provides an abstraction to a number of different
-- repositories. The real work is done by drivers. This is the driver
-- providing access to a repository on a filesystem.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the table for the module.
local repository_driver = {}

-- The "Hash" module abstracts the hash functions like SHA1, SHA384 etc. .
repository_driver.tHash = require("Hash")


--- Initialize the repository driver object.
-- The internal luasocket states are created. The root path in the file
-- system is set.
-- @param atConfiguration A key/value list for the driver configuration.
--        Possible configuration keys for this driver are:
--        strRootPath: The full path to the root of the repository.
-- @return The function returns 2 values. If an error occured, it returns
--         false and an error message as a string. On success it returns true
--         and an empty string.
function repository_driver:init(atConfiguration)
  local fOk = true
  local astrMsg = {}

  self.tHttp = require("socket.http")
  self.tLtn12 = require("ltn12")

  for strKey,tValue in pairs(atConfiguration) do
    if strKey=="strRootPath" then
      self.strRootPath = tValue
    else
      table.insert(astrMsg, string.format("Unknown key: '%s'.", strKey))
      fOk = false
    end
  end

  return fOk, table.concat(astrMsg, " ")
end
