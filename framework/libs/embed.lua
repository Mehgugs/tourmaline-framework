local util = require"util"
local syntax = require"syntax/syntax"
local oop = require"oop/oo"
local discordia = require"discordia"

local utf8 = syntax.utf8
local Color = discordia.Color
local Base = oop.Object:extend():mix('oop/callable')

local insert = table.insert

local Embed = Base:extend{
    __info = 'tourmaline/embed',
    __defaults = {},
    __props = {},
    __schemes = {
        image = {
            http = true, 
            https = true, 
            attachment = true
        }
    }
} 
local rawset = rawset
getmetatable(Embed).__newindex = function(self,k,v)
    if self.__props[k] then 
        self:addprop(k, v)
    else 
        return rawset(self, k, v)
    end
end

function Embed:extend(t) 
    return Base.extend(self, {__defaults = t, __len = self.__len})
end

function etype(t, v, f) 
    if type(v) ~= t then error(("Type of argument%s%s must be a %s"):format(f and " " or "",f or "",t), 3) end 
    return true
end

function eassert(v, msg, ...)
    return v or error(msg:format(...),3)
end

function Embed:initial(o)
    self._embed = { fields = {}, type = 'rich'}
    self._fieldlen = 0 
    self._capacity = 6000
    self._history = {}
    self:merge(self.__defaults)
    if o then 
        return self:merge(o)
    end
end 

function Embed:getMaxFields() return 25 end 

function Embed:spaceAvailable()
    return eassert(self._capacity >= 0, "Embed content was too large (%d chars over limit of 6000 chars).", -self._capacity)
end 

function Embed:merge(obj)
    for field, value in pairs(obj) do 
        self[field](self, value)
    end
    return self
end

local utf8len = utf8.len
local function utf8_len(str) 
    local s, l = pcall(utf8len,str)
    if s then return l 
    else return false
    end 
end

function Embed:addToHistory(property)
    insert(self._history, {self._capacity, property})
    return self
end

function Embed:fix() 
    if self._capacity < 0 then 
        local new = Embed() 
        for _, event in ipairs(self._history) do
            local cap, prop = event[1], event[2]
            if cap >= 0 then 
                Embed[prop](new, self._embed[prop])
            else break end
        end
        return new
    else return self end
end

Embed:static"prop"
function Embed:prop(name)
    self.__props[name] = true
end
Embed:static"addprop"
function Embed:addprop(k, v)
    return rawset(self, k, function(s, ...) 
        v(s, ...)
        return s:addToHistory(k)
    end)
end

Embed:prop"title"
function Embed:title(str)
    if etype('string', str, 1) then 
        local len = eassert(utf8_len(str), "String %q was not utf8 encoded text!", str)
        if eassert(len <= 256, "title must be 256 characters or less!") then
            self._embed.title = str
            self._capacity = self._capacity - len
            return self
        end
    end
end

Embed:static"titleLength"
Embed:static"contentLength"
function Embed.titleLength(str) return str:sub(1,256) end
function Embed.contentLength(str) return str:sub(1,2048) end

Embed:prop"description"
function Embed:description(str)
    if etype('string', str, 1) then 
        local len = eassert(utf8_len(str), "String %q was not utf8 encoded text!", str)
        if eassert(len <= 2048, "description must be 2048 characters or less!") then
            self._embed.description = str
            self._capacity = self._capacity - len
            return self
        end
    end
end

Embed:prop"url"
function Embed:url(u) 
    if etype('string', str, 1) then 
        if eassert(syntax.is_url(u), "Input was not a valid url: %q", u) then 
            self._embed.url = u 
            return self  
        end
    end
end

Embed:prop"color"
function Embed:color( ... )
    local c = Color(...)
    self._embed.color = c.value
    return self
end

Embed:prop"timestamp"
function Embed:timestamp( ust )
    ust = ust == "now" and nil
    self._embed.timestamp = ust and os.date("!%FT%T",ust) or os.date"!%FT%T"
    return self
end

Embed:prop"footer"
function Embed:footer(f)
    etype('table', f, 1)
    local text, icon_url = f.text, f.icon_url 
    if etype('string', text, 'footer.text') then
        local len = eassert(utf8_len(text), "String %q was not utf8 encoded text!", text)
        if icon_url ~= nil then 
            local scm = syntax.parse_url(icon_url).scheme
            eassert(Embed.__schemes.image[scm], "Input was not a valid url: %q", icon_url)
        end
        if eassert(len <= 2048, "footer.text must be 2048 characters or less!") then
            self._embed.footer = {}
            self._embed.footer.text = text 
            self._embed.footer.icon_url = icon_url
            self._capacity = self._capacity - len
            return self
        end
    end
end

function Embed:textfooter( v )
    return self:footer{ text = v}
end

function Embed:_image(i)
    etype('table', i)
    local url = i.url
    local parsed = syntax.parse_url(url)
    local scm = parsed.scheme
    if eassert(Embed.__schemes.image[scm], "Input was not a valid url: %q", url) then 
        self._embed.image = {url = url}
    end
    --optional fields 
    local width, height = i.width, i.height 
    if type(width) == 'number' and type(height) == 'number' then 
        self._embed.image.width = width 
        self._embed.image.height = height
    end
    return self
end

Embed:prop"image"
function Embed:image( url_or_img )
    return type(url_or_img) == 'string' and self:_image{url = url_or_img} or self:_image(url_or_img)
end

function Embed:_thumbnail(i)
    etype('table', i)
    local url = i.url
    local parsed = syntax.parse_url(url)
    local scm = parsed.scheme
    if eassert(Embed.__schemes.image[scm], "Input was not a valid url: %q", url) then 
        self._embed.thumbnail = {url = url}
    end
    
    return self
end

Embed:prop"thumbnail"
function Embed:thumbnail( url_or_img )
    return type(url_or_img) == 'string' and self:_thumbnail{url = url_or_img} or self:_thumbnail(url_or_img)
end

Embed:prop"author"
function Embed:author(v)
    etype('table', v)
    local name = v.name 
    if etype('string', name) then
        local len = eassert(utf8_len(name), "String %q was not utf8 encoded text!", name)
        if eassert(len <= 256, "Embed footer.text must be 2048 characters or less!") then
            self._embed.author = {}
            self._embed.author.name = name 
            self._capacity = self._capacity - len
        end
        local u = v.url 
        if u and syntax.is_url(u) then 
            self._embed.author.url = u
        end
        local icon_url = v.icon_url
        local parsed = syntax.parse_url(icon_url) 
        local scm = parsed.scheme
        if Embed.__schemes.image[scm] then 
            self._embed.author.icon_url = icon_url
        end
    end
    return self
end

function Embed:authorname(n) return self:author{name = n} end 

Embed:prop"field"
function Embed:field(f)
    etype('table', f)
    local name, value = f.name, f.value
    if etype('string', name) and etype('string', value) then 
        local len_name =  eassert(utf8_len(name), "String %q was not utf8 encoded text!", name)
        local len_value = eassert(utf8_len(value), "String %q was not utf8 encoded text!", value)
        if eassert(len_name <= 256 and len_value <= 1024, "Embed field content was too large!") and eassert(self._fieldlen < 25, "Embed field array is at capacity!") then 
            local field = {
                name = name,
                value = value,
                inline = not not f.inline
            }
            insert(self._embed.fields, field)
            self._capacity = self._capacity - len_name - len_value
            self._fieldlen = self._fieldlen + 1
        end
    end
    return self 
end

function Embed:inlinefield(f) etype('table', f) return self:field{name = f.name, value = f.value, inline = true} end

function Embed:fields(fs) for _, field in ipairs(fs) do self:field(field) end return self end

function Embed:getAtFieldLimit() return self._fieldlen == self.MaxFields end

function Embed:getObject()
    self:spaceAvailable()
    return self._embed 
end

function Embed:getJson()
    return encode(self.Object)
end

function Embed:__len() return self:fix():getObject() end

return Embed