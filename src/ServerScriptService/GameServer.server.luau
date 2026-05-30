--[[
    Script: ServerScriptService/GameServer
    Server-side. Authoritative core loop for the checkpoint obby.

    Responsibilities:
        - Creates RemoteEvents (UIUpdate, PlayerAction) in ReplicatedStorage/Remotes
        - Tracks per-player run state: timing, checkpoints, coins
        - Validates all client inputs (only "RequestReset" accepted)
        - Updates leaderstats (BestTime, Coins)
        - Persists data via DataManager on finish / leave / shutdown

    Tags expected in Workspace:
        "Checkpoint" — Parts with an integer Attribute "Order" (1, 2, 3…)
        "Coin"       — Parts the player can collect (once per run per player)
        "FinishLine"  — Single part, the end of the course
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

----------------------------------------------------------------
-- Remote Events
----------------------------------------------------------------
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

-- Server → Client: UI updates, notifications
local uiUpdateEvent = Instance.new("RemoteEvent")
uiUpdateEvent.Name = "UIUpdate"
uiUpdateEvent.Parent = remotesFolder

-- Client → Server: player requests (only "RequestReset")
local playerActionEvent = Instance.new("RemoteEvent")
playerActionEvent.Name = "PlayerAction"
playerActionEvent.Parent = remotesFolder

----------------------------------------------------------------
-- State
----------------------------------------------------------------
type PlayerState = {
    data: DataManager.PlayerData,
    startTime: number?,
    lastCheckpointTime: number?,
    checkpointsReached: number,
    coinsCollectedThisRun: { [Instance]: boolean },
    coinsThisRun: number,
    isRunning: boolean,
    lastCheckpointPos: Vector3?,
}

local playerStates: { [Player]: PlayerState } = {}
local totalCheckpoints: number = 0

-- Cooldowns: prevent reset spam (1 second minimum between resets)
local RESET_COOLDOWN = 1.0
local lastResetTime: { [Player]: number } = {}

-- Touch debounce: prevent rapid re-fires of Touched events per player
local TOUCH_DEBOUNCE = 0.15
local lastTouchTime: { [Player]: number } = {}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function formatTime(seconds: number): string
    local mins = math.floor(seconds / 60)
    local secs = seconds - (mins * 60)
    return string.format("%d:%05.2f", mins, secs)
end

-- Cache spawn position once at init instead of scanning every call
local cachedSpawnPos: Vector3? = nil
local function getSpawnPosition(): Vector3
    if cachedSpawnPos then return cachedSpawnPos end
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            cachedSpawnPos = obj.Position + Vector3.new(0, 3, 0)
            return cachedSpawnPos
        end
    end
    -- Fallback but do NOT cache it, in case the map streams in later
    return Vector3.new(0, 10, 0)
end

local function countCheckpoints()
    local maxOrder = 0
    for _, cp in ipairs(CollectionService:GetTagged("Checkpoint")) do
        local order = cp:GetAttribute("Order")
        if order and order > maxOrder then
            maxOrder = order
        end
    end
    totalCheckpoints = maxOrder
    print(string.format("[GameServer] Checkpoint count: %d", totalCheckpoints))
end

----------------------------------------------------------------
-- Leaderstats
----------------------------------------------------------------
local function setupLeaderstats(player: Player, data: DataManager.PlayerData)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local bt = Instance.new("StringValue")
    bt.Name = "BestTime"
    bt.Value = if data.bestRunTimeSeconds < 999999 then formatTime(data.bestRunTimeSeconds) else "--:--"
    bt.Parent = ls

    local c = Instance.new("IntValue")
    c.Name = "Coins"
    c.Value = data.totalCoins
    c.Parent = ls
end

local function refreshLeaderstats(player: Player, state: PlayerState)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return end
    local bt = ls:FindFirstChild("BestTime")
    if bt then
        bt.Value = if state.data.bestRunTimeSeconds < 999999
            then formatTime(state.data.bestRunTimeSeconds) else "--:--"
    end
    local c = ls:FindFirstChild("Coins")
    if c then c.Value = state.data.totalCoins end
end

----------------------------------------------------------------
-- Run lifecycle
----------------------------------------------------------------
local function startRun(player: Player)
    local state = playerStates[player]
    if not state then return end

    local now = os.clock()
    state.startTime = now
    state.lastCheckpointTime = now
    state.checkpointsReached = 0
    state.coinsCollectedThisRun = {}
    state.coinsThisRun = 0
    state.isRunning = true
    state.lastCheckpointPos = getSpawnPosition()

    -- Teleport to spawn securely, waiting for character stream-in if needed
    task.spawn(function()
        -- EXCEPTION: Character might not exist yet, we must yield.
        local char = player.Character or player.CharacterAdded:Wait()
        if not char.Parent then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp and hrp:IsA("BasePart") then
            hrp.CFrame = CFrame.new(getSpawnPosition())
        end
    end)

    uiUpdateEvent:FireClient(player, {
        type = "RunStarted",
        data = {
            totalCheckpoints = totalCheckpoints,
            bestTime = state.data.bestRunTimeSeconds,
            totalCoins = state.data.totalCoins,
        },
    })
    print(string.format("[GameServer] %s started a run", player.Name))
end

local function finishRun(player: Player)
    local state = playerStates[player]
    if not state or not state.isRunning or not state.startTime then return end

    local elapsed = os.clock() - state.startTime
    state.isRunning = false

    -- Persist
    state.data.totalRuns += 1
    state.data.totalCoins += state.coinsThisRun
    local isNewBest = elapsed < state.data.bestRunTimeSeconds
    if isNewBest then
        state.data.bestRunTimeSeconds = elapsed
    end

    refreshLeaderstats(player, state)

    -- Deep-copy data before async save so a rapid reset can't mutate it mid-write
    local dataSnapshot = table.clone(state.data)
    task.spawn(function()
        DataManager.savePlayerData(player, dataSnapshot)
    end)

    uiUpdateEvent:FireClient(player, {
        type = "RunFinished",
        data = {
            time = elapsed,
            formattedTime = formatTime(elapsed),
            isNewBest = isNewBest,
            bestTime = state.data.bestRunTimeSeconds,
            coinsCollected = state.coinsThisRun,
            totalCoins = state.data.totalCoins,
            totalRuns = state.data.totalRuns,
        },
    })
    print(string.format("[GameServer] %s finished in %s", player.Name, formatTime(elapsed)))
end

----------------------------------------------------------------
-- Touch handlers
----------------------------------------------------------------
local function onCheckpointTouched(cp: BasePart, hit: BasePart)
    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    -- Touch debounce
    local now = os.clock()
    if lastTouchTime[player] and (now - lastTouchTime[player]) < TOUCH_DEBOUNCE then return end
    lastTouchTime[player] = now

    local state = playerStates[player]
    if not state or not state.isRunning then return end

    local order = cp:GetAttribute("Order")
    -- Validate Order is a positive integer
    if type(order) ~= "number" or order ~= math.floor(order) or order < 1 then return end
    if order ~= state.checkpointsReached + 1 then return end

    -- Anti-cheat: validate speed between THIS checkpoint and the LAST one
    if state.lastCheckpointPos and state.lastCheckpointTime then
        local distance = (cp.Position - state.lastCheckpointPos).Magnitude
        local timeBetween = now - state.lastCheckpointTime
        -- Max ~100 studs/sec is generous for any humanoid walkspeed
        if timeBetween > 0.01 and (distance / timeBetween) > 150 then
            warn(string.format("[Anti-Cheat] %s moved %.0f studs in %.2fs to CP %d (blocked)",
                player.Name, distance, timeBetween, order))
            return
        end
    end

    state.checkpointsReached = order
    state.lastCheckpointPos = cp.Position + Vector3.new(0, 3, 0)
    state.lastCheckpointTime = now

    uiUpdateEvent:FireClient(player, {
        type = "CheckpointHit",
        data = { checkpoint = order, total = totalCheckpoints },
    })
    print(string.format("[GameServer] %s hit checkpoint %d/%d", player.Name, order, totalCheckpoints))
end

local function onCoinTouched(coin: BasePart, hit: BasePart)
    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    local state = playerStates[player]
    if not state or not state.isRunning then return end
    if state.coinsCollectedThisRun[coin] then return end

    state.coinsCollectedThisRun[coin] = true
    state.coinsThisRun += 1

    uiUpdateEvent:FireClient(player, {
        type = "CoinCollected",
        data = { coinsThisRun = state.coinsThisRun, position = coin.Position },
    })
end

local function onFinishTouched(hit: BasePart)
    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    local state = playerStates[player]
    if not state or not state.isRunning then return end

    if state.checkpointsReached < totalCheckpoints then
        uiUpdateEvent:FireClient(player, {
            type = "Notification",
            data = {
                message = string.format("Missed checkpoints! (%d/%d)", state.checkpointsReached, totalCheckpoints),
                color = "red",
            },
        })
        return
    end
    finishRun(player)
end

----------------------------------------------------------------
-- Connect tagged parts
----------------------------------------------------------------
local connections: { [Instance]: RBXScriptConnection } = {}

local function connectPart(instance: Instance)
    if connections[instance] then return end
    if CollectionService:HasTag(instance, "Checkpoint") then
        connections[instance] = instance.Touched:Connect(function(hit) onCheckpointTouched(instance, hit) end)
    elseif CollectionService:HasTag(instance, "Coin") then
        connections[instance] = instance.Touched:Connect(function(hit) onCoinTouched(instance, hit) end)
    elseif CollectionService:HasTag(instance, "FinishLine") then
        connections[instance] = instance.Touched:Connect(function(hit) onFinishTouched(hit) end)
    end
end

local function disconnectPart(instance: Instance)
    if connections[instance] then
        connections[instance]:Disconnect()
        connections[instance] = nil
    end
end

for _, cp in ipairs(CollectionService:GetTagged("Checkpoint")) do connectPart(cp) end
for _, coin in ipairs(CollectionService:GetTagged("Coin")) do connectPart(coin) end
for _, fl in ipairs(CollectionService:GetTagged("FinishLine")) do connectPart(fl) end

CollectionService:GetInstanceAddedSignal("Checkpoint"):Connect(function(inst)
    countCheckpoints()
    connectPart(inst)
end)
CollectionService:GetInstanceAddedSignal("Coin"):Connect(connectPart)
CollectionService:GetInstanceAddedSignal("FinishLine"):Connect(connectPart)

CollectionService:GetInstanceRemovedSignal("Checkpoint"):Connect(disconnectPart)
CollectionService:GetInstanceRemovedSignal("Coin"):Connect(disconnectPart)
CollectionService:GetInstanceRemovedSignal("FinishLine"):Connect(disconnectPart)

----------------------------------------------------------------
-- Client → Server (validated)
----------------------------------------------------------------
playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string)
    if type(action) ~= "string" then return end
    if action == "RequestReset" then
        -- Cooldown check: prevent reset spam
        local now = os.clock()
        if lastResetTime[player] and (now - lastResetTime[player]) < RESET_COOLDOWN then
            return
        end
        lastResetTime[player] = now
        startRun(player)
    end
    -- All other values silently ignored
end)

----------------------------------------------------------------
-- Player lifecycle
----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player: Player)
    local data = DataManager.loadPlayerData(player)

    playerStates[player] = {
        data = data,
        startTime = nil,
        lastCheckpointTime = nil,
        checkpointsReached = 0,
        coinsCollectedThisRun = {},
        coinsThisRun = 0,
        isRunning = false,
        lastCheckpointPos = nil,
    }

    setupLeaderstats(player, data)

    -- Wait for client scripts, then auto-start
    task.delay(1, function()
        -- Guard: player may have left during the 1s delay
        if not player.Parent then return end
        if not playerStates[player] then return end

        uiUpdateEvent:FireClient(player, {
            type = "DataLoaded",
            data = {
                bestTime = data.bestRunTimeSeconds,
                totalCoins = data.totalCoins,
                totalRuns = data.totalRuns,
                totalCheckpoints = totalCheckpoints,
            },
        })
        startRun(player)
    end)

    -- Respawn at last checkpoint
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        local state = playerStates[player]
        if not state then return end
        if state.isRunning and state.lastCheckpointPos then
            local hrp = character:WaitForChild("HumanoidRootPart", 5)
            if hrp then hrp.CFrame = CFrame.new(state.lastCheckpointPos) end
        else
            startRun(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    local state = playerStates[player]
    if state then
        -- Deep-copy data before clearing state so async save doesn't race
        local dataSnapshot: DataManager.PlayerData = table.clone(state.data)
        playerStates[player] = nil
        -- Non-blocking save: prevents stalling the server if DataStore retries
        task.spawn(function()
            DataManager.savePlayerData(player, dataSnapshot)
        end)
    end
    -- Clean up cooldown/debounce tables to prevent memory leaks
    lastResetTime[player] = nil
    lastTouchTime[player] = nil
end)

game:BindToClose(function()
    -- Run all saves concurrently and safely block until complete (max 25s timeout)
    local activeSaves = 0
    local bindThread = coroutine.running()

    for player, state in pairs(playerStates) do
        activeSaves += 1
        task.spawn(function()
            DataManager.savePlayerData(player, state.data)
            activeSaves -= 1
            if activeSaves == 0 and coroutine.status(bindThread) == "suspended" then
                task.spawn(bindThread)
            end
        end)
    end
    
    if activeSaves > 0 then
        -- Failsafe timeout to prevent server hanging entirely if DataStore fails endlessly
        local timeoutConn = task.delay(25, function()
            if coroutine.status(bindThread) == "suspended" then
                warn("[GameServer] BindToClose timed out after 25s. Proceeding shutdown.")
                task.spawn(bindThread)
            end
        end)
        coroutine.yield()
        task.cancel(timeoutConn)
    end
end)

----------------------------------------------------------------
-- Init
----------------------------------------------------------------
countCheckpoints()
print("[GameServer] Brainrot Checkpoint Obby initialized!")
