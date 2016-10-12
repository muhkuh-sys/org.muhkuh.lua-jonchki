-- This test checks the Configuration class.

local Configuration = require 'Configuration'

-- Create a configuration object and read the settings from 'demo.cfg'.
cConfiguration = Configuration('demo.cfg')

print(cConfiguration)
