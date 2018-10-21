local T = require "framework"
local discordia = require  "discordia"
local Logger = discordia.Logger(3, "!%F %T")
      Logger:log(3, "Initializing Tourmaline")
T(function(client)
    local fs = require"fs"
    local TOKEN = "Bot " .. assert(fs.readFileSync("./TOKEN"))
    client:on('ready', function() 
        Logger:log(3, "Online!")
    end)
    return TOKEN
end)