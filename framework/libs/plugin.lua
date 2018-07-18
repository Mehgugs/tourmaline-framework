local util = require"util"
local oop = require"oop/oo"
local discordia = require"discordia"
local meta = require"meta"

local cwd = process.cwd

local fs = require"fs"
local pathj = require"pathjoin".pathJoin
local dump = require"pretty-print".dump
local reqgen = require"require"
local decode = require"json".decode
local scandir = fs.scandirSync

local insert = table.insert
local unpack = table.unpack
local Logger = discordia.Logger(3, "!%F %T")
               discordia.extensions.string()

local Plugin = oop.Object:extend{
    __info = "tourmaline/plugin",
    __plugins =  {},
    __root = "plugins",
    __reqcache = {},
    __default_config_loc = ".config"
}


function Plugin:initial( options )
    self._file = options.file
    self._folder = options.folder
    self._name = options.name
    self.require = options.require
    self.module = options.luvit_module
    self.__plugins[options.file] = self
    self._events = {}
    self._sources = {}
    self._unloadable_sources = {}
end

function Plugin:path( ... )
    return pathj(cwd(), self._folder, ...)
end


function Plugin:unload(  )
    if self.onUnload then 
        pcall(self.onUnload, self)
    end
    for name, fns in pairs(self._events) do 
        for _, fn in ipairs(fns) do 
            self.__client:removeListener(name, fn)
        end
    end
    self._events = {}
    for source in pairs(self._unloadable_sources) do 
        self._sources[source] = nil
    end
end
local HadError = {}
function Plugin:_source(path)
    local fs = self:path(path)
    if not fs:endswith(".lua") then fs= fs .. ".lua" end
    local res = assert(loadfile(fs))
    local _env = getfenv(res)
    _env.require = self.require
    _env.plugin = self
    setfenv(res,_env)
    local ret = {pcall(res)}
    local success = table.remove(ret, 1)
    if success then 
        self._sources[path] = ret
        return unpack(ret)
    else
        Logger:log(1, "plugin:%s had error loading source from '%s': %s",self._name,path, ret[1])
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
        Logger:log(2, "plugin:%s has not loaded source '%s' yet, (required files cannot be unloaded this way.)", self._name, path)
    end
end

function Plugin:_fileconfig(path)
    path = path or Plugin.__default_config_loc
    local file = self:path(path)
    return assert(decode(assert(fs.readFileSync(path))))
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

function Plugin:on( name, fn )
    if not self._events[name] then self._events[name] = {} end
    insert(self._events[name], fn)
    return self.__client:on(name, fn)
end

function Plugin:once( name, fn )
    if not self._events[name] then self._events[name] = {} end
    insert(self._events[name], fn) 
    return self.__client:once(name, fn)
end

local function readPlugin(files, plugins, loc, name)
    local path = pathj(loc, "init.lua")
    insert(files, path) 
    plugins.names[name] = path
    plugins.files[path] = name
end

local function readPluginFromDirectory(location, files, plugins, name)
    for file, type in scandir(location) do
        if type == 'file' and file == 'init.lua' then 
            readPlugin(files, plugins, location, name)
        end
    end
end

local function readAll(location, files, plugins)
    local root = pathj(cwd(),location or Plugin.__root)
    for file, type in scandir(root) do
        local at = ("%s/%s"):format(root, file)
        if type == 'directory' then
            readPluginFromDirectory(at, files, plugins, file)
        end
    end
end



local function loadPlugin(name, filepath)
    local folder = filepath:match("^.+[\\/]")
    local logname = ("plugin:%s"):format(name)
    local luvit_module;
    --create a require function localized to the plugin's dir
    if not Plugin.__reqcache[filepath] then 
        local r,m = reqgen(filepath)
        Plugin.__reqcache[filepath] = r
        luvit_module = m
    end
    local newrequire = Plugin.__reqcache[filepath]

    --create a plugin object to put in their env with useful data/helper functions
    --needed to create full paths when not using require to load resources.
    if not Plugin.__plugins[filepath] then
        Plugin:new{
            file = filepath,
            folder = folder,
            name = name,
            require = newrequire,
            luvit_module = luvit_module
        }
    end

    local res, err1 = loadfile(filepath)

    if not res then 
        Logger:log(1,"%s encountered a syntax error: %s",logname,filepath,err1)
        return false, err1
    elseif res and type(res) == 'function' then
        --here we override some components of the env
        local _env = getfenv(res)
        _env.require = newrequire
        _env.plugin = Plugin.__plugins[filepath]
        setfenv(res,_env)
        local success, returns = pcall(res)
        if not success then
            if logname then Logger:log(1,"%s encountered a runtime error: %s",logname,returns) end
            return false,returns
        elseif success then
            if logname then Logger:log(3,"Loaded %s @%s",logname,filepath) end
            return true, returns
        end
    end
end

local function loadPlugins(  )
    Logger:log(3,"Loading plugins from: %s",pathj(cwd(),Plugin.__root))
    local files, plugins = {}, { names = {}, files = {}}
    readAll(_, files, plugins)

    local output, loaded_plugins = {}, {}
    for _, file in ipairs(files) do 
        if not plugins.files[file] then 
            Logger:log(1, "Could not parse %s skipping.", file)
            goto skip
        end
        local loaded, module = loadPlugin(plugins.files[file], file)
        if loaded then 
            local name = plugins.files[file]
            loaded_plugins[name] = Plugin.__plugins[file]

            if module then output[name] = module end
        end
        Plugin.__plugins[file]._state = loaded
        ::skip::
    end
    discordia.storage.loaded_plugins = loaded_plugins
    return output
end

local function reload(name)
    if not discordia.storage.loaded_plugins[name] then
        Logger:log(1,"Tried to reload a non-existant module.",2)
    end
    local plugin = discordia.storage.loaded_plugins[name]
    plugin:unload()
    local loaded, plg = loadPlugin(name, plugin._file)
    plugin._state = loaded
    if loaded then
        Logger:log(3,"Reloaded plugin:%s@%s",plugin._name, plugin._file)
        if plugin.onReload then
            pcall(plugin.onReload,plugin)
        end
        return true,plg
    else
        Logger:log(1,"Failed to reload plugin:%s@%s",plugin._name, plugin._file)
        return false, plg
    end
end

return {
    loadPlugins = loadPlugins,
    reload = reload,
    setClient = Plugin.setClient
}