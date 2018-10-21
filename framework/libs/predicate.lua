local util = require"util" 
local Base = require"oop/oo".Object:extend{}:mix('oop/callable')


local Predicate = Base:extend{
    __info = "tourmaline/predicate"
}

function check(t)
    return type(t) == 'object' and getmetatable(t) == Predicate
end

function Predicate:initial(fn)
    self._fn = fn
end 

function Predicate:__call(...)
    return self._fn(...)
end

function Predicate.resolve(self, other)
    local isPred = check(other)
    local isPredSelf = check(self)
    if isPred and not isPredSelf then 
        self, other = other, self 
        isPred, isPredSelf = isPredSelf, isPred
    end 
    if not isPred and type(other) == 'function' then 
        other = Predicate(other)
    else
        return error("Cannot OR a predicate with a non-predicate")
    end
    return self, other
end 

function Predicate:disjunction(other)
    self, other = Predicate.resolve(self, other)
    local A, B = self._fn, other._fn
    return Predicate(function(...) return A(...) or B(...) end)
end

function Predicate:conjuction(other)
    self, other = Predicate.resolve(self, other)
    local A, B = self._fn, other._fn
    return Predicate(function(...) return A(...) and B(...) end)
end

Predicate.__add = Predicate.disjunction
Predicate.__mul = Predicate.conjuction

function Predicate:negate()
    local A = self._fn

    return Predicate(function(...) return not A(...) end)
end

Predicate.__unm = Predicate.negate

function Predicate:implies(other)
    self, other = Predicate.resolve(self, other)
    local A, B = self._fn, other._fn
    return Predicate(function(...) return (not A(...)) or B(...) end)
end

Predicate.__pow = Predicate.implies

Predicate.guild_only = Predicate(function(_, msg) return not not msg.guild end)

Predicate.has_required_roles = Predicate(function(cmd, msg, scope)
    scope = scope or cmd.scope or "moderation"
    local roles = cmd.plugin:config().roles 
    local member = msg.member
    if not roles[scope] then return false end 
    for _, id in ipairs(roles[scope]) do 
        if not member:hasRole(id) then return false end 
    end
    return true
end)

Predicate.in_correct_channel = Predicate(function(cmd, msg, scope)
    scope = scope or cmd.scope or "moderation"
    local channels = cmd.plugin:config().channels[scope]
    local id = msg.channel.id
    return channels and util.contains(channels, id)
end)

Predicate.has_a_required_role = Predicate(function(cmd, msg, scope)
    scope = scope or cmd.scope or "moderation"
    local roles = cmd.plugin:config().roles[scope]
    local member = msg.member
    if not roles then return false end
    for _, id in ipairs(roles) do 
        if  member:hasRole(id) then return true end 
    end
    return false
end)

Predicate.has_admin = Predicate(function(cmd, msg)
    return Predicate.has_a_required_role(cmd, msg, "admin") or msg.member and msg.member:hasPermission(msg.channel, 0x8)
end)

Predicate.variable = {}

function Predicate.variable.in_guild(gid)
    return Predicate(function(_, msg) return msg.guild and msg.guild.id == gid end)
end