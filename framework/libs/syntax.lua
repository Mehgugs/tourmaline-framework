--## Syntax
-- Utilities for parsing input and converting it to more useful data structures
-- key-value resolvers (for properties) live here.
--;
require"discordia".extensions.string()
local kv_resolver = {__kvr = true} kv_resolver.__index = kv_resolver

local kv = function (vin) return setmetatable(vin, kv_resolver) end

function kv_resolve( args )
    local out = {}
    for k,v in pairs(args) do 
        if type(v) == 'table' and v.__kvr then 
            out[v[1]] = v[2]
        else
            out[k] = v
        end
    end
    return out
end

local parse = {}

local function cut(t, s) 
    local bags = {{}}
    local cur= bags[1]
    for k,v in ipairs(t) do 
        if s == v then 
            table.insert(bags, {})
            cur = bags[#bags]
        else table.insert(cur, v) end  
    end
    return bags
end

function parse.flags( list )
    local kvpairs = {}
    local waiting = nil
    for i, item in ipairs(list) do 
        if item:startswith("-") or item:startswith("--") then 
            --new key
            current = item:gsub("^%-+", "",1)
            kvpairs[current] = true
        elseif kvpairs[current] == true then
            kvpairs[current] = item
        elseif kvpairs[current] then
            kvpairs[current] = kvpairs[current] .. item
        end
    end 
    return kvpairs
end

function parse.cmdline(s_in)
    local arg_set = cut(s_in, '>')
    local flags, pipes = parse.flags(arg_set[1]), {unpack(arg_set, 2)}
    return flags, pipes
end

local function reduceQuotes( list )
    local new = {{}}
    local current
    local escaped
    for i = 1, #list do 
      local c = list:sub(i,i)
      if not escaped and c == '\\' then escaped = i end
      if c == '"' and not current and not escaped then 
        current = #new+1
        new[#new] = table.concat(new[#new])
        new[current] = {c}
        goto continue
      end
      if current and c ~= '"' or escaped then
        table.insert(new[current], c)
      end
      if current and c == '"' and not escaped then 
        new[current] = table.concat(new[current]) .. c
        current = nil
        new[#new+1] = {}
      end
      if not current and c ~= '"' or escaped then 
        table.insert(new[#new], c)
      end
      ::continue::
    end
    for i = #new, 1, -1 do 
       if type(new[i]) == 'table' then new[i] = table.concat(new[i]) end
    end
    if escaped ~= i then escaped = nil end
    return new
end

function parse.std(str)
    local parts = reduceQuotes(str)
    local arglist = { }
    for _, arg in ipairs(parts) do 
        if arg:sub(1,1) == '"' then 
            insert(arglist, arg:sub(2, -2))
        else
            local prts = arg:split" "
            for _, part in ipairs(prts) do if part ~= "" then insert(arglist, part) end end
        end
    end
    return arglist
end

return {
    kv = kv,
    kv_resolve = kv_resolve,
    parse = parse,
    cut = cut,
    std = parse.std
}