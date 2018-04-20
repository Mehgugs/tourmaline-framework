function string:count(p)
    local c = 0; for _ in self:gmatch(p) do c = c+1 end return c;
end

function string:fmtCheck(...)
    return self:count('%%s') == select('#',...)
end

function string:properNoun()
	return self:gsub("^%l", string.upper)
end

function string:startswith( s )
    return self:sub(1, #s) == s
end

function string:endswith( s )
    return self:sub(-#s) == s
end

function string:suffix (pre)
    return self:startswith(pre) and self:sub(#pre+1) or self
end

function string:prefix (pre)
    return self:endswith(pre) and self:sub(1,-(#pre+1)) or self
end

local matches =
{
  ["^"] = "%^";
  ["$"] = "%$";
  ["("] = "%(";
  [")"] = "%)";
  ["%"] = "%%";
  ["."] = "%.";
  ["["] = "%[";
  ["]"] = "%]";
  ["*"] = "%*";
  ["+"] = "%+";
  ["-"] = "%-";
  ["?"] = "%?";
  ["\0"] = "%z";
}
function string:escape_lua_pattern(s)
  return (s:gsub(".", matches))
end

local util = {}

function util.merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            util.merge(t1[k] or {}, v)
        else
            t1[k] = v
        end
    end
    return t1
end

local insert = table.insert
function util.mergeLists(l1, l2)
    for _, v in ipairs(l2) do 
        insert(l1, v)
    end
end

function util.foldWithArgs( l, f, a,...)
    for k, v in ipairs(l) do
        a = f(a,k,v,...)
    end
    return a
end

function util.reduce(f, a, t,...)
    local meta = getmetatable(t)
    local iterate = meta and meta.__iter or ipairs
    for k, v in iterate(t) do
        a = f(a,v,k,...)
    end
    return a
end


local prmt = {__iter = pairs}
function util.pair_reducer( t )
    return setmetatable(t, prmt)
end


local function compose2(f,fnext)
    return function(...) return fnext(f(...)) end
end

function util.compose( ... )
    local funcs = {select(2,...)}
    return util.reduce(compose2, (...),funcs)
end

local mapreduction = function(state, value, index, func, ...) state[index] = func(value, ...); return state end
function util.map( list, func, ... )
    local state = {}
    return util.reduce(mapreduction, state, list, func, ...)
end

local filterreduction = function( state, value, index, func) if func(value) then insert(state, value) end return state end
function util.filter( list, func, state )
    state = state or {}
    return util.reduce(filterreduction, state, list, func)
end

local filterreduction = function( state, value, index, func) if func(value) then insert(state, {index,value}) end return state end
function util.filtered_pairs( list, func, state )
    state = state or {}
    return util.reduce(filterreduction, state, list, func)
end


return util