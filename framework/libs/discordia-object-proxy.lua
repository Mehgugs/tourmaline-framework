local util = require"util"
local syntax = require"syntax/syntax"
local oop = require"oop/oo"
local discordia = require"discordia"
local isObject = discordia.class.isObject

local insert, remove, unpack = table.insert, table.remove, table.unpack

local Log = require"oop/loggable-object"

local DiscordiaProxy = Log:extend
{
    __info = "tourmaline/discordia-proxy"
}
local idx = DiscordiaProxy.__index
local obj = 'obj'
function DiscordiaProxy:__index(k)
    local m = rawget(self, obj)
    if m and m[k] then 
        if self._perms[k] then
            local perms = type(self._perms[k]) == 'table' and self._perms[k] or self._perms
            if type(m[k]) == 'function' then
                rawset(self, k, function(self,...) return DiscordiaProxy:new(m[k](m,...), perms) end)
                return self[k]
            else
                return  DiscordiaProxy:new(m[k], perms)
            end
        else
            return error("Violated permissions: obj.".. k.." is not allowed!")
        end
    end
    return idx(self, k)
end

function DiscordiaProxy:initial( obj, perms )
    self._perms = perms
    self.__info = self.__info .. '/' .. (obj.id or tostring(obj))
    self.obj = obj
end

function DiscordiaProxy:new (obj, perms)
    if not isObject(obj) then return obj, perms end
    local new = setmetatable({}, self)
    new:initial(obj, perms)
    return new
end

return DiscordiaProxy