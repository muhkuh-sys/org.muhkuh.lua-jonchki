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
  self.strSystemConfiguraion = nil
  self.strProjectConfiguration = nil
end



function Logger:setSystemConfiguration(cSystemConfiguration)
  if self.cSystemConfiguraion~=nil then
    error('Logger: failed to log the system configuration: the element is already present.')
  end

  local tXml = self.pl.xml.new('SystemConfig')
  cSystemConfiguration:toxml(tXml)
  self.strSystemConfiguraion = self.pl.xml.tostring(tXml, '', '\t')
end



function Logger:setProjectConfiguration(cProjectConfiguration)
  if self.cProjectConfiguration~=nil then
    error('Logger: failed to log the project configuration: the element is already present.')
  end

  local tXml = self.pl.xml.new('ProjectConfiguration')
  cProjectConfiguration:toxml(tXml)
  self.strProjectConfiguration = self.pl.xml.tostring(tXml, '', '\t')
end



function Logger:write_to_file(strFileName)
  -- Open a file for writing.
  local tFile = io.open(strFileName, 'w')

  tFile:write('<?xml version="1.0" encoding="UTF-8"?>\n')
  tFile:write('<?xml-stylesheet type="text/xsl" href="jonchkilog.xsl"?>\n')
  tFile:write('<JonchkiLog>')

  if self.strSystemConfiguraion~=nil then
    tFile:write('\t<System>')
    tFile:write(self.strSystemConfiguraion)
    tFile:write('\t</System>')
  end

  if self.strProjectConfiguration~=nil then
    tFile:write(self.strProjectConfiguration)
  end

  tFile:write('</JonchkiLog>')
  tFile:close()
end



return Logger
