local Tourmaline = require "framework"
local discordia = require  "discordia"
local fs = require"fs"
local TOKEN = "Bot " .. assert(fs.readFileSync("./TOKEN"))

local client = discordia.Client()

discordia.storage.client = client


Tourmaline.plugin.setClient(client)
Tourmaline.plugin.loadPlugins()

local colors = { 
    BLACK   = 30,
    RED     = 31,
    GREEN   = 32,
    YELLOW  = 33,
    BLUE    = 34,
    MAGENTA = 35,
    CYAN    = 36,
    WHITE   = 37,
}
local function printf(...)
    local str,n = string.format(...):gsub("($(%w+);)", function(_, color) 
        if colors[color:upper()] then 
            return ("\27[0m\27[1;%im"):format(colors[color:upper()])
        else return '' end 
    end)
    print(str .. (n > 0 and "\27[0m" or ""))
end

printf("$magenta;Initializing Tourmaline")

client:on('ready', function() 
    printf("$magenta;Online!")
    for guild in client.guilds:iter() do 

    end
end)

Tourmaline.Command.enrich(client)

client:run(TOKEN)