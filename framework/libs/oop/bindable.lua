local util = require"util"
return require"oop/oo".Object:extend 
{
    __info = "tourmaline/bindable-mixin",
    bindn = function(self, fun, ...)
        local boundArgs = {self, ...}
        return function(...)
          local args = {}
          util.mergeLists(args, boundArgs)
          util.mergeLists(args, {...})
          return fun(table.unpack(args))
        end
    end,
    bindmethod = function(self, fun, ...)
        local boundArgs = {...}
        return function(self,...)
          local args = {}
          util.mergeLists(args, boundArgs)
          util.mergeLists(args, {...})
          return fun(self,table.unpack(args))
        end
    end,
    bind = function(self, fun) return function(...) return fun(self, ...) end end
}