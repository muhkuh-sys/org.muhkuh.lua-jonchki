--- The report class.
-- The report class collects all information for a report.
-- @author cthelen@hilscher.com
-- @copyright 2017 Hilscher Gesellschaft für Systemautomation mbH


-- Create the class.
local class = require 'pl.class'
local Report = class()



function Report:_init(cLogger)
  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  -- lxp is used to write the report in XML format.
  self.lxp = require 'lxp'

  -- Set the default filename.
  self.strFileName = 'jonchkireport.xml'

  -- Use the logger.
  self.tLogger = cLogger

  -- No data yet.
  self.atData = {}
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
      self.tLogger:fatal('[REPORT]: The element "%s" in the path "%s" points to a leaf.', strPathElement, strKey)
      error('Internal error!')
    end

    -- Move to the new node.
    tNode = tNewNode
  end

  -- Create the new key/value pair.
  local strOldValue = tNode[strLeaf]
  if strOldValue~=nil then
    if strOldValue==strValue then
      self.tLogger:warn('[REPORT]: Setting existing key "%s" to the same value of "%s".', strKey, tostring(strValue))
    else
      self.tLogger:fatal('[REPORT]: Try to change existing key "%s" from "%s" to "%s".', strKey, strOldValue, tostring(strValue))
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
          self.tLogger:fatal('[REPORT]: Redefining attribute "%s" in path "%s".', strAttribute, strKey)
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

  -- Convert the entries to an XML document.
  self:to_xml(self.atData, tXml)

  -- Write all data to the output file.
  local tFile = io.open(self.strFileName, 'w')
  -- Write the XML declaration and the link to the stylesheet.
  tFile:write('<?xml version="1.0" encoding="UTF-8"?>\n')
  tFile:write('<?xml-stylesheet type="text/xsl" href="jonchkireport.xsl"?>\n')
  -- Write the complete XML data.
  tFile:write(tXml:__tostring('', '\t'))
  tFile:close()
end


return Report
