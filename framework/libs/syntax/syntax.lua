local lpeg = require"lpeg"
local P, S, R, V, C, Ct, Cg, Cb, Cc, Cs, Cf, l = lpeg.P, lpeg.S, lpeg.R, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cb, lpeg.Cc, lpeg.Cs, lpeg.Cf, {} 
lpeg.locale(l)

local function maybe(p) return p^-1 end

local function replacer (patt, repl)
    patt = lpeg.P(patt)
    patt = lpeg.Cs((patt / repl + 1)^0)
    return patt
end

local syntax = {}
local any = P(1)
local endstr = -any
local space = (S' \t')^0
local fullspace = l.space^0

local open = P"<" -- create the generic pattern objects
local close = P">"
local cid = l.digit^1
local emoji_name = (("_" + l.alnum)  - ":")^1

local mention_types = {
	emoji = ":" * emoji_name * ":" * cid , 
	animoji = "a:" * emoji_name * ":" * cid ,
	user = "@" * cid,
	nick = "@!" * cid,
	role = "@&" * cid ,
	channel = "#" * cid ,
}

local mention_patt = open * (
	mention_types.emoji + 
	mention_types.animoji + 
	mention_types.user + 
	mention_types.nick + 
	mention_types.role + 
	mention_types.channel
) * close

local quote = P'"'
local escapedQuote = P'\\"'/'"'
local non_quote = escapedQuote + (1 - quote) 
local word = 1 - (quote + escapedQuote + l.space) 

local quoted = mention_patt + (quote * Cs(non_quote^1) * quote) + C(word^1)

local qstring = (fullspace * quoted * fullspace)^0
syntax.qstring = #any*qstring

function syntax.enclosed_qstring(start, stop, predicated)
    local escaped_start, escaped_stop = P("\\"..start)/start,P("\\"..stop)/stop
    
    local aug_quote = quote + start + stop
    local aug_escaped = escapedQuote + escaped_start + escaped_stop
    local aug_nonQuote = aug_escaped + (1 - aug_quote)

    local aug_word = 1 - (aug_quote + aug_escaped + l.space)

    local aug_quoted = mention_patt + (quote * Cs(aug_nonQuote^1) * quote) + C(aug_word^1)

    local aug_qstring = (fullspace * aug_quoted * fullspace)^0
    if predicated then
        return start * (#(P(1)-stop)*aug_qstring) * stop
    else
        return start * aug_qstring * stop
    end
end

local nonce = Cg((1 - l.space)^1, "command")

local command_string = Ct(nonce * fullspace * Cg(C(any^0), "args"))

syntax.command_string = command_string

syntax.command = command_string

local digits = R'09'^1
local mpm = maybe(S'+-')
local dot = P'.'
local exp = S'eE'
local float = mpm * digits * maybe(dot*digits) * maybe(exp*mpm*digits)

syntax.float = C(float) / tonumber

syntax.signed = C(mpm * digits) / tonumber

syntax.utf8 = require"syntax/utf8"
syntax.re = require"syntax/re"

local code_mark = P"```"
local lang = Cg((1-l.space)^0, "language")
local code = Cg((1- code_mark)^0, "code")

syntax.codeblock = code_mark * Ct(lang * code) * code_mark

syntax.everything = #any*C(P(1)^0)

local char, byte, format        = string.char, string.byte, string.format
local tochar      = function(s) return char(tonumber(s,16)) end

local colon       = P(":")
local qmark       = P("?")
local hash        = P("#")
local slash       = P("/")
local percent     = P("%")
local endofstring = P(-1)

local hexdigit    = R("09","AF","af")
local plus        = P("+")
local nothing     = Cc("")
local escapedchar = (percent * C(hexdigit * hexdigit)) / tochar
local escaped     = (plus / " ") + escapedchar -- so no loc://foo++.tex

local noslash     = P("/") / ""

local schemestr    = Cs((escaped+(1-colon-slash-qmark-hash))^2)
local authoritystr = Cs((escaped+(1-      slash-qmark-hash))^0)
local pathstr      = Cs((escaped+(1-            qmark-hash))^0)
local querystr     = Cs((        (1-                  hash))^0)
local fragmentstr  = Cs((escaped+(1-           endofstring))^0)

local scheme    =                 schemestr    * colon + nothing
local authority = slash * slash * authoritystr         + nothing
local path      = slash         * pathstr              + nothing
local query     = qmark         * querystr             + nothing
local fragment  = hash          * fragmentstr          + nothing

local url  = scheme * authority * path * query * fragment
local curl = Ct(url)
syntax.is_url = function(s) return not not url:match(s) end
syntax.url = function(s) return curl:match(s) end 

local parser = curl
local escapes = { }

setmetatable(escapes, { __index = function(t,k)
    local v = format("%%%02X",byte(k))
    t[k] = v
    return v
end })

local escaper    = Cs((R("09","AZ","az")^1 + P(" ")/"%%20" + S("-./_")^1 + P(1) / escapes)^0) -- space happens most
local unescaper  = Cs((escapedchar + 1)^0)
local getcleaner = Cs((P("+++") / "%%2B" + P("+") / "%%20" + P(1))^1)

local urlunescaped  = escapedchar
local urlescaper    = escaper
local urlunescaper  = unescaper
local urlgetcleaner = getcleaner

function unescapeget(str)
    return getcleaner:match(str)
end

local function split(str)
    return (type(str) == "string" and parser:match(str)) or str
end

local isscheme = schemestr * colon * slash * slash 
local function hasscheme(str)
    if str then
        local scheme = isscheme:match(str) -- at least one character
        return scheme ~= "" and scheme or false
    else
        return false
    end
end

local rootletter       = R("az","AZ")
                       + S("_-+")
local separator        = P("://")
local qualified        = P(".")^0 * P("/")
                       + rootletter * P(":")
                       + rootletter^1 * separator
                       + rootletter^1 * P("/")
local rootbased        = P("/")
                       + rootletter * P(":")

local barswapper       = replacer("|",":")
local backslashswapper = replacer("\\","/")

-- queries:

local equal = P("=")
local amp   = P("&")
local key   = Cs(((escapedchar+1)-equal            )^0)
local value = Cs(((escapedchar+1)-amp  -endofstring)^0)

local splitquery = Cf ( Ct("") * P { "sequence",
    sequence = V("pair") * (amp * V("pair"))^0,
    pair     = Cg(key * equal * value),
}, rawset)

-- hasher

local function process(detailed)
    local rawscheme  = ""
    local rawquery   = ""
    local somescheme = false
    local somequery  = false
    if detailed then
        rawscheme  = detailed[1]
        rawquery   = detailed[4]
        somescheme = rawscheme ~= ""
        somequery  = rawquery  ~= ""
    end
    if not somescheme and not somequery then
        return {
            scheme    = "file",
            authority = "",
            path      = str,
            query     = "",
            fragment  = "",
            original  = str,
            noscheme  = true,
            filename  = str,
        }
    end
    -- not always a filename but handy anyway
    local authority = detailed[2]
    local path      = detailed[3]
    local filename  = nil
    if authority == "" then
        filename = path
    elseif path == "" then
        filename = ""
    else
        filename = authority .. "/" .. path
    end
    return {
        scheme    = rawscheme,
        authority = authority,
        path      = path,
        query     = unescaper:match(rawquery),  -- unescaped, but possible conflict with & and =
        queries   = splitquery:match(rawquery), -- split first and then unescaped
        fragment  = detailed[5],
        original  = str,
        noscheme  = false,
        filename  = filename,
    }
end

local function hashed(str)
    if not str or str == "" then
        return {
            scheme   = "invalid",
            original = str,
        }
    end
    local detailed   = split(str)
    return process(detailed)
end

syntax.parse_url = hashed



syntax.url = #any * parser / process

function syntax.some(pattern)
    pattern = C(pattern)
    return Ct(pattern^1)
end

syntax.mention = mention_patt

return syntax