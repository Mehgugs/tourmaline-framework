local AudioSource = require "sound/sounds"

local Soundcloud = AudioSource:extend
{
    __info = "tourmaline/soundcloud-audio-source",
    __source = "soundcloud",
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

function Soundcloud:initial(url, soxEffects)
    self._url = url
    self._effects = soxEffects
end

function Soundcloud:processYTDL( chunk )
    return chunk:match"%C+"
end

return Soundcloud
