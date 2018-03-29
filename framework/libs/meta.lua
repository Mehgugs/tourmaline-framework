require "util"

local meta = {}
local atc = {}
local types = {
    string = true,
    ['nil'] = true,
    thread = true,
    ['function'] = true,
    number = true,
    table = true,
    userdata = true,
    boolean = true
}

local oldG = _G

function atc:__index( k )
    if k:startswith"is" and types[k:suffix"is":lower()] then 
        local _type = k:suffix"is":lower()
        self[k] = function(v) return type(v) == _type end
        return self[k]
    else
        return oldG[k]
    end 
end

function meta.autoTypeCheck()
    local env = getfenv(2)
    meta.old = getmetatable(env)
    setmetatable(env, atc)
end

function meta.reset(  )
    setmetatable(getfenv(2), meta.old)
end

local expr = {}

function expr:__index(k)
    self[k] = function(value)
        return kv{k, value}
    end
    return self[k]
end

function meta.express()
    local env = getfenv(2)
    meta.old = getmetatable(env)
    setmetatable(env, expr)
end

function meta.import()
    local env = getfenv(2)
    for k,v in pairs(meta) do 
        env[k] = v
    end
end

return meta

