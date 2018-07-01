--- Policy base class
-- The base class for all policies.
-- @author doc_bacardi@users.sourceforge.net
-- @copyright 2017 Christoph Thelen

-- Create the configuration class.
local class = require 'pl.class'
local Policy = class()

function Policy:_init(cLog, strID)
  local tLogWriter = require 'log.writer.prefix'.new(string.format('[Policy%s] ', strID), cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.Version = require 'Version'
end



function Policy:get_id()
  return self.strID
end



function Policy:select_version_by_constraints(atVersions, strConstraint)
  error('This is the function "select_version_by_constraints" in the Policy base class. Overwrite the function!')
end

return Policy
