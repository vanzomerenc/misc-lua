---@module functional
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren

assert(..., 'Do not use as main file; use require from different file')
local _id = select(2, ...) or ...


local error = error
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring

local require = require 'relative_require' (...)


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



local export_whitelist = {

	bind = '@.bind',
	compose = '@.compose',
	filter = '@.filter',
	first = '@.first',
	lambda = '@.lambda',
	map = '@.map',
	memoize = '@.memoize',
	operator = '@.operator',
	reduce = '@.reduce',
	rest = '@.rest',
}

local export, export_mt = {}, {__metatable = 'module'}
setmetatable(export, export_mt)



function export_mt:__index(k)

	local submod_name = export_whitelist[k] or error('\''..tostring(k)..'\' is not a submodule of this module')

	local success, result = pcall(require, submod_name)
	
	export[k] = success and result or error('An error occurred while loading submodule \''..tostring(k)..'\':\n'..tostring(result))
	
	return result
end



return export