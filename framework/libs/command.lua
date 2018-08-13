local util = require"util"
local syntax = require"syntax/syntax"
local oop = require"oop/oo"
local Embed = require"embed"
local discordia = require"discordia"
local lpeg = require"lpeg"
local insert, remove, unpack = table.insert, table.remove, table.unpack

local error_red = 0xFF4A32

local Log = require"oop/loggable-object"
local Base = Log:extend():mix('oop/callable')
local command_types = {
     basic = true -- a command with no pipe expression
    ,producer= true  -- a command which must be in position one of a pipe
    ,transformer = true -- a command whose position can be > 1 and < n
    ,output = true -- a command which must be in position n of a pipe
    ,pipe = true -- a command which must be in a pipe expression
    ,any = true -- basic + pipe
}

Command = Base:extend
{
    __info = "tourmaline/command",
    __commands = {}, --id => obj
    __aliases = {},
    __dmerr = true,
    parser = syntax.qstring,
    __type = "command",
      type = "basic",
}

function Command:extend( options )
    options = options or {}
    options.__commands = nil
    options.__aliases = nil
    options.__help = nil
    options.__call = self.__call
    return Base.extend(self, options)
end

function Command:initial( options )
    options.__commands = nil
    options.__aliases = nil
    options.__help = nil
    util.merge(self, options)
    assert(self.body, "Cannot create command without a function body.")
    self.prefix = self.prefix or ""
    if not self.name then self.name = "";
        self:warn("command was created with no name, using ''.") 
    end
    
    self.nonce = self.prefix .. self.name
    for _, alias in ipairs(self.aliases or {}) do 
        self.__aliases[self.prefix..alias] = self.nonce
    end

    self.__commands[self.nonce] = self
    if self.group then 
        self.group:add(self)
    end

    if self.plugin == nil then 
        local _env = getfenv(3)
        if _env.plugin then 
            self:info("Found plugin %q in enclosing scope; setting as command plugin.", plugin:name())
            self.plugin = _env.plugin 
        end
    end

    self.__info = ("%s/%s%s"):format(self.__info, self.group and self.group.nonce .. "/" or self.plugin and  self.plugin:name() .. "/" or "", self.nonce) --self.__info .. "/" ..(self.name or "")
    
    self:info("command created.")
    if self.usage == nil then 
        self:warn("command documentation is incomplete; `cmd.usage == nil`")
        self.usage = self.nonce
    end
    if self.desc == nil then 
        self:warn("command documentation is incomplete; `cmd.desc == nil`")
        self.desc = ""
    end

    if self.plugin and not self.group then 
        self.plugin:onceSync('unloaded', self:unloaded())
    end
end

function Command:unloaded() return function() return self:destroy() end end

function Command:__call( msg, cinfo)
    if not self._userId then self._userId = msg.client.user.id end
    local args = cinfo.args
    return self:execute(msg, args)
end

function Command:getUsageString()
    return ("%s %s"):format(self.nonce, self.usage)
end

function Command:execute(msg, args)
    local executed = false;
    if self:valid(msg) and args then
        local success, ret = pcall(self.body,self,msg,self.parser:match(args))
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
    local payload, dm = nil, self.__dmerr
    if type(err) == 'table' then 
        payload = err.response
        dm = err.dm or self.__dmerr 
    else 
        payload = self:runtimeError(err)
    end
    if dm then 
        return assert(msg.author:send{embed =  payload})
    else return assert(msg:reply{embed = payload})
    end
end

function Command:runtimeError(err) 
    local key = self.group and self.group.nonce or self.plugin and self.plugin:name()
    return  {
        title = ("%s%shad runtime error"):format(self.nonce,  key and (" from %s "):format(key) or ""),
        description = err:sub(1, 2048),
        color = error_red,
        timestamp = os.date"!%FT%T"
    }    
end

function Command:raiseArgError()
    local help = self.group and self.group:help()
    local key = self.group and self.group.nonce or self.plugin and self.plugin:name()
    return error{
         response = {
            title = ("%s%swas called incorrectly"):format(self.nonce, key and (" from %s "):format(key) or "")
            ,description = "Usage: %s\n%s" % { 
                self.UsageString:snippet() , 
                help or ""
            }
            ,color = error_red
            ,timestamp = os.date"!%FT%T"
        },
        dm = true
    }
end

function Command:execute_pipe(msg, acc, args, from)
    args = type(args) == 'string' and {self.parser:match(args)} or args
    if self:valid(msg) and args then
        local body = self.__pipe_body or self.body 
        local success, ret = pcall(body,self,msg,acc,unpack(args, from or 1))
        if not success and self.__verbose then self:error(ret) end
        return success, ret
    end
    return false
end

function Command:valid( msg )
    local v= msg.author.id ~= self._userId
    local conds = self.conds

    if conds and v then
        for i, predicate in ipairs(conds.predicates) do 
            v = predicate(self, msg)
            if not v then break end
        end
    end
    return not not v
end

function Command:destroy()
    self.__commands[self.nonce] = nil
    if self.group then 
        self.group:remove(self)
    end
    for _, alias in ipairs(self.aliases or {}) do 
        self.__aliases[self.prefix..alias] = nil
    end
end

Command:static"commands"
function Command.commands()
    return pairs(Command.__commands)
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
    Command.__client = discordiaClient
end

Command:static"command_help"
function Command.command_help(cmd, msg, query)
    local group = cmd.group
    if query then
        query = query:trim()
        local ncmd;
        if group then
            ncmd = group:resolve(query)
            if ncmd == nil then 
                ncmd = group:resolve(cmd.prefix .. query) 
            end
        else
            ncmd = Command.resolveName(query)
            if ncmd == nil then 
                ncmd = Command.resolveName(cmd.prefix .. query) 
            end
        end

        if ncmd then 
            local embed = Embed{
                title = ("Command Information for %s"):format(ncmd.nonce),
                fields = {
                    {name = "Description", value = ncmd.desc},
                    {name = "Usage", value = ncmd.UsageString:sanitize():snippet()},
                    
                },
                textfooter = ncmd.plugin and ncmd.plugin:name()
            }
            if cmd.aliases then 
                embed:field{name = "Aliases", value = table.concat(ncmd.aliases, ", "):sanitize():bold()}
            end
            return {embed = #embed}
        else 
            return "Could not find command matching "..query
        end
    elseif not query and group then
        local names = {}
        for nonce in group:commands() do table.insert(names, nonce) end
        table.sort(names, function(i,j) return i:lower() < j:lower() end)
        msg:reply(("%s commands from %s:"):format(#names, group.nonce))
        return table.concat(names, ",  "):codeblock()
    end
end

Command.Group = Base:extend{
    __info = "tourmaline/command-group",
    __groups = {},
    __handlers = {},
    __type = "group",
}

function Command.Group:initial(options)
    options = options or {}
    options.__groups = nil
    util.merge(self, options)
    self.nonce = self.name
    if self.plugin == nil then 
        local _env = getfenv(3)
        if _env.plugin then 
            self:info("Found plugin %q in enclosing scope; setting as group plugin.", _env.plugin:name())
            self.plugin = _env.plugin 
        else
            self:fatal("Can not create a group without a plugin.")
        end
    end
    if not self.nonce then 
        self.nonce = self.plugin:name()
    end
    self.__info = "command-group/" .. self.nonce
    self.__groups[self.nonce] = self
    self.__commands = {}
    if not self.defer then self:addHandler() end

    self.plugin:onceSync('unloaded', self:unloaded())
    if self.command then 
        self.command.group = self 
        self.command.plugin = self.plugin
        self.cmd = Command:extend(self.command)
    end
end

function Command.Group:__call(...) 
    if self.cmd then 
        local new = self.cmd:new(...)
        return new
    end
end

function Command.Group:add(item)
    if Command.__commands[item.nonce] then 
        self.__commands[item.nonce] = item
    end
end

function Command.Group:get(k, v)
    for _, cmd in pairs(self.__commands) do 
        if cmd[k] == v then 
            return cmd
        end
    end
end

function Command.Group:remove(item)
    local nonce = type(item) == 'string' and item or item.nonce
    if Command.__commands[nonce] then
        if self._help == self.__commands[nonce] then
            self._help = nil 
        end 
        self.__commands[nonce] = nil
    end
end

function Command.Group:commands() return pairs(self.__commands) end

function Command.Group:resolve(txt)
    local alias = Command.__aliases[txt]
    local cmd = self.__commands[txt]
    if not cmd and alias then 
        cmd = self.__commands[alias]
    end
    return cmd
end

function Command.Group:_messageCreate(msg)
    local info = Command.find(msg.content)
    if info then 
        local cmd = self:resolve(info.command)

        if cmd then
            executed = cmd(msg, info)
        end
    end
end

function Command.Group:messageCreate() return function(msg) return self:_messageCreate(msg) end end

function Command.Group:addHandler()
    self.handler = self:messageCreate()
    self:info("Registered commands.")
    return self.plugin.client:on('messageCreate', self.handler)
end

function Command.Group:removeHandler()
    self:info("Stopped handling commands.")
    return self.plugin.client:removeListener('messageCreate', self.handler)
end

function Command.Group:_unloaded()
    local cmds = {}
    for nonce, command in self:commands() do
        insert(cmds, command)
    end
    util.map(cmds, Command.destroy)
    self.__groups[self.nonce] = nil
end

function Command.Group:unloaded() return function() return self:_unloaded() end end

function Command.Group:sethelp(cmd)
    self._help = cmd or self.cmd and self.cmd:new{
        name = 'help', 
        body = Command.command_help, 
        usage = "", 
        desc = ""
    }
    self:info("Set %s as help command.", self._help.nonce)
end

function Command.Group:help()
    return self._help and "Use %s for more information" % self._help.nonce
end

Command.Group:static"enrich"

function Command.Group.enrich()
    for _, group in pairs(Command.Group.__groups) do 
        group:removeHandler()
        group:addHandler()
    end
end

function Command.Group.clean()
    for _, group in pairs(Command.Group.__groups) do 
        group:removeHandler()
    end
end



return Command