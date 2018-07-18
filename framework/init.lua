local oo = require"./libs/oop/oo"
return {
    syntax = require"./libs/syntax/syntax",
    plugin = require"./libs/plugin",
    Command = require"./libs/command",
    util = require"./libs/util",
    oo = oo,
    Object = oo.Object,
    Logger = require"./libs/oop/loggable-object",
    Deque = require"./libs/oop/deque",
    Callable = require"./libs/oop/callable",
    Bindable = require"./libs/oop/bindable",
    Bandcamp = "./libs/sound/bandcamp",
    YT = require"./libs/sound/youtube",
    Audio = require"./libs/sound/sounds",
    proxy = require"./libs/discordia-object-proxy.lua",
}