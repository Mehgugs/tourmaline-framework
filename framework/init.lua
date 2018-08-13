local oo = require"./libs/oop/oo"
local util = require"./libs/util"
local module = {
    oo = oo,
    plugin = require"./libs/plugin",
    proxy = require"./libs/discordia-object-proxy.lua",
    syntax = require"./libs/syntax/syntax",
    util= util,
        here = util.makeCallback,
    Object = oo.Object,
        Bindable = require"./libs/oop/bindable",
        Callable = require"./libs/oop/callable",
        Deque = require"./libs/oop/deque",
        Logger = require"./libs/oop/loggable-object",
            Command = require"./libs/command",
            Embed = require"./libs/embed",          
}

local mmeta = {}

local function init(self, pre)
    local discordia = require"discordia"
    local client = discordia.Client()
    self.plugin.setClient(client)
    self.plugin.loadPlugins()
    local token = pre(client)
    return client:run(token)
end

function mmeta:__call(pre)
    return coroutine.wrap(init)(self,pre)
end

return setmetatable(module, mmeta)