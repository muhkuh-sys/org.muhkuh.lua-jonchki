-- This test checks the Configuration class.

local SystemConfiguration = require 'SystemConfiguration'

-- Create a configuration object and read the settings from 'demo.cfg'.
cSysCfg = SystemConfiguration('demo.cfg')

print(cSysCfg)
