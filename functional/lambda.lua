---@module lambda
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren
--
-- @usage
-- local lambda = require(pkgname..'lambda')
-- local f = lambda 'x => x^2'
-- f(3)		-- returns 9

assert(..., 'Do not use as main file; use require from different file')
local _id = select(2, ...) or ...


local error = error
local find = string.find
local gsub = string.gsub
local load = load
local loadstring = loadstring
local pcall = pcall
local setfenv = setfenv
local setmetatable = setmetatable
local type = type

local require = require 'relative_require' (...)

local memoize = require '.memoize'


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



if setfenv and not pcall(load, '') then

	local rawload = load

	function load(ld, source, mode, env)
	
		if type(ld) == 'string' then
	
			local chunk, err = loadstring(ld, source)
			if chunk then setfenv(chunk, env) end
			return chunk, err
		
		else
		
			return rawload(ld, source, mode, env)
		end
	end
end



local lambda_env
do
	local function lambda_access_error(_, k)
	
		error('\''..k..'\' is not accessible from lambda expression', 2)
	end
	
	lambda_env = setmetatable({}, {__index = lambda_access_error, __newindex = lambda_access_error})
end



local function lambda(expr)

	if not find(expr, '=>', 1, true) then expr = '_=>'..expr end

	local source = 'return function('..gsub(expr, '=>', ')return ')..' end;'
	
	local chunk, err = load(source, expr, 't', lambda_env)
	if not chunk then error(err, 2) end
	
	return chunk()
end



return memoize(lambda, 'allowgc', 1)