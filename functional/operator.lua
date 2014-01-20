---@module operator
-- @author Christopher VanZomeren
-- @copyright (c) 2014 Christopher VanZomeren

assert(..., 'Do not use as main file; use require from different file')
local _pkg = (...):match("(.-)[^%.]+$")
local _id = select(2, ...) or ...


local type = type


local _ENV = {}
if setfenv then setfenv(1, _ENV) end



function call(x, ...) return x(...) end
function index(x, k) return x[k] end

function len(x) return #x end
function unm(x) return -x end

function add(x,y) return x+y end
function sub(x,y) return x-y end
function mul(x,y) return x*y end
function div(x,y) return x/y end
function mod(x,y) return x%y end
function pow(x,y) return x^y end
function concat(x,y) return x..y end

function eq (x,y) return x==y end
function neq(x,y) return x~=y end
function lt (x,y) return x< y end
function le (x,y) return x<=y end
function gt (x,y) return x> y end
function ge (x,y) return x>=y end

function NOT(x) return not x end

function AND (x,y) return x and y end
function OR  (x,y) return x or  y end
function NAND(x,y) return not (x and y) end
function NOR (x,y) return not (x or  y) end
function XOR (x,y) return not (x and y) and (x or  y) end
function XNOR(x,y) return not (x or  y) or  (x and y) end

function exists(x) return x~=nil end



return _ENV