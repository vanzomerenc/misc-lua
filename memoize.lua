---@module memoize
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren
--
-- Used to memoize arbitrary functions with single return values.
-- 'Memoized' functions behave similarly to their unmemoized counterparts,
-- but automatically cache results based on either arguments or a supplied
-- hash function.
--
-- @usage
-- local memoize = require 'memoize'
-- local function foo(...) return something end	--an arbitrary function
-- foo = memoize(foo)	--foo is now memoized

-- LDoc does not like some of the things that happen in this file. Be very careful when adding doc
-- comments, or it will probably crash, and almost certainly not output what was intended.

assert(..., 'Do not use as main file; use require from different file')
local _pkg = (...):match('(.-)[^%.]+$')
local _id = select(2,...) or ...


local debug_getinfo = debug and debug.getinfo

local error = error
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



---@local Used to store nil as a hash or result

local de_nil, re_nil
do
	local null = {}
	function de_nil(x) if x == nil then return null else return x end end
	function re_nil(x) if x == null then return nil else return x end end
end



---Used to provide the number of parameters of a function to the default hash function

local function get_nparams(a_function) return end

do
	local warn_debug_getinfo_fail =
'unused arguments to memoized functions will still be used for caching if no hash function is supplied'

	if debug_getinfo then
	
		if debug_getinfo(function()end, 'u').nparams then
		
			function get_nparams(a_function)
			
				local info = debug_getinfo(a_function, 'u')
				if not info.isvararg then return info.nparams end
			end
			
		else
		
			warn 'debug.getinfo does not include nparams'; warn(warn_debug_getinfo_fail)
		end
		
	else
	
		warn 'debug.getinfo does not exist'; warn(warn_debug_getinfo_fail)
	end
end



local -- Placed before comment so LDoc doesn't see it.

---The function returned by `require 'memoize'`
--
-- @param a_function A function or other callable object to memoize
-- @param[opt] a_hash_function An optional function used to transform the arguments to
-- `a_function` when caching. May return one or more values. If not specified, the
-- default for this parameter is a function equivalent to
--
-- `unpack({...}, 1, nparams)`
--
-- where `nparams` is the number of parameters to `a_function`, or `nil` if `a_function` uses
-- varargs (`...`) or if `debug.getinfo` does not exist or does not return parameter information;
--
-- @return `a_memoized_function` (an object representing the memoized function)

function memoize(a_function, a_hash_function)

	if type(a_function) ~= 'function' then
		error('Argument 1 (a_function): expected function; got '..type(a_function))
	end
	
	if a_hash_function == nil then
		local num_args = get_nparams(a_function)
		function a_hash_function(...) return unpack({...}, 1, num_args) end
	end
	if type(a_hash_function) ~= 'function' then
		error('Argument 2 (a_hash_function): expected function; got '..type(a_function))
	end

	local cache = weak 'kv'
	local parent_nodes_of = weak 'k'
	local result_of
	
	local make_result_table
	
	
	
	---Adds a node to the set of parents of another node or of a result
	
	local function add_parent_node(x, node)
	
		local parents_of_x = parent_nodes_of[x]
		
		if not parents_of_x then
			parents_of_x = {}
			parent_nodes_of[x] = parents_of_x
		end
		
		parents_of_x[node] = true
	end
	
	
	
	---Gets the result of a cache node or, if there is none, caches and returns the result of the function call.
	
	local function get_or_save_result(node, ...)
	
		local result = result_of[node]
		
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
	
	
	
	---Recursively finds the node for each argument in (next_arg, ...)
	
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
	
	--I still do not quite understand LDoc.
	
	---Memoized function methods:
	--
	-- @section a_memoized_function
	
	---Behaves like the function used to create it, but returns only a single result
	-- which is cached for future calls.
	--
	-- @name a_memoized_function
	-- @param ... The parameters to the memoized function
	-- @return the first return value of the memoized function

	local a_memoized_function = setmetatable({}, a_memoized_function_mt)
	
	
	
	local function assert_self(self)
		if self ~= a_memoized_function then
			error('First parameter is not self. Check usage of \'.\' and \':\'', 2)
		end
	end
	
	
	
	---Allows garbage collection of unused cached results.
	-- @return `self`
	
	function a_memoized_function:allowgc()
	
		assert_self(self)
		make_result_table = function() return weak 'kv' end
		
		local new_results = make_result_table()
		
		if result_of then for k,v in pairs(result_of) do new_results[k] = v end end
		result_of = new_results
		
		return self
	end
	
	
	
	---Prevents garbage collection of unused cached results. This is the default behavior.
	-- @return `self`
	
	function a_memoized_function:preventgc()
	
		assert_self(self)
		make_result_table = function() return {} end
		
		local new_results = make_result_table()
		
		if result_of then for k,v in pairs(result_of) do new_results[k] = v end end
		result_of = new_results
		
		return self
	end
	
	
	
	---Removes result for a series of arguments
	--
	-- @param ... The series of arguments to forget the result of
	-- @return `self`
	
	function a_memoized_function:forget(...)
	
		assert_self(self)
	
		local node = find_node_in(cache, a_hash_function(...))
		
		local result_of_node = result_of[node]
		
		if not is_value_type[type(result_of_node)] then
		
			parent_nodes_of[result_of_node][node] = nil
		end
		
		result_of[node] = nil
		
		return self
	end
	
	
	
	---Clears all results
	-- @return `self`
	
	function a_memoized_function:forgetAll()
	
		assert_self(self)
		
		cache = weak 'kv'
		parent_nodes_of = weak 'k'
		result_of = make_result_table()
		
		return self
	end
	
	
	
	-- __call metamethod so our memoized function can be treated as a function
	
	function a_memoized_function_mt:__call(...)
	
		assert_self(self)
		return get_or_save_result(find_node_in(cache, a_hash_function(...)), ...)
	end
	
	-- return the memoized function
	
	return a_memoized_function:preventgc()
end



return memoize