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
local space = (S' \t')^0
local fullspace = l.space^0
local escapedQuote = P'\\"'
local quote = P'"'
local non_quote = escapedQuote + (1 - quote) 
local word = 1 - (quote + escapedQuote + l.space) 

local quoted = (quote * C(non_quote^1) * quote) + C(word^1)

local qstring = (fullspace * quoted * fullspace)^0
syntax.qstring = Ct(qstring)


local pipe_literal = P"|"
local escaped_pipe = P"\\|"
local inc = function(a) return a + 1 end
local pipe_arg = escaped_pipe + (1 - pipe_literal)
local pipe_item = 
    Cg(Cc(true), "pipe") 
    * 
    Cg(C((escaped_pipe + (1 - (pipe_literal + l.space))  )^1), "func") 
    * fullspace * 
    Cg(C(pipe_arg^0), "pipe_args")

local pipe_args = (fullspace * Ct(pipe_item) * fullspace)^0
local pipe_expr =  Ct( (pipe_args * pipe_literal * pipe_args)^1)

syntax.pipe = pipe_expr


local nonce = Cg((1 - l.space)^1, "command")

local command_string = Ct(nonce * fullspace * Cg(C(any^0), "args"))



syntax.command_string = command_string


local command_pipe = Ct(nonce * fullspace * Cg(C(pipe_arg^0), "args") * Cg(pipe_expr, "pipe"))

syntax.command_pipe = command_pipe

syntax.command = command_pipe + command_string

local digits = R'09'^1
local mpm = maybe(S'+-')
local dot = P'.'
local exp = S'eE'
local float = mpm * digits * maybe(dot*digits) * maybe(exp*mpm*digits)

local lisp_environment = {}
local lisp_parser = P { --taken from https://gist.github.com/polymeris/857a7ae31db0d240ef3f and modified.
    'program', -- initial rule
    program   = Ct(V'sexpr' ^ 0),
    wspace    = S' \n\r\t' ^ 0,
    atom      = V'boolean' + V'number' + V'string' + V'symbol',
        symbol  = C(((1 - S' \n\r\t\"\'()[]{}#@~')) ^ 1) /function (s) return lisp_environment[s] end,
        boolean = C(P'true' + P'false') /lisp_environment,
        number  = V'integer' + V'float',
            integer = C(R'19' * R'09' ^ 0)/tonumber,
            float   =  float/tonumber,
        string  = S'"' * C((1 - S'"\n\r') ^ 0) * S'"',
    coll      = V'list' + V'array',
        list    = P'\'(' * Ct(V'expr' ^ 1) * P')',
        array   = P'[' * Ct(V'expr' ^ 1) * P']',
    expr      = V'wspace' * (V'coll' + V'atom' + V'sexpr'),
    sexpr     = V'wspace' * P'(' * (V'symbol' + V'sexpr') * Ct(V'expr' ^ 0) * P')' / function(f, args) return f and f(args) end
}

local def = function(n, f) lisp_environment[n] = f end

local function reduce(f, args) local head = args[1]; 
    for i = 2, #args do head = f(head, args[i]) end 
    return head 
end
local identity = function(t) return t end
local function map(args) local out = {}
    local f = lisp_environment[args[1]] or identity

    for k,v in pairs(args) do 
        out[k] = f(v) 
    end
end

--built-in functions

local function bind1(f, a) return function(...) return f(a, ...) end end
local function bool(a) 
    if a and a ~= lisp_environment["false"] then return true;
    else return false end
end
def('+', bind1(reduce, function(a,b) return a + b end))
def('-', bind1(reduce, function(a,b) return a - b end))
def('*', bind1(reduce, function(a,b) return a * b end))
def('/', bind1(reduce, function(a,b) return a / b end))
def('true', function(a) return a[1] end)
def('false', function(a) return a[2] end)
def('if', function(a) return bool(a[1]) and a[2] or a[3] end)
def('else', function(a) return not bool(a[1]) and lisp_environment['true'] or lisp_environment['false'] end)
def('and', bind1(reduce, function(a, b) return bool(a) and bool(b) end))
def('or', bind1(reduce, function(a, b) return bool(a) or bool(b) end))
def('xor', bind1(reduce, function(a, b) return (bool(a) and  not bool(b))  or (not bool(a) and  bool(b)) end))
def('=>', bind1(reduce, function(a, b) return (not bool(a)) or bool(b) end))
def('not', function(a) return not bool(a[1]) end)

syntax.lisp = {
    def = def,
    ENV = lisp_environment,
    parser = lisp_parser,  
}
syntax.utf8 = require"syntax/utf8"
syntax.re = require"syntax/re"

local code_mark = P"```"
local lang = Cg((1-l.space)^0, "language")
local code = Cg((1- code_mark)^0, "code")

syntax.codeblock = code_mark * Ct(lang * code) * code_mark
syntax.codeblock_arg = Ct(syntax.codeblock)

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

local function hashed(str)
    if not str or str == "" then
        return {
            scheme   = "invalid",
            original = str,
        }
    end
    local detailed   = split(str)
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

syntax.parse_url = hashed

return syntax