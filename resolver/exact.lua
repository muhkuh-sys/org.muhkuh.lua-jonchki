--- A resolver which accepts exact matches only.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local ResolverExact = class()


--- Initialize a new instance of the exact resolver.
-- @param strID The ID identifies the resolver.
function ResolverExact:_init(strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.Version = require 'Version'
end



function ResolverExact:get_id()
  return self.strID
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function ResolverExact:__tostring()
  local strRepr = string.format('ResolverExact(id="%s")', self.strID)

  return strRepr
end


return ResolverExact
