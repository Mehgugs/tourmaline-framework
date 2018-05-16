require "util"
local dlogger = require"discordia".Logger(4, "!%F %T")
local colors = { 
    BLACK   = 30,
    RED     = 31,
    GREEN   = 32,
    YELLOW  = 33,
    BLUE    = 94,
    MAGENTA = 35,
    CYAN    = 36,
    WHITE   = 37,
}
local function printf(...)
    local str,n = string.format(...):gsub("($(%w+);)", function(_, color) 
        if colors[color:upper()] then 
            return ("\27[0m\27[1;%im"):format(colors[color:upper()])
        elseif color == 'reset' then
            return "\27[0m"
        else return '' end 
    end)
    return str .. (n > 0 and "\27[0m" or "")
end

local Logger = require"oop/oo".Object:extend
{
    __info = "tourmaline/loggable",
    __levels = {
        debug = 4,
        info  =3,
        warn = 2,
        error = 1
    }
}
:mix("oop/bindable")


function Logger:newLevel( name )
    self[name] = self:bindmethod(self.log, name)
    return self
end

local function fmtCheck( s, ... )
    return s:count("[^%%]%%") <= select('#',...)
end

function Logger:log( level, msg, ... )
    if level == 'debug' and self.__debug ~= true then return end
    local timeStamp = os.date"!%F %T"
    local preamble = self.__info:suffix"tourmaline/"
    local text;
    if fmtCheck(msg, ...) then 
        text =  printf("<$magenta;%s$reset;> %s", preamble, msg:format(...) )
    else
        text = printf("<$magenta;%s$reset;> %s", preamble, 
            ("Problem logging output of: '%s'."):format(tostring(msg))
        )
    end
    return dlogger:log(self.__levels[level], text)
end

Logger:newLevel("info")
Logger:newLevel("warn")
Logger:newLevel("error")
Logger:newLevel("debug")

return Logger