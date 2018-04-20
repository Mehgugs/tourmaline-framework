local util = require"util"
local syntax = require"syntax/syntax"
local oop = require"oop/oo"
local discordia = require"discordia"

local insert, remove, unpack = table.insert, table.remove, table.unpack

local Log = require"oop/loggableObject"

Command = Log:extend
{
    __info = "tourmaline/command",
    __commands = {},
    __aliases = {},
    __unpackFunc = function(self, msg, args) return self:_body(msg, unpack(args)) end
}

function Command:extend( options )
    options = options or {}
    options.__commands = nil
    options.__aliases = nil
    options.__call = self.__call
    return Log.extend(self, options)
end

function Command:initial( options )
    options.__commands = nil
    options.__aliases = nil
    if options.plugin == nil then 
        options.plugin = "tourmaline/misc"
    end
    util.merge(self, options)
    
    self.nonce = self.prefix .. self.name
    self.__commands[self.nonce] = self
    for _, alias in ipairs(self.aliases or {}) do 
        self.__aliases[self.prefix..alias] = self.nonce
    end

    if self.unpack then self._body = self.body;
        self.body = self.__unpackFunc
    end
    self.__info = self.__info .. "/"..self.name
    self:info(
        "command created."
    )
end


function Command:__call( msg, cinfo)
    local args, wasPipe =  cinfo.pipe or cinfo.args, not not cinfo.pipe
    if wasPipe and self.__pipes then 
        local initialArgs = remove(args, 1)
        
        local succ,acc = self:execute_pipe(msg, initialArgs)
        if succ and self.__middle and #args == 0 then succ = false acc = "Unfinished pipe expression!" end
        if not succ then 
            return self:replyWithErr(msg, acc)
        else
            for i, cmdexpr in ipairs(args) do 
                local command = Command.resolveName(cmdexpr[1]) or Command.resolveName(self.prefix .. cmdexpr[1])
                if command and command.__pipes then 
                    local success; 
                    if command.__middle and i == #args then 
                        success = false 
                        acc = "Unfinished `pipe_expr`!" 
                    else
                        success, acc = command:execute_pipe(msg, {acc, unpack(cmdexpr, 2)}) 
                    end
                    if not success then return command:replyWithErr(msg, acc) end
                end
            end
            if acc then msg:reply(acc) end
        end
    elseif not wasPipe and not self.__pipeonly and not self.__middle then return self:execute(msg, args, false)
    else
        return self:replyWithErr(msg, "Expected `pipe_expr`!")
    end
end

function Command:execute(msg, args)
    if not self._userId then self._userId = msg.client.user.id end
    local executed = false;
    if self:valid(msg) then
        local success, ret = pcall(self.body,self,msg,unpack(args))
        executed = success
        if not success then 
            self:replyWithErr(msg, ret)
        elseif success and ret ~= nil then
            msg:reply(ret) 
        end
    end
    return executed
end

function Command:replyWithErr( msg, err )
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

function Command:execute_pipe(msg, args)
    if not self._userId then self._userId = msg.client.user.id end
    if self:valid(msg) then
        local body = self.__pipe_body or self.body 
        local success, ret = pcall(body,self,msg,unpack(args))
        if not success and self.__verbose then self:error(ret) end
        return success, ret
    end
    return false
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
    local cmdInfo = syntax.command:match(txt)
    return cmdInfo
end


Command:static"resolveName"
function Command.resolveName( txt )
    local alias = Command.__aliases[txt]
    local cmd = Command.__commands[txt]

    if not cmd and alias then 
        cmd = Command.__commands[alias]
    end
    return cmd
end

Command:static"messageCreate"
function Command.messageCreate( msg )
    local info = Command.find(msg.content)
    if info then 
        
        local cmd = Command.resolveName(info.command)

        if cmd then
            executed = cmd(msg, info)
        end
    end
end

Command:static"enrich"
function Command.enrich( discordiaClient )
    discordiaClient:on("messageCreate", Command.messageCreate)
    discordiaClient.__command = Command
end
return Command