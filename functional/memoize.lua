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
-- local memoize = require(pkgname..'memoize')
-- local function foo(...) return something end	--an arbitrary function
-- foo = memoize(foo)	--foo is now memoized

assert(..., 'Do not use as main file; use require from different file')
local _id = select(2,...) or ...

local debug
do
	local success, result = pcall(require, 'debug')
	debug = success and result
end

local debug_getinfo = debug and debug.getinfo

local error = error
local pairs = pairs
local setmetatable = setmetatable
local stderr = io.stderr
local type = type

local require = require 'relative_require' (...)

local opt_args = require '^.opt_args'
local weak = require '^.weak'

local vararg = require 'vararg'
local vararg_pack, vararg_range = vararg.pack, vararg.range


local _ENV = {}
local operation = _ENV
if setfenv then setfenv(1, _ENV) end



local function warn(msg) stderr:write(_id, ': WARNING: ', msg, '\n') end



---Used to store nil as a hash or result

local box, unbox
do
	local null, nan = {}, {}
	
	function box(x)
	
		if x == nil then return null
		elseif x ~= x then return nan
		else return x end
	end
	
	function unbox(x)
	
		if x == null then return nil
		elseif x == nan then return 0/0
		else return x end
	end
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
		
			warn 'debug.getinfo does not include nparams'
			warn(warn_debug_getinfo_fail)
			
			function get_nparams()
			
				warn 'debug.getinfo does not include nparams'
				warn(warn_debug_getinfo_fail)
			end
		end
		
	else
	
		warn 'debug.getinfo does not exist'
		warn(warn_debug_getinfo_fail)
		
		function get_nparams()
		
			warn 'debug.getinfo does not exist'
			warn(warn_debug_getinfo_fail)
		end
	end
end



---Adds a node to the set of parents of another node or of a result

local function add_parent_node(parent_nodes_of, x, node)

	local parents_of_x = parent_nodes_of[x]

	if not parents_of_x then
		parents_of_x = {}
		parent_nodes_of[x] = parents_of_x
	end

	parents_of_x[node] = true
end



---Finds the node for a series of arguments stored in a vararg object

local function find_or_create_node_in(this_node, parent_nodes_of, ...)

	for _, next_arg in vararg_pack(...) do
	
		next_arg = box(next_arg)
		local next_node = this_node[next_arg]
		
		if not next_node then
		
			next_node = weak 'kv'
			this_node[next_arg] = next_node
			add_parent_node(parent_nodes_of, next_node, this_node)
		end
		
		this_node = next_node
	end
	
	return this_node
end



local is_value_type = {boolean = true, string = true, number = true, ['nil'] = true}

---Gets the result of a cache node or, if there is none, caches and returns the result of the function call.

local function get_or_save_result(parent_nodes_of, result_of, node, a_function, ...)

	local result = result_of[node]

	if result == nil then

		result = a_function(...)
		result_of[node] = box(result)
	
		-- We want one, and only one, unique result usable as a key for each series of hashes.
		-- This means we cannot let the garbage collector eat a chain of cache nodes if the result
		-- at the end of the chain is an uncollectable table, function, userdata, et c. However, the same does not
		-- apply to value-type data as it is already unique, usable as a key, and never collectable.
	
		if not is_value_type[type(result)] then add_parent_node(parent_nodes_of, result, node) end
	end

	return unbox(result)
end



local cache_of = weak 'k'



local memoize_opt_args = {'string', 'function', 'number'}

local

---The function returned by `require 'memoize'`
--
-- @param a_function A function or other callable object to memoize
-- @param[opt] ... Can be any combination of the following, in the order given:
-- 
-- * `operation:` An operation to perform on the cache of a_function, represented as a string.
-- Defaults to `'reset'`. Valid operations are listed as `operation.\_\_\_\_\_` in this documentation.
-- 
-- * `a_hash_function:` An optional function used to generate hashes or hashable values for caching.
-- If not specified, the default for this parameter is a function equivalent to
--
--         unpack({...}, 1, num_params)
--
-- * `num_params:` A number specifying the number of parameters to consider in the default hash
-- function. If not specified, this number defaults to the number of parameters of `a_function`, or
-- `nil` if `a_function` uses varargs (`...`) or if `debug.getinfo` does not exist or does not
-- return parameter information.
--
-- @return `a_memoized_function` (an object representing the memoized function)

function memoize(a_function, ...)

	if type(a_function) ~= 'function' then
	
		return error('argument 1: expected function; got '..type(a_function))
	end

	local op, a_hash_function, num_params = opt_args(memoize_opt_args, ...)
	
	op = op or 'reset'
	
	
	
	-- if the function is not already memoized, do so
	
	local a_memoized_function = a_function
	
	if not cache_of[a_function] then
	
		num_params = num_params or get_nparams(a_function)
	
		if not a_hash_function then
		
			if num_params then a_hash_function = function(...) return vararg_range(1, num_params, ...) end
			else a_hash_function = function(...) return ... end
			end
		end
		
		local cache = {}
		
		a_memoized_function = function(...)
			
			return get_or_save_result(
				cache.parent_nodes_of,
				cache.result_of,
				find_or_create_node_in(cache.root, cache.parent_nodes_of, a_hash_function(...)),
				a_function,
				...
			)
		end
	
		cache_of[a_memoized_function] = cache
		
		if op == 'allowgc' or op == 'preventgc' then
		
			operation[op](a_memoized_function)
			op = box(nil)
			
		else
		
			preventgc(a_memoized_function)
		
			if op == 'reset' then op = box(nil) end
		end
		
		reset(a_memoized_function)
	end
	
	operation[op](a_memoized_function)
	
	return a_memoized_function
end



-- a private no-op to prevent redundant operations

operation[box(nil)] = function(x) return x end



---used by allowgc/preventgc

local function make_weak_table() return weak 'kv' end
local function make_strong_table() return {} end



---allows garbage collection of unused cached results of `a_function`

operation.allowgc = function(a_function)

	local cache = cache_of[a_function]
	
	local old_result_of, new_result_of = cache.result_of, make_weak_table()
	
	if old_result_of then for k, v in pairs(old_result_of) do new_result_of[k] = v end end
	
	cache.result_of, cache.make_result_table = new_result_of, make_weak_table
	
	return a_function
end



---prevents garbage collection of unused cached results of `a_function`

operation.preventgc = function(a_function)

	local cache = cache_of[a_function]
	
	local old_result_of, new_result_of = cache.result_of, make_strong_table()
	
	if old_result_of then for k, v in pairs(old_result_of) do new_result_of[k] = v end end
	
	cache.result_of, cache.make_result_table = new_result_of, make_strong_table
	
	return a_function
end



---resets the cache of `a_function`

operation.reset = function(a_function)

	local cache = cache_of[a_function]
	
	cache.root, cache.parent_nodes_of, cache.result_of = weak 'kv', weak 'k', cache.make_result_table()
	
	return a_function
end



return memoize
