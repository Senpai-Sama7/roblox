local Signal = require("./src/ServerScriptService/Signal")

-- E1: Zero allocations after warmup
local function testAllocations()
    local sig = Signal.new()
    local x = 0
    local conn = sig:Connect(function(val)
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

testAllocations()
testYielding()
testConcurrentDisconnect()
print("All Success Criteria Passed.")
