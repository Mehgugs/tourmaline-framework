tourmaline = require "framework"

local Test = tourmaline.Command:extend{
    prefix = "::",
    plugin = plugin._name,
    src = plugin._file
}

local function help(cmd, msg)
    msg:reply{
        embed = {
            title = "Help",
            description = "Helpful help!"
        }
    }
end

Test:new{
    body = help,
    name = "help"
}