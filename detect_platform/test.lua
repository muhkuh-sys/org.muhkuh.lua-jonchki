-- Try to detect a set of parameters which define the target platform for a
-- package.
--
--  * The platform should be defined in a way that compiled code from package
--    X runs on platforms in category Y.
--    Example: All 64Bit code from MinGW64 should run on 64Bit windows systems.
--
--  * The LUA interpreter with its version.
--    Is it important to distinguish the normal LUA interpreter and LUAJIT?
--    Examples: "Lua 5.1" or "LuaJit 5.1"


-- LUA and LUAJIT compatibility
--
-- It seems to be possible to use all LUA modules also with LUAJIT.
-- On Ubuntu the module must be in the correct folder, on my system it is
-- /usr/lib/x86_64-linux-gnu/lua/5.1
