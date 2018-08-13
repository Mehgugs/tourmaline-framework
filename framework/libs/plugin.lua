local util = require"util"
local oop = require"oop/oo"
local discordia = require"discordia"
local meta = require"meta"
local Logger = require"oop/loggable-object"
local cwd = process.cwd

local fs = require"fs"
local util = require"util"
local pathj = require"pathjoin".pathJoin
local dump = require"pretty-print".dump
local reqgen = require"require"
local decode = require"json".decode
local scandir = fs.scandir
local yield, wrap  = coroutine.yield, coroutine.wrap
local makeCallback = util.makeCallback
local stat = fs.stat
local insert = table.insert
local unpack = table.unpack

local Emitter = discordia.Emitter
local log = Logger:extend{__info = "plugins"}:new()
            discordia.extensions.string()

local Plugin = Logger:extend{
    __info = "tourmaline/plugin",
    __manifest = {},
    __plugins =  {},
    __byname = {},
    __root = "plugins",
    _name = "global",
    __reqcache = {},
    __default_config_loc = ".config"
}:mix(Emitter)

discordia.storage.config = {}

local ClientWrapper = oop.Object:extend()

function ClientWrapper:initial(p,c)
    self._plugin = p
    self._client = c
end

for method in pairs(Emitter) do 
    if not method:startswith"__" then 
        ClientWrapper[method] = function(self, ...)
            local pmethod = 'client_'..method
            if self._plugin[pmethod] then 
                self._plugin[pmethod](self._plugin, self._client, ...)
            end
            return self._client[method](self._client, ...)
        end
    end
end

local idx = ClientWrapper.__index 

function ClientWrapper:__index( k )
    local og = idx(self, k)
    if og then return og 
    else
        local v = self._client[k]
        if v and type(v) == 'function' then 
            local new = function(wrapper, ...) return v(wrapper._client, ...) end
            self[k] = new 
            return new
        end
    end 
end

function Plugin:initial( name, file, options )
    Emitter.__init(self)
    self._name = name
    self._file = file
    self._folder = self._file:match("^.+[\\/]")
    self.__plugins[file] = self
    self.__byname[name] = self
    self.__info = self:name()
    self._events = {}
    self._sources = {}
    self._unloadable_sources = {}
    self.require = reqgen(file)
    self._client = ClientWrapper:new(self, self.__client)
end

function Plugin:getRawname() return self._name end
function Plugin:name() return ("plugin/%s"):format(self._name) end
function Plugin:src() return self._file end
function Plugin:path( ... )
    return pathj(cwd(), self._folder or '', ...)
end

function Plugin:output() return self._output end

function Plugin:getClient() return self._client end

local HadError = {}
function Plugin:_source(path)
    local fs = self:path(path)
    if not fs:endswith(".lua") then fs= fs .. ".lua" end
    local res = assert(loadfile(fs))
    local _env = getfenv(res)
    setfenv(res,setmetatable({plugin = self, require =self.require}, {__index =_env}))
    local ret = {pcall(res)}
    local success = table.remove(ret, 1)
    if success then 
        self._sources[path] = ret
        return unpack(ret)
    else
        self:error("had error loading source from '%s': %s",path, ret[1])
        self._sources[path] = HadError
        return nil
    end
end

function Plugin:source(path, u) 
    if u then self:refreshSource(path, true) end
    if self._sources[path] and self._sources[path] ~= HadError then 
        return unpack(self._sources[path])
    elseif self._sources[path] == nil then
        return self:_source(path)
    end
end

function Plugin:unloadableSource(path)
    return self:source(path, true)
end

function Plugin:refreshSource(path, supress)
    self._unloadable_sources[path] = true
    if not self._sources[path] and not supress then 
        self:warn("plugin has not loaded source '%s' yet, (required files cannot be unloaded this way.)", path)
    end
end

function Plugin:_fileconfig(path)
    path = path or self.__default_config_loc
    local file = self:path(path)
    local cfg =  assert(decode(assert(fs.readFileSync(file))))
    discordia.storage.config[self._name] = cfg
    return cfg
end

function Plugin:_storedconfig()
    return discordia.storage.config[self._name]
end

function Plugin:config(path)
    return self:_storedconfig() or self:_fileconfig(path)
end

Plugin:static"setClient"
function Plugin.setClient( c )
    Plugin.__client = c
end

function Plugin:get(name) return self.__byname[name] end

function Plugin:client_on( cli, name, fn )
    self:info('registering an event for %s', name)
    if not self._events[name] then self._events[name] = {} end
    insert(self._events[name], fn)
end

Plugin.client_onSync = Plugin.client_on

function Plugin:client_once( cli, name, fn )
    self:info('registering an event for %s', name)
    if not self._events[name] then self._events[name] = {} end
    insert(self._events[name], fn) 
end



Plugin.client_onceSync = Plugin.client_once

function Plugin:client_removeListener(cli, name, fn)
    self._events[name] = util.filter(self._events[name], function(f) return f ~= fn end)
end

function Plugin:client_removeAllListeners(cli, name, fn)
    self._events[name] = {}
end

function Plugin:load()
    if not self.loaded then
        local res, err1 = loadfile(self._file)
        self._state = not err1
        if type(res) ~= 'function' then 
            self:error("encountered a syntax error: %s",self._file,err1)
            self:unload(true)
            return false, err1
        else
            local _env = getfenv(res)
            setfenv(res,setmetatable({plugin = self, require =self.require}, {__index =_env}))
            local success, returns = pcall(res)
            self._state = success
            if not success then
                self:error("encountered a runtime error: %s",returns) 
                self:unload(true)
                return false,returns
            elseif success then
                self.loaded = true
                self:info("Loaded @%s",self._file)
                self._output = returns
                self:emit('loaded', self)
                return true, returns
            end
        end
    else 
        return self:reload()
    end
end

function Plugin:unload( force )
    if self.loaded or force then 
        for name, fns in pairs(self._events) do 
            for _, fn in ipairs(fns) do 
                self.__client:removeListener(name, fn)
            end
        end
        self._events = {}
        for source in pairs(self._unloadable_sources) do 
            self._sources[source] = nil
        end
        self.loaded = false
        self:emit('unloaded', self)
    end
end

function Plugin:reload()
    self:unload()
    local loaded, returns = self:load()
    if loaded then
        self:info("Reloaded",self._file)
        self:emit('reloaded', self)
        return true, returns
    else
        plugin:error("Failed to reload @%s", self._file)
        return false, nil
    end
end



Plugin:static"loadNew"
function Plugin.readNew(name, location)
    local root = pathj(cwd(),location or Plugin.__root)
    local at = ("%s/%s"):format(root, name)
    local path = ("%s/init.lua"):format(at)
    if not Plugin.__plugins[path] then 
        stat(at, makeCallback())
        local err, stats = yield()
        if err ~= nil then 
            log:error("Tried to load a non-existant plugin '%s'.", name)
            return nil, err
        elseif err == nil and stats.type ~= "directory" then
            log:error("Tried to load a non-existant plugin '%s'.", name)
            return nil, "Found file at plugin location, not folder."
        elseif err == nil and stats.type == "directory" then 
            stat(path, makeCallback())
            local doesnotexit = yield()
            if doesnotexit then 
                log:error("Tried to load a broken plugin '%s'.", name)
                return nil, doesnotexit
            else
                return Plugin:new(name, path)              
            end
        end
    else
        return Plugin.__plugins[path]
    end
end

Plugin:static"loadAll"
function Plugin.loadAll(location)
    local root = pathj(cwd(),location or Plugin.__root)
    log:info("Loading plugins from %q", root)
    scandir(root, makeCallback())
    local err, scanner = yield()
    if err then return nil, err end
    local output = {}
    for file, type in scanner do
        local plg = Plugin.readNew(file)
        if plg then 
            local loaded, returns = plg:load()
            if loaded and returns then 
                output[name] = returns 
            end
        end
    end
    return output
end

Plugin:static"loadNew"
function Plugin.loadNew(name)
    local plg = assert(Plugin.readNew(name))
    if plg then 
        return plg:load()
    end
end

Plugin:static"reloadPlugin"
function Plugin.reloadPlugin(name)
    local plugin = Plugin.__byname[name]
    if not plugin then
        log:error("Tried to reload a non-existant plugin '%s'.", name)
        return nil
    end
    
    return plugin:reload()
end

Plugin:static"plugins"
function Plugin.plugins()
    return pairs(Plugin.__byname)
end

return {
    new = Plugin.loadNew,
    loadPlugins = Plugin.loadAll,
    reload = Plugin.reloadPlugin,
    setClient = Plugin.setClient,
    config = function(...) return Plugin:config(...) end,
    get = function(...) return Plugin.get(Plugin, ...) end,
    plugins = Plugin.plugins
}