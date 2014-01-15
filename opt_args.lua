---@module opt_args
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren

assert(..., 'Do not use as main file; use require from different file')
local _pkg = (...):match("(.-)[^%.]+$")
local _id = select(2, ...) or ...


local select = select
local type = type
local unpack = table.unpack or unpack


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



local function get_opt_args(patterns, ...)

	local last_patt_index, last_arg_index, matches = 0, 0, {}

	while last_arg_index < select('#', ...) and last_patt_index < #patterns do
	
		local next_arg_index = last_arg_index + 1
		local arg = select(next_arg_index, ...)
		local found_match
	
		while last_patt_index < #patterns and not found_match do
		
			local next_patt_index = last_patt_index + 1
			local pattern = patterns[next_patt_index]
			local type_patt = type(pattern)
			
			if type_patt == 'string' then found_match = type(pattern) == arg
			elseif type_patt == 'function' then found_match = pattern(arg)
			end
			
			last_patt_index = next_patt_index
		end
		
		matches[last_patt_index] = found_match and arg
		last_arg_index = next_arg_index
	end
	
	return matches
end



return get_opt_args