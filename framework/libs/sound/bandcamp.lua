local AudioSource = require "sound/sounds"

local Bandcamp = AudioSource:extend
{
    __info = "tourmaline/bandcamp-audio-source",
    __source = "bandcamp",
    __stream_config = 
    {
        '-f',
        'mpeg/bestaudio/best',
        '-g',
        '--no-playlist',
        '--no-warnings',
        '--quiet',
        '--no-check-certificate',
    }
}

function Bandcamp:initial(url, soxEffects)
    self._url = url
    self._effects = soxEffects
end

function Bandcamp:processYTDL( chunk )
    return chunk:match"%C+"
end

local pattern = '^https?://[^.]+%.bandcamp%.com/track/([a-zA-Z0-9-_]+)/?$'
function Bandcamp:valid( url )
    -- body
end


return Bandcamp
