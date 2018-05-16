local util = require"util"
local oop = require"oop/oo"
local discordia = require"discordia"
local meta = require"meta"

local cwd = process.cwd

local fs = require"fs"
local pathj = require"pathjoin".pathJoin
local dump = require"pretty-print".dump
local reqgen = require"require"
local scandir = fs.scandirSync

local insert = table.insert

local Logger = discordia.Logger(3, "!%F %T")
               discordia.extensions.string()

local Plugin = oop.Object:extend{
    __info = "tourmaline/plugin",
    __plugins =  {},
    __root = "plugins",
    __reqcache = {}
}


function Plugin:initial( options )
    self._file = options.file
    self._folder = options.folder
    self._name = options.name
    self.require = newrequire
    self.__plugins[options.file] = self
    self.events = {}
end

function Plugin:path( ... )
    return pathj(cwd(), self._folder, ...)
end

function Plugin:onUnload(f) self.unloads = f end

function Plugin:unload(  )
    if self.unloads then 
        self:unloads()
    end
    for name, fn in pairs(self.events) do 
        self.__client:removeListener(name, fn)
    end
end

Plugin:static"setClient"
function Plugin.setClient( c )
    Plugin.__client = c
end

function Plugin:on( name, fn )
    self.events[name] = fn 
    return self.__client:on(name, fn)
end

function Plugin:once( name, fn )
    self.events[name] = fn 
    return self.__client:once(name, fn)
end

local function readPlugin(files, plugins, file)
    local path = pathj(cwd(), file)
    insert(files, path) 
    local name = file:match("([^/\\]*)%.lua$")
    plugins.names[name] = path
    plugins.files[path] = name
end

local function readAll(location, files, plugins)

    location = location or Plugin.__root
    local root = pathj(cwd(),location)
    for file, type in scandir(root) do
        local at = location..'/'..file
        if type == 'directory' then
            readAll(at, files, plugins)
        elseif type == 'file' and file:endswith".lua" then
            readPlugin(files, plugins, at)
        end
    end
end

local function loadPlugin(filepath)
    local folder = filepath:match("^.+[\\/]")
    local name = filepath:match("([^/\\]*)%.lua$")
    local logname = ("plugin:%s"):format(name)

    --create a require function localized to the plugin's dir
    if not Plugin.__reqcache[filepath] then 
        local r,m = reqgen(filepath)
        Plugin.__reqcache[filepath] = r
    end
    local newrequire = Plugin.__reqcache[filepath]

    --create a plugin object to put in their env with useful data/helper functions
    --needed to create full paths when not using require to load resources.
    if not Plugin.__plugins[filepath] then
        Plugin:new{
            file = filepath,
            folder = folder,
            name = name,
            require = newrequire
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
        local loaded, module = loadPlugin(file)
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
    local loaded, plg = loadPlugin(plugin._file)
    plugin._state = loaded
    if loaded then
        Logger:log(3,"Reloaded plugin:%s@%s",plugin._name, plugin._file)
        if plugin.onReload then
            pcall(plugin.onReload,plugin,msg)
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