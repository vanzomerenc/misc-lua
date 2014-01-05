---
-- (c) 2014 Christopher VanZomeren
-- See LICENSE
--
-- memoize.lua

assert(..., 'Do not use as main file; use require from different file')
local _pkg = (...):match('(.-)[^%.]+$')
local _id = select(2,...) or ...


local debug_getinfo = debug and debug.getinfo

local assert = assert
local pairs = pairs
local select = select
local setmetatable = setmetatable
local stderr = io.stderr
local type = type
local unpack = unpack or table.unpack

local weak = require(_pkg..'weak')


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



local function warn(msg) stderr:write(_id, ': WARNING: ', msg, '\n') end



local is_value_type = {boolean = true, string = true, number = true, ['nil'] = true}



-- Used to store nil as a hash or result

local de_nil, re_nil
do
	local null = {}
	function de_nil(x) if x == nil then return null else return x end end
	function re_nil(x) if x == null then return nil else return x end end
end



-- Used to provide the number of parameters of a function to the default hash function

local function get_nparams() return end

local warn_debug_getinfo_fail = 'unused arguments to memoized functions will still be used for caching if no hash function is supplied'

if debug_getinfo then
	if debug_getinfo(function()end, 'u').nparams then
		function get_nparams(a_function)
			local info = debug_getinfo(a_function, 'u')
			if not info.isvararg then return info.nparams end
		end
	else warn 'debug.getinfo does not include nparams'; warn(warn_debug_getinfo_fail)
	end
else warn 'debug.getinfo does not exist'; warn(warn_debug_getinfo_fail)
end



-- This is our memoization function.

local function memoize(a_function, a_hash_function)
		
	-- The default hash function uses the arguments of the function as the hash.
	-- The list of these arguments is automatically truncated/expanded if debug.getinfo exists
	-- and a_function does not use varargs.
	
	if not a_hash_function then
		local num_args = get_nparams(a_function)
		function a_hash_function(...) return unpack({...}, 1, num_args) end
	end

	local cache
	local parent_nodes_of
	
	local result_of
	local explicit_result_of
	
	local make_result_table
	
	
	
	-- Adds a node to the set of parents of another node or of a result
	
	local function add_parent_node(x, node)
	
		local parents_of_x = parent_nodes_of[x]
		
		if not parents_of_x then
			parents_of_x = {}
			parent_nodes_of[x] = parents_of_x
		end
		
		parents_of_x[node] = true
	end
	
	
	
	-- Gets the result of a cache node or, if there is none, caches and returns the result of the function call.
	
	local function get_or_save_result(node, ...)
	
		local result = explicit_result_of[node]
	
		if result == nil then result = result_of[node] end
		
		if result == nil then
		
			result = a_function(...)
			result_of[node] = de_nil(result)
			
			-- We want one, and only one, unique result usable as a key for each series of hashes.
			-- This means we cannot let the garbage collector eat a chain of cache nodes if the result
			-- at the end of the chain is an uncollectable table, function, userdata, et c. However, the same does not
			-- apply to value-type data as it is already unique, usable as a key, and never collectable.
			
			if not is_value_type[type(result)] then add_parent_node(result, node) end
		end
		
		return re_nil(result)
	end
	
	
	
	-- Recursively finds the node for each argument in ...
	
	local function find_node_in(this_node, next_arg, ...)

		if  next_arg == nil and select('#', ...) == 0 then return this_node
	
		else
		
			next_arg = de_nil(next_arg)

			local next_node = this_node[next_arg]
			
			if not next_node then
			
				next_node = weak 'kv'
				this_node[next_arg] = next_node
				add_parent_node(next_node, this_node)
			end
	
			return find_node_in(next_node, ...)
		end
	end
	
	
	
	local a_memoized_function_mt = {__metatable = 'memoized function'}
	local a_memoized_function = setmetatable({}, a_memoized_function_mt)
	
	
	
	-- Replaces the result table with one that allows collection of unused results,
	-- copying all key-value pairs to the new table
	
	function a_memoized_function:allowgc()
	
		assert(self == a_memoized_function)
		make_result_table = function() return weak 'kv' end
		
		local new_results = make_result_table()
		
		if result_of then for k,v in pairs(result_of) do new_results[k] = v end end
		result_of = new_results
		
		return self
	end
	
	
	
	-- Replaces the result table with one that does not allow collection of unused results,
	-- copying all existing key-value pairs to the new table
	
	function a_memoized_function:preventgc()
	
		assert(self == a_memoized_function)
		make_result_table = function() return {} end
		
		local new_results = make_result_table()
		
		if result_of then for k,v in pairs(result_of) do new_results[k] = v end end
		result_of = new_results
		
		return self
	end
	
	
	
	-- Sets the result for a series of arguments
	
	function a_memoized_function:remember(...)
	
		assert(self == a_memoized_function)
	
		local args = {...}
	
		return function(result)
		
			explicit_result_of[find_node_in(cache, a_hash_function(unpack(args)))] = result
			return self
		end
	end
	
	
	
	-- Removes result for a series of arguments
	
	function a_memoized_function:forget(...)
	
		assert(self == a_memoized_function)
	
		local node = find_node_in(cache, a_hash_function(...))
		
		explicit_result_of[node] = nil
		
		local result_of_node = result_of[node]
		
		if result_of_node ~= nil then
			parent_nodes_of[result_of_node] = nil
			result_of[node] = nil
		end
		
		return self
	end
	
	
	
	-- Clears cached results
	
	function a_memoized_function:forgetCached()
	
		assert(self == a_memoized_function)
		
		result_of = make_result_table()
		
		return self
	end
	
	
	
	-- Clears results that have been set explicitly
	
	function a_memoized_function:forgetExplicit()
	
		assert(self == a_memoized_function)
		
		explicit_result_of = {}
		
		return self
	end
	
	
	-- Clears all results
	
	function a_memoized_function:forgetAll()
	
		assert(self == a_memoized_function)
		
		self:forgetCached()
		self:forgetExplicit()
		cache, parent_nodes_of = weak 'kv', weak 'k'
		
		return self
	end
	
	
	
	-- __call metamethod so our memoized function can be treated as a function
	
	function a_memoized_function_mt:__call(...)
	
		assert(self == a_memoized_function)
		return get_or_save_result(find_node_in(cache, a_hash_function(...)), ...)
	end
	
	
	
	--
	
	return a_memoized_function:preventgc():forgetAll()
end



return memoize