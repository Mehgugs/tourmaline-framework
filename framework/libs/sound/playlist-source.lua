local qs = require"querystring"
local spawn = require('coro-spawn')
local split = require('coro-split')
local parse = require('url').parse
local fs = require"fs"
local insert,format = table.insert,string.format
local unpack = table.unpack

local running, yield , wrap, resume = coroutine.running, coroutine.yield, coroutine.wrap, coroutine.resume

local AudioSource = require"sound/sounds"
local Deque = require"oop/deque"
local Sox = require "sound/sox"

local PlaylistSource = AudioSource:extend
{
    __info = "tourmaline/playlisted-audio-source",
    __stream_config = {
        '-g'
    }
}:mix(Deque)

function PlaylistSource:initial( url, soxEffects )
    Deque.initial(self)
    return AudioSource.initial(self, url, soxEffects )
end

function PlaylistSource:getffmpegStream(  )
    self_started = true
    local args = {unpack(self.__stream_config)}
    args[#args+1] = self._url
    local child = spawn('youtube-dl', {
        args = args,
        stdio = {nil, true, true}
    })
  
    local stream
    local function readstdout()
        local stdout = child.stdout
        for chunk in stdout.read do
            local data = self:processYTDL(chunk)
            if data then 
                self:pushleft(data)
                if self._waiting then 
                    local thr = self._waiting
                    self._waiting = nil
                    assert(resume(thr, true))
                end
            end
        end
        if self._waiting then 
            local thr = self._waiting
            self._waiting = nil
            assert(resume(thr, false))
        end
        return pcall(stdout.handle.close, stdout.handle)
    end
  
    local function readstderr()
        local stderr = child.stderr
        for chunk in stderr.read do
            print(chunk)
        end
        return pcall(stderr.handle.close, stderr.handle)
    end
    self._waiting = coroutine.running()
    wrap(split)(readstdout, readstderr, child.waitExit)
    self._cache = yield()
    return self._cache
end

function PlaylistSource:pull()
    local data = self:popright()
    if data then self:info("Pulled item off queue") return data end
end

function PlaylistSource:queued_items()
    return self:count()
end

function PlaylistSource:waitForItem(  )
    self._waiting = running()
    return yield()
end

function PlaylistSource:start( blocksize ,samplerate, channels  )

    if self._started == nil then self:getffmpegStream() end
    local stream = self:pull()
    if stream then 
        return Sox:new(stream,samplerate or 48000, channels or 2, blocksize, self._effects)
    elseif self._cache and not stream then
        self:waitForItem()
        return self:start(blocksize ,samplerate, channels)
    else
        self:error("Could not resolve this url with youtube-dl: %s", self._url)
        return error("",2)
    end
end



function PlaylistSource:startraw( blocksize ,samplerate, channels  )
    if self._started == nil then self:getffmpegStream() end
    local stream = self:pull()
    if stream then 
        return Sox:new(stream,samplerate or 48000, channels or 2, blocksize, self._effects, true)
    elseif self._cache and not stream then
        self._waiting = running()
        yield()
        return self:start(blocksize ,samplerate, channels)
    else
        self:error("Could not resolve this url with youtube-dl: %s", self._url)
        return error("",2)
    end
end

return PlaylistSource