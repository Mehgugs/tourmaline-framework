local create = function(cls,...) return cls:new(...) end
return require"oop/oo".Object:extend {
    extend = function(base, t)
        local sub = t or {}
        sub.__base = base
        return setmetatable(newObject(sub), {__index = base, __call = create})
    end
}