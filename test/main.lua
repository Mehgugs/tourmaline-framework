local Tourmaline = require "framework"
local discordia = require  "discordia"
local fs = require"fs"
local TOKEN = "Bot " .. assert(fs.readFileSync("./TOKEN"))
local Logger = discordia.Logger(3, "!%F %T")
local client = discordia.Client()

discordia.storage.client = client


Tourmaline.plugin.setClient(client)
Tourmaline.plugin.loadPlugins()

Logger:log(3, "Initializing Tourmaline")

client:on('ready', function() 
    Logger:log(3, "Online!")
end)

Tourmaline.Command.enrich(client)

client:run(TOKEN)