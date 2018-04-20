require "util"
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
    print(str .. (n > 0 and "\27[0m" or ""))
end

local Logger = require"oop/oo".Object:extend
{
    __info = "tourmaline/loggable",
}
:mix("oop/bindable")


function Logger:newLevel( name, color )
    self[name] = self:bindmethod(self.log, name, color)
    return self
end

local function fmtCheck( s, ... )
    return s:count("[^%%]%%") <= select('#',...)
end

function Logger:log( level, color, msg, ... )
    local timeStamp = os.date"!%F %T"
    local preamble = self.__info:suffix"tourmaline/"
    if fmtCheck(msg, ...) then 
        local text = msg:format(...)
        printf("/$magenta;%s$reset;/$magenta;%s$reset;/$%s;%s$reset;> %s", timeStamp, preamble, color, level, text )
    else
        printf("/$magenta;%s$reset;/$magenta;%s$reset;/$%s;%s$reset;> %s", 
            timeStamp, preamble, 'red', level.."-failed",
            ("Problem logging output of: '%s'."):format(tostring(msg))
        )
    end
end

Logger:newLevel("info", "green")
Logger:newLevel("warn", "yellow")
Logger:newLevel("error", "red")
Logger:newLevel("debug", "blue")

return Logger