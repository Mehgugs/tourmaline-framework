local qs = require"querystring"
local spawn = require('coro-spawn')
local split = require('coro-split')
local parse = require('url').parse
local fs = require"fs"
local insert,format = table.insert,string.format
local unpack = table.unpack

local AudioSource = require "sound/sounds"

local Playlist = require"sound/playlist-source"

local oop = require "oop/oo"

local YT = AudioSource:extend
{
    __info = "tourmaline/youtube-audio-source",
    __source = "youtube"
}
function YT:processYTDL(chunk)
    for line in chunk:gmatch('%C+') do
        local q = parse(chunk, true).query
        local mime = q.mime
        if type(mime) == 'string' and mime:find('audio') then
            return line
        end
    end
end

YT:static"Mix"
YT.Mix = Playlist:extend
{
    __info = "tourmaline/youtube-mix-audio-source",
    __source = "youtube-mix"
}

function YT.Mix:processYTDL( chunk )
    return chunk:match"%C+"
end

return YT
