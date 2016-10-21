--- The logger.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH


-- Create the logger class.
local class = require 'pl.class'
local Logger = class()



function Logger:_init()
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- There is no data yet.
  self.cSystemConfiguraion = nil
  self.cProjectConfiguration = nil
end



function Logger:setSystemConfiguration(cSystemConfiguration)
  if self.cSystemConfiguraion~=nil then
    error('Logger: failed to log the system configuration: the element is already present.')
  end

  self.cSystemConfiguraion = cSystemConfiguration
end



function Logger:setProjectConfiguration(cProjectConfiguration)
  if self.cProjectConfiguration~=nil then
    error('Logger: failed to log the project configuration: the element is already present.')
  end

  self.cProjectConfiguration = cProjectConfiguration
end



function Logger:write_to_file(strFileName)
  -- Create a new XML document.
  local tXml = self.pl.xml.new('JonchkiLog')

  -- Append the system configuration block.
  if self.cSystemConfiguraion~=nil then
    tXml:addtag('System')

    self.cSystemConfiguraion:toxml(tXml)

    tXml:up()
  end
  if self.cProjectConfiguration~=nil then
    tXml:addtag('ProjectConfiguration')

    self.cProjectConfiguration:toxml(tXml)

    tXml:up()
  end

  self.pl.file.write(strFileName, self.pl.xml.tostring(tXml, '', '\t'))
end



return Logger
