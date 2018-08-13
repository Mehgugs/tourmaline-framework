local create = function(cls,...) return cls:new(...) end
local oo = require"oop/oo"
local newObject = oo.new
return oo.Object:extend {
    extend = function(base, t)
        local sub = t or {}
        sub.__base = base
        return setmetatable(newObject(sub), {__index = base, __call = create})
    end
}