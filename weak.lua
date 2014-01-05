---
-- (c) Christopher VanZomeren
-- See LICENSE
--
-- weak.lua
--
-- Used to provide tables that do not prevent GC under certain conditions.

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