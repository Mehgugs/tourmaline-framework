local tourmaline = require "framework"
local qs = require"querystring"
local util = tourmaline.util
local utf8 = tourmaline.syntax.utf8

local insert, concat= table.insert, table.concat

local Test = tourmaline.Command:extend{
    prefix = "::",
    plugin = plugin._name,
    src = plugin._file,
    __pipes = true,
}

local Provider = tourmaline.Command:extend{
    prefix = "::",
    plugin = plugin._name,
    src = plugin._file,
    __pipes = true,
    __middle = true,
}

local Standalone = tourmaline.Command:extend{
    prefix = "::",
    plugin = plugin._name,
    src = plugin._file,
    __pipes = false,
}

local Processor = tourmaline.Command:extend{
    prefix = '',
    plugin = plugin._name,
    src = plugin._file,
    __pipes = true,
    __pipeonly = true,
}

local insert, concat = table.insert, table.concat

local function help(cmd, msg)
    
    local embed = {
            title = "Help!",
            description = "Command List!",
            color = 0xDA2072,
            fields = {}
    }

    for nonce, command in pairs(Test.__commands) do 
        insert(embed.fields, {
            name = nonce .. (command.__pipes and ' (>)' or ''),
            value = command.desc or 'No description :('
        })
    end
    return {
        embed = embed
    }
end



local function rawupper(object)
    if type(object) == 'table' and not object.__ignore then 
        return util.map(util.pair_reducer(object), rawupper)
    elseif type(object) == 'string' then return object:upper();
    else return object
    end
end

local function upper(cmd, msg, object) return rawupper(object) end



local function rawlower(object)
    if type(object) == 'table' and not object.__ignore then 
        return util.map(util.pair_reducer(object), rawlower)
    elseif type(object) == 'string' then return object:lower();
    else return object
    end
end

local function lower(cmd, msg, object) return rawlower(object) end



local function rawreverse(object)
    if type(object) == 'table' and not object.__ignore then 
        return util.map(util.pair_reducer(object), rawreverse)
    elseif type(object) == 'string' then return object:reverse();
    else return object
    end
end

local function reverse(cmd, msg, object) return rawreverse(object) end



function rawrand( object )
    if type(object) == 'string' then
        local data = object
        local len = utf8.len(object)
        for i = 1, len do local r = math.random(1, len)
            data = utf8.sub(data, 1, r-1) .. utf8.sub(data, r+1, len) .. utf8.sub(data ,r,r)
        end
        return data
    elseif type(object) == 'table' then 
        return util.map(util.pair_reducer(object), rawrand)
    else return object
    end
end

local function random(cmd, msg, object) return rawrand(object) end

local function guilds(cmd, msg)
    return msg.client.guilds:toArray()
end

local function where(cmd, msg, object, key, value)
    local pairs = util.filter(object, function(i) return i[key] == value end)
    return {
        embed = {
            title = "Result:",
            description = concat(util.map(pairs, function(i) return i.name end),'\n'),
            color = 0xDA2072,
        }
    }
end

local audioThreads = {};
local activeConnection = {}
local skipped = {}
local function playPlaylist(cmd, msg, url)
    local query = qs.parse(url:match("%?(.*)") or '')
    local uri = url:match("^[^?]+")
    query.v = nil
    url = uri .. "?" .. qs.stringify(query)
    local audioThread = audioThreads[msg.channel.guild.id]

    if not audioThread or coroutine.status( audioThread ) == 'dead' then
        cmd:info(url)
        if audioThread then activeConnection[audioThread] = nil end
        audioThread = coroutine.running(); audioThreads[msg.channel.guild.id] = audioThread
        local ch = msg.client:getChannel("298412191906791426")
        local conn = ch:join()
        activeConnection[audioThread] = conn
        local audio = tourmaline.YT.Mix:new(url, {
            {'gain', '-20'}
        })
        msg:reply("Loading Playlist!")
        audio:getffmpegStream()
        msg:reply(("Playing <%s>!"):format(url))
        while not audio:is_empty() do
            local player = audio:start(conn.pcmPacketLength)
            assert(player and player.__info, "AudioPlayer failed to return a stream.")
            conn:playPCM(player)
            player:close()
            if conn.state == "stopped" and not skipped[audioThread] then break end
            if skipped[audioThread] then skipped[audioThread] = nil end
        end
        return nil;
    else
        msg:reply(("I'm currently playing audio on: %s in this guild."):format(tostring(audioThread)))
    end
end
local function playYoutube( cmd, msg, url )
    url = (url:prefix'>'):suffix'<'
    if url:find("list=", 1, true) then
        return playPlaylist(cmd, msg, url)
    end
    local audioThread = audioThreads[msg.channel.guild.id]
    if not audioThread or coroutine.status( audioThread ) == 'dead' then
        if audioThread then activeConnection[audioThread] = nil end
        audioThread = coroutine.running(); audioThreads[msg.channel.guild.id] = audioThread
        local ch = msg.client:getChannel("298412191906791426")
        local conn = ch:join()
        activeConnection[audioThread] = conn
        local audio = tourmaline.YT:new(url, {
            {'gain', '-20'}
        })
        msg:reply(("Playing <%s>!"):format(url))
        local player = audio:start(conn.pcmPacketLength)
        conn:playPCM(player)
        player:close()
        return nil;
    else
        msg:reply("I'm currently playing audio on:"..tostring(audioThread))
    end
end

local function pipedPlaylist(cmd, msg, effects, url)
    local query = qs.parse(url:match("%?(.*)") or '')
    local uri = url:match("^[^?]+")
    query.v = nil
    url = uri .. "?" .. qs.stringify(query)
    local audioThread = audioThreads[msg.channel.guild.id]
    if not audioThread or coroutine.status( audioThread ) == 'dead' then
        cmd:info(url)
        if audioThread then activeConnection[audioThread] = nil end
        audioThread = coroutine.running(); audioThreads[msg.channel.guild.id] = audioThread
        local ch = msg.client:getChannel("298412191906791426")
        local conn = ch:join()
        activeConnection[audioThread] = conn
        local audio = tourmaline.YT.Mix:new(url, effects)
        msg:reply("Loading Playlist!")
        audio:getffmpegStream()
        msg:reply(("Playing <%s>!"):format(url))
        while not audio:is_empty() do
            local player = audio:start(conn.pcmPacketLength)
            assert(player and player.__info, "AudioPlayer failed to return a stream.")
            conn:playPCM(player)
            player:close()
            if conn.state == "stopped" and not skipped[audioThread] then break end
            if skipped[audioThread] then skipped[audioThread] = nil end
        end
        return nil;
    else
        msg:reply("I'm currently playing audio on:"..tostring(audioThread))
    end
end

local function pipedYoutube( cmd, msg, effects, url )
    url = (url:prefix'>'):suffix'<'
    if url:find("list=", 1, true) then
        return pipedPlaylist(cmd, msg, effects, url)
    end
    local audioThread = audioThreads[msg.channel.guild.id]
    if not audioThread or coroutine.status( audioThread ) == 'dead' then
        if audioThread then activeConnection[audioThread] = nil end
        audioThread = coroutine.running(); audioThreads[msg.channel.guild.id] = audioThread
        local ch = msg.client:getChannel("298412191906791426")
        local conn = ch:join()
        activeConnection[audioThread] = conn
        msg:reply("Piped in these effects:" .. concat(util.map(effects, table.concat, " "), "  "))
        local audio = tourmaline.YT:new(url, effects)
        msg:reply(("Playing <%s>!"):format(url))
        local player = audio:start(conn.pcmPacketLength)
        conn:playPCM(player)
        player:close()
        return nil;
    else
        msg:reply("I'm currently playing audio on:"..tostring(audioThread))
    end
end

local function stopYT(_, msg)
    local audioThread = audioThreads[msg.channel.guild.id]
    if audioThread and coroutine.status( audioThread ) ~= 'dead' then 
        local conn = activeConnection[audioThread]
        conn:stopStream()
        return "Stopped playing audio."
    else
        return audioThread and "Audio playback has finished." or "No audio playing."
    end
end

local function skipYT(_, msg)
    local audioThread = audioThreads[msg.channel.guild.id]
    if audioThread and coroutine.status( audioThread ) ~= 'dead' then 
        local conn = activeConnection[audioThread]
        skipped[audioThread] = true
        conn:stopStream()
        return "Skipped."
    else
        return audioThread and "Audio playback has finished." or "No audio playing."
    end
end

local sandbox = {
    send = true,
    content = true,
    id = true,
    mentions = true,
    author = true
}

local mt = {__index = _G}

local function exec( cmd, msg, str, ... )
    local env = setmetatable({
        msg = proxy:new(msg, sandbox),
        util = tourmaline.util
    }, mt)
    local func = load(str, '🌗', "t", env)
    jit.off(func)

end

local function sox_info(_,msg)
    return tostring(tourmaline.Audio.__sox.Get_Obj_Ref_Count())
end

local function effects(_,_)
    return {}
end

local function bass(_,_, effects, value)
    insert(effects, {'bass', value})
    return effects
end
local function gain(_,_, effects, value)
    insert(effects, {'gain', value})
    return effects
end
local function treble(_,_, effects, value)
    insert(effects, {'treble', value})
    return effects
end

Test:new{
    name = "stop",
    body = stopYT,
    desc = "Stops playing audio."
}

Test:new{
    name = "skip",
    body = skipYT,
    desc = "Skips an audio track."
}

Test:new{
    name = "sox_info",
    body = sox_info,
    desc = "Gets sox debug info."
}

Test:new{
    name = "pyt",
    body = playYoutube,
    __pipe_body = pipedYoutube,
    desc = "Play a youtube url (WIP af)"
}

Provider:new{
    name = "guilds",
    body = guilds,
    desc = "Gets a list of the guilds on this shard."
}

Provider:new{
    name = "effects",
    body = effects,
    __middle = true,
    desc = "Creates a new SoX effects list."
}

Processor:new{
    __middle = true,
    name = "bass",
    body = bass,
    desc = "Adds bass to a SoX effects list."
}

Processor:new{
    __middle = true,
    name = "treble",
    body = treble,
    desc = "Adds treble to a SoX effects list."
}

Processor:new{
    __middle = true,
    name = "gain",
    body = gain,
    desc = "Adds gain to a SoX effects list."
}

Processor:new{
    name = "where",
    body = where,
    desc = "Filters a list"
}

Processor:new{
    name = "where",
    body = where,
    desc = "Filters a list"
}

Test:new{
    name = 'help',
    body = help,
    desc = "Print command list!"
}

Processor:new{
    name = "upper",
    body = upper,
    desc = "Makes input upper case."
}

Processor:new{
    name = "lower",
    body = lower,
    desc = "Makes input lower case."
}

Processor:new{
    name = "random",
    body = random,
    desc = "Randomizes input."
}

Processor:new{
    name = "reverse",
    body = reverse,
    desc = "Reverses input."
}

Processor:new{
    name = "b",
    body = rawb,
    desc = "yes."
}