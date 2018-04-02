local meta = require"meta"
local running = coroutine.running

meta.decorator('coro', function(f) 
    return function(...)
        local _, main = running()
        assert(not main, "Cannot call function outside a coroutine.")
        return f (...)
    end
end)
