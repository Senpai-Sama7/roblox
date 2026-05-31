--!strict
export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type ConnectionNode = {
	_next: ConnectionNode?,
	_fn: ((...any) -> ())?,
	Connected: boolean,
	Disconnect: (self: ConnectionNode) -> (),
}

-- Module-level free pools for zero-allocation recycling
local freeNode: ConnectionNode? = nil
local freeThread: thread? = nil

-- runCallback is called by the yielder coroutine; it restores freeThread after use.
local function runCallback(fn: (...any) -> (), ...: any)
	local thread = freeThread
	freeThread = nil
	fn(...)
	freeThread = thread
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

-- Disconnect: mark node dead only.
-- Do NOT immediately recycle (_next = freeNode) here because:
--   1. The Fire loop may have captured a snapshot of this node's _next already.
--   2. Immediate recycle corrupts the _next chain if this node is visited mid-iteration.
-- Recycling is deferred to the Fire loop's pruning pass (the `else` branch).
local function disconnect(self: ConnectionNode)
	if not self.Connected then
		return
	end
	self.Connected = false
	self._fn = nil
end

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_head = nil :: ConnectionNode?,
	}, Signal) :: any
end

function Signal:Connect(fn)
	local node: ConnectionNode
	if freeNode then
		node = freeNode
		freeNode = node._next
		node._next = nil
	else
		node = {} :: any
	end

	node._fn = fn
	node.Connected = true
	node.Disconnect = disconnect
	-- Prepend to head (LIFO). Tests assume FIFO; see note below.
	-- We use a tail-pointer to maintain FIFO connection order so that
	-- the first-connected handler fires first (matches test_signal.luau E3 expectations).
	if not self._head then
		self._head = node
		self._tail = node
	else
		-- Append to tail to preserve connection order (FIFO)
		local tail = self._tail :: any
		tail._next = node
		self._tail = node
	end

	return node :: Connection
end

function Signal:Fire(...)
	local curr = self._head
	local prev: ConnectionNode? = nil

	while curr do
		local node = curr :: ConnectionNode
		-- Capture next pointer BEFORE executing callback.
		-- This prevents mid-callback Disconnect() calls from corrupting traversal,
		-- because Disconnect() no longer mutates _next (only sets Connected = false).
		local nextNode = node._next

		if node.Connected then
			-- Capture fn before callback: Disconnect() nils _fn mid-callback
			local fn = node._fn
			if fn then
				local t = freeThread
				if not t then
					t = coroutine.create(yielder)
					freeThread = t
					coroutine.resume(t)
				end
				-- Support both Roblox task scheduler (game) and pure Luau CLI (lune)
				if type(task) == "table" and task.spawn then
					task.spawn(t, fn, ...)
				else
					coroutine.resume(t, fn, ...)
				end
			end
			prev = node
			curr = nextNode
		else
			-- Node marked dead: splice out and recycle safely now.
			-- It is safe to recycle here because we already advanced to nextNode.
			if prev then
				prev._next = nextNode
			else
				self._head = nextNode
			end
			-- If we just pruned the tail, update _tail to prevent dangling ref
			if self._tail == node then
				self._tail = prev
			end
			-- Recycle into free pool
			node._next = freeNode
			freeNode = node
			curr = nextNode
		end
	end
end

function Signal:DisconnectAll()
	local curr = self._head
	while curr do
		local node = curr :: ConnectionNode
		node.Connected = false
		node._fn = nil
		local nextNode = node._next
		node._next = freeNode
		freeNode = node
		curr = nextNode
	end
	self._head = nil
	self._tail = nil
end

return {
	new = Signal.new,
}
