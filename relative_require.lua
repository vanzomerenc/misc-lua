---@module relative_require
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren
--
-- @usage
--
-- local require_relative = require 'relative_require' (...)
-- require_relative 'foo.baz'	-- behaves like standard require 'foo.baz'
-- require_relative '.foo.baz'	-- requires 'foo.baz' from the same directory as the current module
-- require_relative '^.foo.baz	-- requires 'foo.baz' from the directory above the one containing the current module
-- require_relative '^.^.foo.baz'	-- requires 'foo.baz' from the directory two above the one containing the current module
-- require_relative '@.foo.baz'	--requires 'foo.baz' from the directory sharing this module's name

assert(..., 'Do not use as main file; use require from different file')
local _pkg = (...):match("(.-)[^%.]+$")
local _id = select(2, ...) or ...


local concat, insert = table.concat, table.insert
local error = error
local gmatch, gsub, sub = string.gmatch, string.gsub, string.sub
local pcall = pcall
local require = require
local type = type


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



return function(calling_module)

	if type(calling_module) ~= 'string' then error('expected string, received '..type(calling_module)) end

	local parent_package = {}
	for str in gmatch(calling_module, '([^.]*%.)') do insert(parent_package, str) end

	return function(modname)
	
		if type(modname) ~= 'string' then error('expected string, received '..type(modname)) end

		local first_char = sub(modname, 1, 1)
		
		if first_char == '.' then
		
			modname = concat(parent_package, '', 1, #parent_package)..sub(modname, 2)
		
		elseif first_char == '@' then
		
			modname = calling_module..sub(modname, 2)
		
		elseif first_char == '^' then
	
			local last_index = 1
		
			for a, b in gmatch(modname, '()%^%.()') do
			
				if a == last_index then last_index = b else break end
			end
			
			local parent_level = #parent_package - ((last_index - 1) / 2)
			
			modname = concat(parent_package, '', 1, parent_level)..sub(modname, last_index)
		end
		
		return require(modname)
	end
end