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

getmetatable"".__mod = function(self, t )
    if type(t) == 'table' then return self:format(unpack(t))
    else return self:format(t) end
end

local codeblock = "```%s```"
local langblock = "```%s\n%s\n```"
local bold = "**%s**"
local emphasis =  "*%s*"
local strike = "~~%s~~"
local snippet = "`%s`"

local lpeg = require"lpeg"
lpeg.locale(lpeg)

local modifiers = lpeg.S"`*_~:<>"

function lpeg.gsub (s, patt, repl)
    patt = lpeg.P(patt)
    patt = lpeg.Cs((patt / repl + 1)^0)
    return lpeg.match(patt, s)
end

--cleans a string so that it's discord safe
function string.sanitize(str) 
    return lpeg.gsub(str, modifiers, "\\%0")
end

function string.strip(str) return str:gsub("%^.-;", "") end


function string:codeblock()
    return codeblock:format(self)
end

function string:lang( lang )
    return langblock:format(lang, self)
end

function string:bold(  )
    return bold:format(self:sanitize())
end

function string:emphasis(  )
    return emphasis:format(self:sanitize())
end

function string:strike(  )
    return strike:format(self:sanitize())
end

function string:snippet()
    return snippet:format(self)
end

function string:trim() return self:gsub("^%s*(.-)%s*$","%1",1) end

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
local insert = table.insert 
local running, resume, yield, wrap, status = coroutine.running, coroutine.resume, coroutine.yield, coroutine.wrap, coroutine.status 
local sleep = require"timer".sleep

function util.keys(t) 
    local new = {}
    for k in pairs(t) do insert(new, k) end 
    return new
end

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

function util.fold(l, f, a)
    for k,v in ipairs(l) do 
        a = f(a,v)
    end
    return a
end

function util.filterout(t, elem)
    local new = {}
    for _, v in ipairs(r) do 
        if v ~= elem then 
            insert(new, v)
        end
    end
    return new
end

function util.reduce(f, a, t,...)
    for k, v in ipairs(t) do
        a = f(a,v,k,...)
    end
    return a
end

function util.contains(t, elem)
    for k, v in pairs(t) do 
        if v == elem then return true end
    end
end

local function compose2(f,fnext)
    return function(...) return fnext(f(...)) end
end

function util.compose( ... )
    local funcs = {select(2,...)}
    return util.reduce(compose2, (...),funcs)
end

function util.map( list, func, ...)
    local new = {}
    for k, v in ipairs(list) do 
        new[k] = func(v, ...)
    end
    return new
end

function util.filter( list, func, ... )
    local new = {}
    for k, v in ipairs(list) do 
        if func(v, ...) then insert(new, v) end
    end
    return new
end


function util.str( s, default )
    if s == nil or s == '' then return default else return s end
end

util.proxy = setmetatable({}, {__index = util, __newindex = function() end, __metatable = false})

local function _disjuct(A,B) return function(cmd, msg) return A(cmd, msg) or B(cmd, msg) end end

function util.disjunct(...) 
    local f = _disjuct(...)
    for _, nxt in ipairs{select(3,...)} do 
        f = _disjuct(f, nxt)
    end
    return f
end
function util.negate(A) return function(cmd, msg) return not A(cmd, msg) end end

function util.guild_only(_, msg) return not not msg.guild end

function util.has_required_roles(cmd, msg, scope)
    scope = scope or cmd.scope or "moderation"
    local roles = cmd.plugin:config().roles 
    local member = msg.member
    if not roles[scope] then return false end 
    for _, id in ipairs(roles[scope]) do 
        if not member:hasRole(id) then return false end 
    end
    return true
end

function util.in_correct_channel(cmd, msg, scope)
    scope = scope or cmd.scope or "moderation"
    local channels = cmd.plugin:config().channels[scope]
    local id = msg.channel.id
    return channels and util.contains(channels, id)
end

function util.has_a_required_role(cmd, msg, scope)
    scope = scope or cmd.scope or "moderation"
    local roles = cmd.plugin:config().roles[scope]
    local member = msg.member
    if not roles then return false end
    for _, id in ipairs(roles) do 
        if  member:hasRole(id) then return true end 
    end
    return false
end

function util.has_admin(cmd, msg)
    return util.has_a_required_role(cmd, msg, "admin") or msg.member and msg.member:hasPermission(msg.channel, 0x8)
end

function util.in_guild(gid)
    return function(_, msg) return msg.guild and msg.guild.id == gid end 
end

function util.makeCallback()
    local thread = running() 
    return wrap(function(...) while status(thread) ~= "suspended" do sleep(0) end return assert(resume(thread, ...)) end)
end

local weak_meta = {__mode = "k"}
function util.weak(t)
    return setmetatable(t, weak_meta)
end


return util