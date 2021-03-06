local discordia = require"discordia"
local T = require"framework"

local cfg = plugin:config()
local commands = T.Command.commands
local util = T.util
local Embed = T.Embed
local CoreGroup = T.Command.Group()

local Date, Time = discordia.Date, discordia.Time

local OK = 0x17F65A
local Error = 0xFF4A32

local CoreCommand = T.Command:extend{
    prefix = ";",
    plugin = plugin,
    src = plugin:src(),
    scope = "admin",
    __pipes = false,
    conds = {
        predicates = {
            util.guild_only
        }
    },
    group = CoreGroup
}

CoreGroup:sethelp(
    CoreCommand{
        name = "help",
        body = T.Command.command_help,
        usage = "[query]",
        desc = "Gets command information."
    }
)

local function command_reload(cmd, msg, query)
    if not query then query = cmd.plugin.rawname end
    local result, res = T.plugin.reload(query:trim())
    if result == nil then 
        msg:reply{
            embed = #Embed()
            :title(("plugin %s does not exist!"):format(name))
            :color(Error)
            :timestamp"now"  
        }
    elseif result == true then
        msg:reply{
            embed = #Embed()
            :title(("%s reloaded successfully"):format(query:trim()))
            :color(OK)
            :author{name = ('Responsible Moderator: %s'):format(msg.author.tag), icon_url = msg.author:getAvatarURL()}
            :timestamp"now"
        }
    elseif result == false then
        msg:reply{
            embed = #Embed()
            :title(("%s did not reload!"):format(name))
            :description(res)
            :color(Error)
            :author{name = ('Responsible Moderator: %s'):format(msg.author.tag), icon_url = msg.author:getAvatarURL()}
            :timestamp"now"  
        }
    end
end

local function cleanContent(text)
    return text --verbose but I cba being elegant 
        :gsub('<@(%d+)>', "<@\xE2\x80\x8B%1>")
        :gsub('<@!(%d+)>', "<@!\xE2\x80\x8B%1>")
        :gsub('<@&(%d+)>', "<@&\xE2\x80\x8B%1>")
        :gsub('<#(%d+)>', "<#\xE2\x80\x8B%1>")
        :gsub('<a?(:.+:)%d+>', '%1')
        :gsub('@everyone', "@\xE2\x80\x8Beveryone")
        :gsub('@here', "@\xE2\x80\x8Bhere")
end

local function command_spy(cmd, msg, id)
    if id then 
        local channel = msg.mentionedChannels:iter()() or msg.channel
        local _msg = channel:getMessage(id:trim())
        
        if _msg.oldContent then 
            local times = util.map(util.keys(_msg.oldContent), Date.fromISO)
            table.sort(times, sorter)
            for i, time in ipairs(times) do 
                local ts = time:toISO()
                local content = _msg.oldContent[ts]
                msg:reply{
                    embed = #Embed()
                    :title ("Message Version:" .. i)
                    :timestamp (ts)
                    :description (cleanContent(content):sanitize())
                    :color(0x4287F4)
                }
            end
        else 
            return {embed = #Embed{color = 0x4287F4, description = "Message has not been edited."}}
        end
    end
end

local function command_testDelete(_, msg)
    local h1 = msg:reply('With Cache.lua patch id:')
    local r = msg:reply('DEL')
    h1:setContent(h1.content .. r.id)
    local count = #msg.channel.messages
    coroutine.wrap(function()
        local success = plugin.client:waitFor('messageDelete', 1e6, function(m) return m.id == r.id end)
        return success and msg:reply('Message Delete was called for this delete, id:' .. r.id)
    end)()
    coroutine.wrap(function()
        local success, _, m = plugin.client:waitFor('messageDeleteUncached', 1e6, function(_,m) return m == r.id end)
        return success and msg:reply('Message Delete __Uncached__ was called for this delete, id:'.. m)
    end)()
    r:delete()
    msg:reply('Message Count Delta:  '..(#msg.channel.messages - count))
end

CoreCommand{
    name = "reload",
    body = command_reload,
    usage = "[plugin]",
    desc = "Reloads the specified plugin."
}

CoreCommand{
    name = "spy",
    body = command_spy,
    usage = "[#channel] {id}",
    desc = "Gets information about a message."
}


CoreCommand{
    name = "test-delete",
    body = command_testDelete,
    usage = "",
    desc = ""
}

plugin.client:on('messageDelete', function(m) plugin:info("%s:%s %s", m.channel.id, m.id, m.content) end)