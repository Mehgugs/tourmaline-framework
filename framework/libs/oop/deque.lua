return require"oop/oo".Object
:extend
{
    __info = "tourmaline/deque",
    initial = function(self)
        self._queue = {}
        self._first = 0
        self._last = -1
    end,
    is_empty = function(self) return self._first == 0 and self._last == -1 end,
    pushleft = function(self, v)
        local first = self._first - 1
        self._first = first
        self._queue[first] = v
    end,
    pushright = function(self, v)
        local last = self._last + 1
        self._last = last
        self._queue[last] = v
    end,
    popleft = function(self)
        local first = self._first
        if first > self._last then return end
        local value = self._queue[first]
        self._queue[first] = nil        -- to allow garbage collection
        self._first = first + 1
        return value
    end,
    popright = function(self)
        local last = self._last
        if self._first > last then return end
        local value = self._queue[last]
        self._queue[last] = nil        -- to allow garbage collection
        self._last = last - 1
        return value
    end,
    first = function (self) return self._queue[self._first] end,
    last = function (self) return self._queue[self._last] end  
}