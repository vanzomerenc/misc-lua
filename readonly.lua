---
-- (c) Christopher VanZomeren
-- See license included with this program
--
-- readonly.lua
--
-- used to provide a readonly interface of a table

assert(..., 'Do not use as main file; use require from different file')
local _pkg = (...):match("(.-)[^%.]+$")
local _id = select(2, ...) or ...


local assert = assert
local error = error
local pairs, ipairs = pairs, ipairs
local select = select
local setmetatable = setmetatable
local stderr = io.stderr
local tostring = tostring
local type = type

local weak = require(_pkg..'weak')


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



local function warn(msg) stderr:write(_id, ': WARNING: ', msg, '\n') end



local target_of = weak 'k'



local readonly_mt = {__metatable = 'readonly'}



local is_usable_type = {boolean = true, string = true, number = true, ['nil'] = true, table = true}

local is_immutable_type = {boolean = true, string = true, number = true, ['nil'] = true}



local function isreadonly(t)

	local type_t = type(t)
	assert(is_usable_type[type_t])
	
	return is_immutable_type[type_t] or target_of[t] ~= nil
end



local function readonly(_, t)

	if isreadonly(t) then return t
		
	else

		local readonly_t = setmetatable({}, readonly_mt)
		
		target_of[readonly_t] = t

		return readonly_t
	end
end



function readonly_mt.__call(t) error('Attempt to call '..tostring(target_of[t])..' through readonly interface.', 2) end

function readonly_mt.__index(t, k) return target_of[t][k] end
function readonly_mt.__newindex(t) error('Attempt to modify '..tostring(target_of[t])..' through readonly interface.', 2) end

function readonly_mt.__pairs(t)
	local iter = pairs(target_of[t])
	return function(t, ...) return iter(target_of[t] or t, ...) end
end
function readonly_mt.__ipairs(t)
	local iter = ipairs(target_of[t])
	return function(t, ...) return iter(target_of[t] or t, ...) end
end

function readonly_mt.__len(t) return readonly(nil, #(target_of[t])) end
function readonly_mt.__unm(t) return readonly(nil, -(target_of[t])) end
function readonly_mt.__tostring(t) return tostring(target_of[t]) end

function readonly_mt.__add(t1, t2) return readonly(nil, (target_of[t1] or t1) + (target_of[t2] or t2)) end
function readonly_mt.__sub(t1, t2) return readonly(nil, (target_of[t1] or t1) - (target_of[t2] or t2)) end
function readonly_mt.__mul(t1, t2) return readonly(nil, (target_of[t1] or t1) * (target_of[t2] or t2)) end
function readonly_mt.__div(t1, t2) return readonly(nil, (target_of[t1] or t1) / (target_of[t2] or t2)) end
function readonly_mt.__mod(t1, t2) return readonly(nil, (target_of[t1] or t1) % (target_of[t2] or t2)) end
function readonly_mt.__pow(t1, t2) return readonly(nil, (target_of[t1] or t1) ^ (target_of[t2] or t2)) end

function readonly_mt.__concat(t1, t2) return readonly(nil, (target_of[t1] or t1) .. (target_of[t2] or t2)) end

function readonly_mt.__eq(t1, t2) return (target_of[t1] or t1) == (target_of[t2] or t2) end
function readonly_mt.__lt(t1, t2) return (target_of[t1] or t1) < (target_of[t2] or t2) end
function readonly_mt.__le(t1, t2) return (target_of[t1] or t1) <= (target_of[t2] or t2) end



local _test = readonly(_,{1})
if not pairs(_test)(_test) then warn('pairs does not respect metamethods; iteration of readonly objects will not work') end
if not ipairs(_test)(_test, 0) then warn('ipairs does not respect metamethods; iteration of readonly objects will not work') end
if #_test ~= 1 then warn('\'#\' operator does not respect metamethods; use on readonly objects will not work') end



return setmetatable({isreadonly = isreadonly}, {__call = readonly, __metatable = 'callable'})