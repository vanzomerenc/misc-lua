---@module bind
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren

assert(..., 'Do not use as main file; use require from different file')
local _id = select(2, ...) or ...


local error = error
local select = select
local type = type

local require = require 'relative_require' (...)

local memoize = require('.memoize')


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



local function bind_at_least_one(f, x, ...)

	local function f_x(...) return f(x, ...) end
	
	if select('#', ...) == 0 then return f_x
	else return bind_at_least_one(f_x, ...)
	end
end

bind_at_least_one = memoize(bind_at_least_one, 'allowgc')



local function bind_n(n, f, ...)

	if select('#', ...) < n then return bind_at_least_one(bind_n, n, f, ...)
	else return bind_at_least_one(f, ...)
	end
end



local function bind(fst, ...)

	if fst == nil then return bind
	elseif select('#', ...) == 0 then return bind_at_least_one(bind, fst)
	elseif type(fst) == 'function' then return bind_at_least_one(fst, ...)
	elseif type(fst) == 'number' then
		if fst > 0 then return bind_n(fst, ...)
		else return select(1, ...)
		end
	else error('attempt to bind arguments to non-callable object', 2)
	end
end



return bind