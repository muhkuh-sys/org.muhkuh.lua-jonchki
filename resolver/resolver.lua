--- The resolver base class.
-- @author cthelen@hilscher.com
-- @copyright 2016 Hilscher Gesellschaft für Systemautomation mbH

-- Create the configuration class.
local class = require 'pl.class'
local Resolver = class()


--- Initialize a new instance of the exact resolver.
-- @param strID The ID identifies the resolver.
function Resolver:_init(strID)
  self.strID = strID

  -- The "penlight" module is used to parse the configuration file.
  self.pl = require'pl.import_into'()

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.Version = require 'Version'
  
  self.atRepositoryList = nil
  self.atRepositoryByID = nil
  
  self:clear_resolve_tables()
end



function Resolver:clear_resolve_tables()
  -- Create a new resolve table.
  self.atResolvTab = {}
  -- Create a new GA->V table.
  self.atGA_V = {}
end



function Resolver:get_id()
  return self.strID
end



function Resolver:setRepositories(atRepositoryList)
  -- Store the list.
  self.atRepositoryList = atRepositoryList
  
  -- Create a mapping from the ID -> repository driver.
  local atMap = {}
  for _,tRepository in pairs(atRepositoryList) do
    local strID = tRepository:get_id()
    atMap[strID] = tRepository
  end
  self.atRepositoryByID = atMap
end



function Resolver:add_to_ga_v(cArtifact, strSourceID)
  -- Combine the group and artifact.
  local strGA = string.format('%s/%s', cArtifact.tInfo.strGroup, cArtifact.tInfo.strArtifact)

  -- Is the GA already registered?
  local atGA = self.atGA_V[strGA]
  if atGA==nil then
    -- No, register GA now.
    atGA = {}
    self.atGA_V[strGA] = atGA
  end

  -- Is the version already registered?
  local strVersion = tostring(cArtifact.tInfo.tVersion)
  local atV = atGA[strVersion]
  if atV==nil then
    -- No, register the version now.
    atV = {}
    atGA[strVersion] = atV
  end

  -- Add the source ID.
  local atSrcID = atV[strSourceID]
  if atSrcID==nil then
    atSrcID = {}
    atV[strSourceID] = atSrcID
  end
end



function Resolver:search_artifact(tArtifact)
  print(string.format("search for %s/%s/%s", tArtifact.strGroup, tArtifact.strArtifact, tArtifact.tVersion:get()))

  -- Loop over the repository list.
  for _, tRepository in pairs(self.atRepositoryList) do
    local strSourceID = tRepository:get_id()
    print(string.format('  ... in repository %s', strSourceID))
    local tResult, strError = tRepository:get_available_versions(tArtifact)
    if tResult==nil then
      print(string.format('    failed to scan the repository: %s', strError))
    else
      for _, tVersion in pairs(tResult) do
        print(string.format('    %s', tostring(tVersion)))
      end
    end
  end
end



--- Return the complete configuration as a string.
-- @return The configuration as a string. 
function Resolver:__tostring()
  local strRepr = string.format('Resolver(id="%s")', self.strID)

  return strRepr
end



return Resolver
