local qs = require"querystring"
local spawn = require('coro-spawn')
local split = require('coro-split')
local parse = require('url').parse
local fs = require"fs"
local insert,format = table.insert,string.format
local unpack = table.unpack

local Log = require"oop/loggable-object"

local Sox = require "sound/sox"


local AudioSource = Log:extend
{
    __info = "tourmaline/generic-audio-source",
    __stream_config = {
        '-g',
        '--no-warnings',
        '--no-playlist'
    },
    __sox = Sox
}

function AudioSource:initial(url, soxEffects)
    self._url = url
    self._effects = soxEffects
end

function AudioSource:getffmpegStream(  )
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
            if data then stream = data end
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
  
    split(readstdout, readstderr, child.waitExit)
    self._cache = stream
    return stream
end

function AudioSource:start( blocksize ,samplerate, channels )
    self._sox = Sox:new(self._cache or self:getffmpegStream(),samplerate or 48000, channels or 2, blocksize, self._effects)
    return self._sox
end

function AudioSource:startraw( blocksize ,samplerate, channels  )
    self._sox = Sox:new(
        self._cache or self:getffmpegStream(),
        samplerate or 48000, 
        channels or 2, 
        blocksize,
        self._effects,
        true
    )
    return self._sox
end

function AudioSource.__defaultProcess( chunk )
    return chunk:match"%C+"
end

function AudioSource:processYTDL(  )
    self:error("[%s] did not implement AudioSource.processYTDL", tostring(self))
end

return AudioSource
