--- The report class.
-- The report class collects all information for a report.
-- @author cthelen@hilscher.com
-- @copyright 2017 Hilscher Gesellschaft für Systemautomation mbH


-- Create the class.
local class = require 'pl.class'
local Report = class()



function Report:_init(cLog, strJonchkiPath)
  -- The "penlight" module is used to parse the configuration file.
  local pl = require'pl.import_into'()
  self.pl = pl

  -- lxp is used to write the report in XML format.
  self.lxp = require 'lxp'

  -- Set the default filename.
  self.strFileName = 'jonchkireport.xml'

  -- Use the logger.
  local tLogWriter = require 'log.writer.prefix'.new('[Report] ', cLog)
  local tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )
  self.tLog = tLog

  -- No data yet.
  self.atData = {}

  -- Set the filename for the embedded stylesheet.
  local strXslFileName = pl.path.join(strJonchkiPath, 'doc', 'jonchkireport.xsl')
  local tXsl = nil
  -- Does the file exist?
  if pl.path.exists(strXslFileName)~=strXslFileName then
    tLog.debug('The file "%s" was not found.', strXslFileName)
  else
    local strXsl, strError = pl.utils.readfile(strXslFileName, false)
    if strXsl==nil then
      tLog.debug('Failed to read the file "%s": %s', strXslFileName, tostring(strError))
    else
      -- Read the complete document.
      tXsl, strError = pl.xml.parse(strXsl, false, false)
      if tXsl==nil then
        tLog.debug('Failed to parse the file "%s" as XML: %s', strXslFileName, tostring(strError))
      end
    end
  end
  self.tXsl = tXsl

  if tXsl==nil then
    tLog.debug('Not embedding a stylesheet.')
  end
end



function Report:getFileName()
  return self.strFileName
end



function Report:setFileName(strFileName)
  self.tLog.debug('Set the filename to "%s".', strFileName)
  self.strFileName = strFileName
end



function Report:addData(strKey, strValue)
  local atData = self.atData

  if strKey==nil then
    error('The key must not be empty.')
  end

  -- Start at the root of the document.
  local tNode = self.atData

  -- Split the key in path elements.
  local astrPathElements = self.pl.stringx.split(strKey, '/')
  -- Get the leaf of the path.
  local strLeaf = table.remove(astrPathElements)

  -- Find the node where the key should be created.
  for _,strPathElement in ipairs(astrPathElements) do
    -- Does the path element already exist?
    local tNewNode = tNode[strPathElement]
    if tNewNode==nil then
      -- No, it does not exist yet. Create it now.
      tNewNode = {}
      tNode[strPathElement] = tNewNode
    elseif type(tNewNode)~='table' then
      self.tLog.fatal('The element "%s" in the path "%s" points to a leaf.', strPathElement, strKey)
      error('Internal error!')
    end

    -- Move to the new node.
    tNode = tNewNode
  end

  -- Create the new key/value pair.
  local strOldValue = tNode[strLeaf]
  if strOldValue~=nil then
    if strOldValue==strValue then
      self.tLog.warning('Setting existing key "%s" to the same value of "%s".', strKey, tostring(strValue))
    else
      self.tLog.fatal('Try to change existing key "%s" from "%s" to "%s".', strKey, strOldValue, tostring(strValue))
      error('Internal error!')
    end
  end

  -- Create the new leaf with the data.
  tNode[strLeaf] = strValue
end



function Report:to_xml(tNode, tXml)
  -- Loop over all elements.
  for strKey,tValue in pairs(tNode) do
    local atAttributes = {}
    -- Does the path element contain attributes?
    local iIdx = self.pl.stringx.lfind(strKey, '@')
    if iIdx~=nil then
      -- Separate the path element from the attributes.
      local strAttributes = string.sub(strKey, iIdx+1)
      strKey = string.sub(strKey, 1, iIdx-1)
      -- Get all attributes.
      local astrAttributes = self.pl.stringx.split(strAttributes, '@')
      for _,strAttribute in ipairs(astrAttributes) do
        -- Does the attribute contain a value?
        local strAttributeValue = ''
        local iIdxEq = self.pl.stringx.lfind(strAttribute, '=')
        if iIdxEq~=nil then
          strAttributeValue = string.sub(strAttribute, iIdxEq+1)
          strAttribute = string.sub(strAttribute, 1, iIdxEq-1)
        end
        if atAttributes[strAttribute]~=nil then
          self.tLog.fatal('Redefining attribute "%s" in path "%s".', strAttribute, strKey)
          error('Internal error!')
        end
        atAttributes[strAttribute] = strAttributeValue
      end
    end

    tXml:addtag(strKey, atAttributes)
    if type(tValue)=='table' then
      self:to_xml(tValue, tXml)
    else
      tXml:text(tostring(tValue))
    end
    tXml:up()
  end
end



function Report:write()
  local tXml = self.pl.xml.new('JonchkiReport')

  -- Add the stylesheet.
  local tXsl = self.tXsl
  if tXsl~=nil then
    tXml:set_attrib('xmlns:xsl', "http://www.w3.org/1999/XSL/Transform")
    tXml:add_child(tXsl)
  end

  -- Convert the entries to an XML document.
  self:to_xml(self.atData, tXml)

  -- Write all data to the output file.
  local tFile = io.open(self.strFileName, 'w')
  -- Write the XML declaration and the link to the stylesheet.
  tFile:write('<?xml version="1.0" encoding="UTF-8"?>\n')
  if tXsl==nil then
    tFile:write('<?xml-stylesheet type="text/xsl" href="jonchkireport.xsl"?>\n')
  else
    tFile:write('<?xml-stylesheet type="text/xml" href="#jonchkistyle"?>\n')
  end
  -- Write the complete XML data.
  tFile:write(tXml:__tostring('', '\t'))
  tFile:close()
end


return Report
