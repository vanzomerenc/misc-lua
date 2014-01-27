---@module opt_args
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren
-- 
-- This will be replaced with a more flexible and general solution at some point

assert(..., 'Do not use as main file; use require from different file')
local _id = select(2, ...) or ...


local error = error
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
	
		for next_patt_index = last_patt_index+1, #patterns do
		
			local pattern = patterns[next_patt_index]
			local type_of_patt = type(pattern)
			
			if type_of_patt == 'string' then found_match = type(pattern) == arg
			elseif type_of_patt == 'function' then found_match = pattern(arg)
			else return error('expected string or function in argument pattern; received '..type_of_patt)
			end
			
			if found_match then
			
				last_patt_index = next_patt_index
				break
			end
		end
		
		matches[last_patt_index] = found_match and arg
		last_arg_index = next_arg_index
	end
	
	return unpack(matches)
end



return get_opt_args
