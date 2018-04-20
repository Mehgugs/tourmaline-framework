 
 local uv   = require('uv')
local oop  = require"oop/oo"
local remove = table.remove
local unpack = string.unpack -- luacheck: ignore
local concat = table.concat
local rep = string.rep
local yield, resume, running = coroutine.yield, coroutine.resume, coroutine.running
local insert = table.insert
local function onExit() end

local fmt = setmetatable({}, {
	__index = function(self, n)
		self[n] = '<' .. rep('i2', n)
		return self[n]
	end
})

local SoxProcess = oop.Object:extend
{
	__info = "tourmaline/sox-audio-proc",
	__processes = setmetatable({}, {__mode = "v"})
}:mix('oop/bindable')

function SoxProcess:initial(path, rate, channels, blocksize , effects, raw)
	self.__processes[path] = self
	self._raw = raw
	self._ffmpeg = {}
	self._sox = {}

	self._ffmpeg.stdout = uv.new_pipe(false)
	self._sox.stdin = self._ffmpeg.stdout
	self._sox.stdout = uv.new_pipe(false)

	self._ffmpeg.child = uv.spawn('ffmpeg', {
		args = {
			'-reconnect_streamed',
			1,
			'-i', 
			path,
			'-ar', 
			rate, 
			'-ac', 
			channels, 
			'-f', 
			's16le', 
			-- '-blocksize',
			-- 2*blocksize,
			'pipe:1', 
			'-loglevel', 'warning'},
		stdio = {0, self._ffmpeg.stdout, 2},
	}, onExit)

	--verbose but works; sox cant infer the type of audio if it's being piped in/out
	local soxArgs = {
		'-G',
		'-t',
		'raw', --file [t]ype [raw]
		'-e',
		'signed', --[e]ncoding [signed]
		'-b', 
		'16', -- [b]its [16]
		'-r',
		rate, -- sample [r]ate
		'-c',
		channels, -- audio [c]hannels
		'-', --use stdin (the ffmpeg output)
		'-t',
		'raw',
		'-e',
		'signed',
		'-b',
		'16',
		'-r',
		rate,
		'-c',
		channels,
		'-', -- use stdout
	}

	for k,v in ipairs(effects or {}) do 
		for _, eff in ipairs(v) do insert(soxArgs, eff) end
		print(("SoX: added effect '%s'"):format(v[1]))
	end


	self._sox.child = uv.spawn('sox', {
		args = soxArgs,
		stdio = {self._sox.stdin, self._sox.stdout, 2}
	}, onExit)

	self._consumed = { }
	self._buffer = ''
	
end

function SoxProcess:read(n)
	local stdout = self._sox.stdout
	local buffer = self._buffer
	local bytes = self._raw and n * 2 or n

	if not self._eof and #buffer < bytes then

		local thread = running()
		stdout:read_start(function(err, chunk)
			if err or not chunk then
				self._eof = true
				self:close()
				return assert(resume(thread))
			elseif #chunk > 0 then
				buffer = buffer .. chunk
			end
			if #buffer >= bytes then
				stdout:read_stop()
				return assert(resume(thread))
			end
		end)
		yield()

	end

	if #buffer >= bytes then
		self._buffer = buffer:sub(bytes + 1)
		if not self._raw then 
			return buffer:sub(1, bytes)
		else
			local pcm = {unpack(fmt[n], buffer)}
			remove(pcm)
			return pcm
		end
	end
end

function SoxProcess:close()
	self._sox.child:kill()
	self._ffmpeg.child:kill()
	if not self._sox.stdout:is_closing() then
		self._sox.stdout:close()
	end
	if not self._ffmpeg.stdout:is_closing() then
		self._ffmpeg.stdout:close()
	end
end

function SoxProcess:__gc()
	p'Closing SoxProcess; it has been garbage collected.'
	self:close()
end

SoxProcess:static"Get_Obj_Ref_Count"
function SoxProcess.Get_Obj_Ref_Count()
	local c = 0
	for _ in pairs(SoxProcess.__processes) do c = c +1 end
	return c
end
return SoxProcess