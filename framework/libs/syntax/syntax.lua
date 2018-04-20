local lpeg = require"lpeg"
local P, S, R, V, C, Ct, Cg, l = lpeg.P, lpeg.S, lpeg.R, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, {} 
lpeg.locale(l)

local function maybe(p) return p^-1 end

local syntax = {}
local any = P(1)
local space = l.space^0
local escapedQuote = P'\\"'
local quote = P'"'
local non_quote = escapedQuote + (1 - quote) 
local word = 1 - (quote + escapedQuote + l.space) 

local quoted = (quote * C(non_quote^1) * quote) + C(word^1)

local qstring = (space * quoted * space)^0
syntax.qstring = Ct(qstring)


local pipe_literal = P"|"
local pipe_item = (quote * C((non_quote)^1) * quote) + C((1 - (quote + escapedQuote + l.space + pipe_literal))^1)
local pipe_args = Ct((space * pipe_item * space)^0)
local pipe_expr = Ct(pipe_args * (pipe_literal * pipe_args)^1)

syntax.pipe = pipe_expr


local nonce = Cg((1 - l.space)^1, "command")

local command_string = Ct(nonce * space * Cg(syntax.qstring, "args"))



syntax.command_string = command_string

local function fix_pipe_expr(pipe)

    return pipe,pipe[1]
end

local command_pipe = Ct(nonce * space * Cg(pipe_expr, "pipe"))

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
    sexpr     = V'wspace' * P'(' * (V'symbol' + V'sexpr') * Ct(V'expr' ^ 0) * P')' / function(f, args) return f(args) end
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

return syntax