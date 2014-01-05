if _VERSION ~= 'Lua 5.1' then return false end

local debug = debug
local debug_getmetatable = debug.getmetatable
local debug_setmetatable = debug.setmetatable

local error = error

local rawget, rawset = rawget, rawset
local pairs, ipairs = pairs, ipairs
local select = select
local type = type
local unpack = unpack

local _G = getfenv(0)



setfenv(1, {})



_G.table.pack = _G.table.pack or function(...) return {n = select('#', ...), ...} end

_G.table.unpack = _G.table.unpack or _G.unpack

if true then	--HACK
	_G.pairs = function(obj)
		local mt = debug_getmetatable(obj)
		if type(mt) == 'table' then
			local mt_pairs = rawget(mt, '__pairs')
			if type(mt_pairs) == 'function' then return mt_pairs(obj) end
		end
		return pairs(obj)
	end
end

if true then	--HACK
	_G.ipairs = function(obj)
		local mt = debug_getmetatable(obj)
		if type(mt) == 'table' then
			local mt_ipairs = rawget(mt, '__ipairs')
			if type(mt_ipairs) == 'function' then return mt_ipairs(obj) end
		end
		return ipairs(obj)
	end
end

return _G._VERSION