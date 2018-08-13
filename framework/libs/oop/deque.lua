local deque = require"oop/oo".Object
:extend
{
    __info = "tourmaline/deque",
    initial = function(self)
        self._queue = {}
        self._first = 0
        self._last = -1
    end,
    is_empty = function(self) return self._first == 0 and self._last == -1 end,
    count = function(self) return self._last + 1 - self._first end,
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
    peekleft = function(self) 
        return self._queue[self._first]
    end,
    peekright = function(self) 
        return self._queue[self._last]
    end,
    __deque_iter_left = function(state, i) 
        if i < state._last then 
            return i+1, state._queue[i+1]
        end
    end,
    __deque_iter_right = function(state, i) 
        if i > state._first then 
            return i-1, state._queue[i-1]
        end
    end,
    fromleft = function(self) return self.__deque_iter_left, self, self._first-1 end,
    fromright = function(self) return self.__deque_iter_right, self, self._last+1 end,
    __consume_left = function(state) return state:popleft() end, 
    __consume_right = function(state) return state:popright() end,  
    drainleft = function(self) return self.__consume_left, self end,
    drainright = function(self) return self.__consume_right, self end,
    first = function (self) return self._queue[self._first] end,
    last = function (self) return self._queue[self._last] end,
    filterleft = function(self, pred)
        local new = deque:new()
        for _, item in self:fromleft() do 
            
            if pred(item) then 
                new:pushleft(item)
            end 
        end
        return new
    end,
    filterright = function(self, pred)
        local new = deque:new()
        for _, item in self:fromright() do 
            
            if pred(item) then 
                new:pushright(item)
            end 
        end
        return new
    end,
    findleft = function(self, pred)
        for _, item in self:fromleft() do 
            if pred(item) then 
                return item
            end 
        end
    end,
    findright = function(self, pred)
        for _, item in self:fromright() do 
            if pred(item) then 
                return item
            end 
        end
    end,
}
return deque