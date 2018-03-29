local util = require"libs/util"
local syntax = require"libs/syntax"
local oop = require"libs/oo"
local discordia = require"discordia"


local Object = oop.Object

Command = Object:extend{
    __info = "tourmaline/command",
    __commands = {},
    __aliases = {},
}

function Command:extend( options )
    options = syntax.kv_resolve(options)
    options.__commands = nil
    options.__aliases = nil
    options.__call = self.__call
    return Object.extend(self, options)
end

function Command:initial( options )
    options = syntax.kv_resolve(options)
    options.__commands = nil
    options.__aliases = nil
    if options.module == nil then 
        options.module = T.NONE 
    end
    util.merge(self, options)
    
    atc()
        assert(isFunction(self.body) and isString(self.name) and isString(self.prefix))
    reset()

    self._logger = discordia.Logger(3, "!%F %T")
    self.nonce = self.prefix .. self.name
    self.__commands[self.nonce] = self
    for _, alias in ipairs(self.aliases or {}) do 
        self.__aliases[self.prefix..alias] = self.nonce
    end
end

function Command:info( ... )
    self._logger:log(3, ...)
end

function Command:warn( ... )
    self._logger:log(2, ...)
end

function Command:error( ... )
    self._logger:log(1, ...)
end

function Command:__call(msg, args)
    if not self._userId then self._userId = msg.client.user.id end
    local executed = false;
    if self:valid(msg) then
        local success, err = pcall(self.body,self,msg,syntax.std(args))
        executed = success
        if not success then 
            self:error("had runtime-error: %s", err)
            msg:reply{
                embed = {
                    title = ("%s%shad runtime error"):format(self.nonce, self.plugin and (" from %s "):format(self.plugin) or ""),
                    description = err,
                    color = 0xFF4A32,
                    timestamp = os.date"!%FT%T"
                }
            }
        end
    end
    return executed
end

-- simple predicate checker
local function validate(val, i, predicate, msg,self)
    return val and predicate(msg,self)
end
function Command:valid( msg )
    local v= msg.author.id ~= self._userId
    local conds = self.conds

    if conds and v then
        v = util.foldWithArgs(conds.predicates,validate,v,msg,self)
    end
    return v
end

Command:static"find"
function Command.find(txt)
    local s,e =  txt:find("^%S+")
    if s then 
        return txt:sub(s,e), txt:sub(e+1)
    end
end

Command:static"messageCreate"
function Command.messageCreate( msg )
    local cmdName, args = Command.find(msg.content)
    local alias = Command.__aliases[cmdName]
    local executed;
    local cmd = Command.__commands[cmdName]

    if not cmd and alias then 
        cmd = Command.__commands[alias]
    end

    if cmd then
        executed = cmd(msg, match)
    end
end

return Command