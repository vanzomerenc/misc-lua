---@module weak
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren
--
-- Used to provide tables that do not prevent GC under certain conditions.
--
-- Returns a function with one parameter, `mode`, whose valid values are
-- 
-- `'k'`, `'key'`, `'ephemeron'` for weak keys;  
-- `'v'`, `'value'` for weak values; or  
-- `'kv'`, `'vk'` for weak keys and values
--
-- and which returns an empty table with its metatable set to have the corresponding
-- `__mode`.
--
-- @usage
-- local weak = require(pkgname..'weak')
-- local foo = weak 'k'	-- declares foo as a table with weak keys

local assert = assert
local setmetatable = setmetatable


local _ENV = {}
if setfenv then setfenv(1, {}) end



local k = {__mode = 'k', __metatable = 'ephemeron table'}
local v = {__mode = 'v', __metatable = 'weak value table'}
local kv = {__mode = 'kv', __metatable = 'weak table'}

local mt_of = {
	k = k, v = v, kv = kv, vk = kv,
	
	key = k,
	value = v,
	
	ephemeron = k
}

return function(param)

	assert(param and mt_of[param])

	return setmetatable({}, mt_of[param])
end