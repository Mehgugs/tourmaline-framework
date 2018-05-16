--TODO: unfinished module
local Log = require"oop/loggable-object"
local Deqeue = require"oop/deqeue"

local AudioPlayer = Log:extend
{
    __info = "tourmaline/audio-player",
    __resources  = {
        bandcamp= true,
        youtube = true,
        soundcloud = true,
    }
}
:mix(Deqeue)


function AudioPlayer:initial(  )
    Deqeue.initial(self)
    self._thread = nil
    
end

function AudioPlayer:loadSources()
    self.AudioSources = {}
    for source in pairs(self.__resources) do 
        self.AudioSources[source] = require(("sound/%s"):format(source))
    end
end

function AudioPlayer:addItem( url, metadata)
    local src = self:getSource(url, metadata)
    if src then 
        coroutine.wrap (src.getffmpegStream)(src)
        self:pushleft{source = src, metadata = metadata}
    end
end

function AudioPlayer:getSource( url, metadata )
    for name, AudioSource in pairs(self.AudioSources) do
        if AudioSource:valid(url) then 
            return AudioSource:new(url, metadata.effects)
        end
    end
end