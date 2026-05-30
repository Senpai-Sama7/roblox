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
	_fn: (...any) -> (),
	Connected: boolean,
	Disconnect: (self: ConnectionNode) -> (),
}

local freeNode: ConnectionNode? = nil
local freeThread: thread? = nil

local function runCallback(fn, ...)
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

local function disconnect(self: ConnectionNode)
	if not self.Connected then
		return
	end
	self.Connected = false
	self._fn = nil :: any
	self._next = freeNode
	freeNode = self
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
	else
		node = {} :: any
	end

	node._fn = fn
	node.Connected = true
	node.Disconnect = disconnect
	node._next = self._head
	self._head = node

	return node :: Connection
end

function Signal:Fire(...)
	local node = self._head
	local prev: ConnectionNode? = nil

	while node do
		if node.Connected then
			if not freeThread then
				freeThread = coroutine.create(yielder)
				coroutine.resume(freeThread :: thread)
			end
			-- Support both Roblox task scheduler and pure Luau CLI
			if typeof(task) == "table" and task.spawn then
				task.spawn(freeThread :: thread, node._fn, ...)
			else
				coroutine.resume(freeThread :: thread, node._fn, ...)
			end
			prev = node
			node = node._next
		else
			local nextNode = node._next
			if prev then
				prev._next = nextNode
			else
				self._head = nextNode
			end
			node = nextNode
		end
	end
end

function Signal:DisconnectAll()
	local node = self._head
	while node do
		node.Connected = false
		node._fn = nil :: any
		local nextNode = node._next
		node._next = freeNode
		freeNode = node
		node = nextNode
	end
	self._head = nil
end

return {
	new = Signal.new,
}
