local Signal = require("./src/ServerScriptService/Signal")

-- E1: Zero allocations after warmup
local function testAllocations()
    local sig = Signal.new()
    local x = 0
    local _conn = sig:Connect(function(val)
        x = x + val
    end)
    
    -- Warmup
    sig:Fire(1)
    
    local startMem = gcinfo()
    for i = 1, 1000 do
        sig:Fire(1)
    end
    local endMem = gcinfo()
    
    assert(endMem - startMem == 0, "Memory allocated during Fire loop! GC diff: " .. tostring(endMem - startMem))
    assert(x == 1001, "Handler didn't execute")
    print("✓ E1/E5: Zero allocations per Fire")
end

-- E2: Yielding handlers execute fully
local function testYielding()
    local sig = Signal.new()
    local fired1, fired2 = false, false
    
    sig:Connect(function()
        coroutine.yield()
        fired1 = true
    end)
    sig:Connect(function()
        fired2 = true
    end)
    
    sig:Fire()
    assert(not fired1, "Yielding handler shouldn't finish immediately")
    assert(fired2, "Subsequent handler didn't fire")
    print("✓ E2: Yielding handlers survive and don't block")
end

-- E3: Disconnecting during Fire loop
local function testConcurrentDisconnect()
    local sig = Signal.new()
    local runCount = 0
    local conn1, conn2
    
    conn1 = sig:Connect(function()
        runCount += 1
        conn1:Disconnect()
        conn2:Disconnect()
    end)
    
    conn2 = sig:Connect(function()
        runCount += 1
    end)
    
    sig:Fire()
    assert(runCount == 1, "Handler fired after being disconnected during loop")
    
    sig:Fire()
    assert(runCount == 1, "Disconnected handlers fired on subsequent pass")
    print("✓ E3: Concurrent disconnects handle gracefully")
end
-- E4: Disconnecting the tail node, then connecting a new handler
-- Regression test: if _tail was left dangling after the tail node was
-- disconnected and pruned, the next Connect() would append to a recycled
-- node in the free pool, corrupting the linked list.
local function testTailDisconnectReconnect()
    local sig = Signal.new()
    local results = {}

    local conn1 = sig:Connect(function()
        table.insert(results, "A")
    end)
    local conn2 = sig:Connect(function()
        table.insert(results, "B")
    end)

    -- Disconnect the tail (conn2 was connected second = tail in FIFO)
    conn2:Disconnect()

    -- Fire to trigger pruning of the dead tail node
    sig:Fire()
    assert(#results == 1 and results[1] == "A", "E4a: Expected only A to fire after tail disconnect")

    -- Now connect a new handler — this must not crash or silently fail
    table.clear(results)
    local conn3 = sig:Connect(function()
        table.insert(results, "C")
    end)
    sig:Fire()
    assert(#results == 2 and results[1] == "A" and results[2] == "C",
        "E4b: Expected A then C after reconnect. Got: " .. table.concat(results, ","))

    conn1:Disconnect()
    conn3:Disconnect()
    table.clear(results)
    sig:Fire()
    assert(#results == 0, "E4c: Expected no fires after full disconnect")
    print("✓ E4: Tail disconnect + reconnect handled correctly")
end

testAllocations()
testYielding()
testConcurrentDisconnect()
testTailDisconnectReconnect()
print("All Success Criteria Passed.")
