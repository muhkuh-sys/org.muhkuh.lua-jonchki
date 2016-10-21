-- This test checks the Configuration class.

-- Add the src folder to the search list.
package.path = package.path .. ";src/?.lua;src/?/init.lua"


-- Create the logger.
local Logger = require 'Logger'
local cLogger = Logger()

-- Create a configuration object and read the settings from 'demo.cfg'.
local SystemConfiguration = require 'SystemConfiguration'
local cSysCfg = SystemConfiguration()
cSysCfg:parse_configuration('demo.cfg')
cLogger:setSystemConfiguration(cSysCfg)

-- Read the project configuration.
local ProjectConfiguration = require 'ProjectConfiguration'
local cPrjCfg = ProjectConfiguration()
cPrjCfg:parse_configuration('jonchkicfg.xml')
cLogger:setProjectConfiguration(cPrjCfg)

local ResolverChain = require 'resolver.resolver_chain'
local cResolverChain = ResolverChain('default')
cResolverChain:set_repositories(cPrjCfg.atRepositories)

-- Read the artifact configuration.
local ArtifactConfiguration = require 'ArtifactConfiguration'
local cArtifactCfg = ArtifactConfiguration()
cArtifactCfg:parse_configuration_file('org.muhkuh.tools-flasher_cli.xml')

-- Create the exact resolver.
local ResolverExact = require 'resolver.exact'
local tResolver = ResolverExact('default-exact')

-- Resolve all dependencies.
tResolver:setResolverChain(cResolverChain)
tResolver:resolve(cArtifactCfg)
local atArtifacts = tResolver:get_used_artifacs()
for strGA,tV in pairs(atArtifacts) do
  print(strGA, tV:get())
end

cLogger:write_to_file('jonchkilog.xml')
