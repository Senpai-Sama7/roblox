--[[
    Script: ServerScriptService/GameServer
    Authoritative core loop for the checkpoint obby - S-TIER EDITION
    
    Monetization Hooks:
        - 2x Coins Gamepass
        - VIP Gamepass (golden name, +50% coins)
        - Roblox Premium (+20% coins)
        - Developer Products (coin packs)
    
    Retention Systems:
        - Daily rewards with streaks
        - Combo system (consecutive checkpoints = multiplier)
        - Achievement triggers
        - Leaderboards (OrderedDataStore)
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local RESET_COOLDOWN = 1.0
local TOUCH_DEBOUNCE = 0.15
local MAX_ACTION_LENGTH = 64
local AUTO_START_DELAY = 1.0
local COIN_COLLECT_RADIUS = 8
local MAX_SPEED_STUDS_PER_SEC = 150
local LEADERBOARD_REFRESH = 60

----------------------------------------------------------------
-- Remote Events (idempotent)
----------------------------------------------------------------
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string, className: string): Instance
    local existing = remotesFolder:FindFirstChild(name)
    if existing then return existing end
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local uiUpdateEvent = getOrCreateRemote("UIUpdate", "RemoteEvent") :: RemoteEvent
local playerActionEvent = getOrCreateRemote("PlayerAction", "RemoteEvent") :: RemoteEvent
local shopActionEvent = getOrCreateRemote("ShopAction", "RemoteEvent") :: RemoteEvent
local dailyRewardEvent = getOrCreateRemote("DailyReward", "RemoteEvent") :: RemoteEvent

----------------------------------------------------------------
-- Leaderboard (OrderedDataStore)
----------------------------------------------------------------
local OrderedDataStoreService = game:GetService("DataStoreService")
local leaderboardStore = OrderedDataStoreService:GetOrderedDataStore("ObbyLeaderboard_v1")

----------------------------------------------------------------
-- State
----------------------------------------------------------------
type PlayerState = {
    data: DataManager.PlayerData,
    settings: DataManager.PlayerSettings,
    daily: DataManager.DailyRewardState,
    
    -- Run state
    startTime: number?,
    lastCheckpointTime: number?,
    checkpointsReached: number,
    coinsCollectedThisRun: { [Instance]: boolean },
    coinsThisRun: number,
    isRunning: boolean,
    lastCheckpointPos: Vector3?,
    
    -- Combo system
    comboCount: number,
    comboMultiplier: number,
    lastComboCheckpointTime: number,
    
    -- Session
    hasDoubleCoins: boolean,
    hasVIP: boolean,
    isPremium: boolean,
}

local playerStates: { [Player]: PlayerState } = {}
local totalCheckpoints: number = 0

-- Cooldowns
local lastResetTime: { [Player]: number } = {}
local lastTouchTime: { [Player]: number } = {}
local lastTouchPart: { [Player]: BasePart } = {}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function isFinite(n: number): boolean
    return n == n and n ~= math.huge and n ~= -math.huge
end

local function formatTime(seconds: number): string
    if not isFinite(seconds) then return "--:--" end
    local mins = math.floor(seconds / 60)
    local secs = seconds - (mins * 60)
    return string.format("%d:%05.2f", mins, secs)
end

local cachedSpawnPos: Vector3? = nil
local function getSpawnPosition(): Vector3
    if cachedSpawnPos then return cachedSpawnPos end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            cachedSpawnPos = (obj :: SpawnLocation).Position + Vector3.new(0, 3, 0)
            return cachedSpawnPos
        end
    end
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
-- Date helper
----------------------------------------------------------------
local function getTodayString(): string
    local date = os.date("*t")
    return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function isYesterday(today: string, lastDate: string): boolean
    if lastDate == "" then return false end
    local y, m, d = string.match(today, "(%d+)%-(%d+)%-(%d+)")
    local ly, lm, ld = string.match(lastDate, "(%d+)%-(%d+)%-(%d+)")
    if not y or not ly then return false end
    
    local todayNum = tonumber(y) * 10000 + tonumber(m) * 100 + tonumber(d)
    local lastNum = tonumber(ly) * 10000 + tonumber(lm) * 100 + tonumber(ld)
    return todayNum - lastNum == 1
end

----------------------------------------------------------------
-- Combo System
----------------------------------------------------------------
local function getComboTier(comboCount: number): { multiplier: number, label: string }?
    local bestTier = nil
    for _, tier in ipairs(Config.COMBO_TIERS) do
        if comboCount >= tier.threshold then
            bestTier = tier
        end
    end
    return bestTier
end

local function updateCombo(state: PlayerState, now: number): number
    local comboActive = state.lastComboCheckpointTime and (now - state.lastComboCheckpointTime) < Config.COMBO_WINDOW_SECONDS
    
    if comboActive then
        state.comboCount += 1
    else
        state.comboCount = 1 -- Reset but count this checkpoint
    end
    state.lastComboCheckpointTime = now
    
    local tier = getComboTier(state.comboCount)
    if tier then
        state.comboMultiplier = tier.multiplier
        return tier.multiplier
    else
        state.comboMultiplier = 1.0
        return 1.0
    end
end

----------------------------------------------------------------
-- Leaderstats + Leaderboard
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

    local r = Instance.new("IntValue")
    r.Name = "Runs"
    r.Value = data.totalRuns
    r.Parent = ls
end

local function refreshLeaderstats(player: Player, state: PlayerState)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return end
    local bt = ls:FindFirstChild("BestTime") :: StringValue?
    if bt then
        bt.Value = if state.data.bestRunTimeSeconds < 999999
            then formatTime(state.data.bestRunTimeSeconds) else "--:--"
    end
    local c = ls:FindFirstChild("Coins") :: IntValue?
    if c then c.Value = state.data.totalCoins end
    local r = ls:FindFirstChild("Runs") :: IntValue?
    if r then r.Value = state.data.totalRuns end
end

local function updateLeaderboard(player: Player, bestTime: number)
    if bestTime >= 999999 then return end
    local ok, err = pcall(function()
        leaderboardStore:SetAsync(tostring(player.UserId), math.floor(bestTime * 100))
    end)
    if not ok then
        warn("[Leaderboard] Failed to update: " .. tostring(err))
    end
end

----------------------------------------------------------------
-- Daily Rewards
----------------------------------------------------------------
local function checkDailyReward(player: Player, state: PlayerState)
    local today = getTodayString()
    local daily = state.daily
    
    if daily.lastClaimDate == today then
        -- Already claimed today
        dailyRewardEvent:FireClient(player, {
            type = "AlreadyClaimed",
            data = { streak = daily.streak },
        })
        return
    end
    
    -- Check if streak continues
    local streakBroken = daily.lastClaimDate ~= "" and not isYesterday(today, daily.lastClaimDate)
    if streakBroken then
        daily.streak = 0
    end
    
    daily.streak = math.min(daily.streak + 1, Config.DAILY_REWARD_MAX_STREAK)
    daily.lastClaimDate = today
    
    local baseReward = Config.DAILY_REWARD_BASE + (daily.streak * Config.DAILY_REWARD_STREAK_MULTIPLIER)
    if state.isPremium then
        baseReward += Config.DAILY_REWARD_PREMIUM_BONUS
    end
    
    state.data.totalCoins += baseReward
    refreshLeaderstats(player, state)
    
    -- Save daily state
    task.spawn(function()
        DataManager.saveDailyReward(player, daily)
    end)
    
    dailyRewardEvent:FireClient(player, {
        type = "RewardAvailable",
        data = {
            reward = baseReward,
            streak = daily.streak,
            isPremium = state.isPremium,
        },
    })
end

----------------------------------------------------------------
-- Coin Calculation
----------------------------------------------------------------
local function calculateCoinReward(state: PlayerState, baseCoins: number): number
    local multiplier = 1.0
    
    if state.hasDoubleCoins then multiplier *= 2.0 end
    if state.hasVIP then multiplier *= 1.5 end
    if state.isPremium then multiplier *= (1.0 + Config.PREMIUM_COIN_BONUS) end
    multiplier *= state.comboMultiplier
    
    return math.floor(baseCoins * multiplier)
end

----------------------------------------------------------------
-- Run Lifecycle
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
    state.comboCount = 0
    state.comboMultiplier = 1.0
    state.lastComboCheckpointTime = nil

    -- Teleport to spawn securely
    task.spawn(function()
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
            hasDoubleCoins = state.hasDoubleCoins,
            hasVIP = state.hasVIP,
            isPremium = state.isPremium,
            settings = state.settings,
        },
    })
    print(string.format("[GameServer] %s started a run", player.Name))
end

local function finishRun(player: Player)
    local state = playerStates[player]
    if not state or not state.isRunning or not state.startTime then return end

    local elapsed = os.clock() - state.startTime
    elapsed = math.clamp(elapsed, 0, 86400)
    state.isRunning = false

    -- Persist
    state.data.totalRuns += 1
    local coinReward = calculateCoinReward(state, state.coinsThisRun)
    state.data.totalCoins += coinReward
    local isNewBest = elapsed < state.data.bestRunTimeSeconds
    if isNewBest then
        state.data.bestRunTimeSeconds = elapsed
        updateLeaderboard(player, elapsed)
    end

    refreshLeaderstats(player, state)

    -- Deep-copy before async save
    local dataSnapshot = DataManager.cloneData(state.data)
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
            coinReward = coinReward,
            totalCoins = state.data.totalCoins,
            totalRuns = state.data.totalRuns,
            comboCount = state.comboCount,
        },
    })
    print(string.format("[GameServer] %s finished in %s (coins: %d, combo: %d)",
        player.Name, formatTime(elapsed), coinReward, state.comboCount))
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

    local now = os.clock()
    if lastTouchTime[player] and lastTouchPart[player] == cp
        and (now - lastTouchTime[player]) < TOUCH_DEBOUNCE then
        return
    end
    lastTouchTime[player] = now
    lastTouchPart[player] = cp

    local state = playerStates[player]
    if not state or not state.isRunning then return end

    local order = cp:GetAttribute("Order")
    if type(order) ~= "number" or order ~= math.floor(order) or order < 1 then return end
    if order ~= state.checkpointsReached + 1 then return end

    -- Anti-cheat speed check
    if state.lastCheckpointPos and state.lastCheckpointTime then
        local distance = (cp.Position - state.lastCheckpointPos).Magnitude
        local timeBetween = now - state.lastCheckpointTime
        if timeBetween <= 0.01 then
            if distance > 2 then
                warn(string.format("[Anti-Cheat] %s touched CP %d too quickly (%.1f studs) - blocked",
                    player.Name, order, distance))
                return
            end
        else
            local speed = distance / timeBetween
            if speed > MAX_SPEED_STUDS_PER_SEC then
                warn(string.format("[Anti-Cheat] %s speed %.1f to CP %d - blocked",
                    player.Name, speed, order))
                return
            end
        end
    end

    -- Combo system
    local comboMult = updateCombo(state, now)
    local tier = getComboTier(state.comboCount)

    state.checkpointsReached = order
    state.lastCheckpointPos = cp.Position + Vector3.new(0, 3, 0)
    state.lastCheckpointTime = now

    uiUpdateEvent:FireClient(player, {
        type = "CheckpointHit",
        data = {
            checkpoint = order,
            total = totalCheckpoints,
            comboCount = state.comboCount,
            comboMultiplier = comboMult,
            comboLabel = if tier then tier.label else nil,
        },
    })
    print(string.format("[GameServer] %s hit CP %d/%d (combo: %d)",
        player.Name, order, totalCheckpoints, state.comboCount))
end

local function onCoinTouched(coin: BasePart, hit: BasePart)
    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    local now = os.clock()
    if lastTouchTime[player] and lastTouchPart[player] == coin
        and (now - lastTouchTime[player]) < TOUCH_DEBOUNCE then
        return
    end
    lastTouchTime[player] = now
    lastTouchPart[player] = coin

    local state = playerStates[player]
    if not state or not state.isRunning then return end
    if state.coinsCollectedThisRun[coin] then return end

    -- Security: require HRP to exist. If a client deletes their HRP, we block.
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        warn(string.format("[Anti-Cheat] %s coin blocked — missing HRP", player.Name))
        return
    end
    local dist = (coin.Position - hrp.Position).Magnitude
    if dist > COIN_COLLECT_RADIUS then
        warn(string.format("[Anti-Cheat] %s coin from %.1f studs - blocked",
            player.Name, dist))
        return
    end

    state.coinsCollectedThisRun[coin] = true
    state.coinsThisRun += 1

    uiUpdateEvent:FireClient(player, {
        type = "CoinCollected",
        data = {
            coinsThisRun = state.coinsThisRun,
            position = coin.Position,
            comboMultiplier = state.comboMultiplier,
        },
    })
end

local function onFinishTouched(finishPart: BasePart, hit: BasePart)
    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    local now = os.clock()
    if lastTouchTime[player] and lastTouchPart[player] == finishPart
        and (now - lastTouchTime[player]) < TOUCH_DEBOUNCE then
        return
    end
    lastTouchTime[player] = now
    lastTouchPart[player] = finishPart

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

    -- Anti-cheat: speed check to finish
    if state.lastCheckpointPos and state.lastCheckpointTime then
        local distance = (finishPart.Position - state.lastCheckpointPos).Magnitude
        local timeBetween = now - state.lastCheckpointTime
        if timeBetween <= 0.01 then
            if distance > 5 then
                warn(string.format("[Anti-Cheat] %s finish too quick - blocked", player.Name))
                return
            end
        else
            local speed = distance / timeBetween
            if speed > MAX_SPEED_STUDS_PER_SEC then
                warn(string.format("[Anti-Cheat] %s finish speed %.1f - blocked", player.Name, speed))
                return
            end
        end
    end

    finishRun(player)
end

----------------------------------------------------------------
-- Connect tagged parts
----------------------------------------------------------------
local connections: { [Instance]: RBXScriptConnection } = {}

local function connectPart(instance: Instance)
    if connections[instance] then return end
    if not instance:IsA("BasePart") then
        warn(string.format("[GameServer] Tagged instance %s is not a BasePart, skipping", instance:GetFullName()))
        return
    end
    local part = instance :: BasePart
    if CollectionService:HasTag(instance, "Checkpoint") then
        connections[instance] = part.Touched:Connect(function(hit) onCheckpointTouched(part, hit) end)
    elseif CollectionService:HasTag(instance, "Coin") then
        connections[instance] = part.Touched:Connect(function(hit) onCoinTouched(part, hit) end)
    elseif CollectionService:HasTag(instance, "FinishLine") then
        connections[instance] = part.Touched:Connect(function(hit) onFinishTouched(part, hit) end)
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
-- Client → Server Actions
----------------------------------------------------------------
playerActionEvent.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
    if type(action) ~= "string" then return end
    if #action > MAX_ACTION_LENGTH then return end
    
    local state = playerStates[player]
    if not state then return end
    
    if action == "RequestReset" then
        local now = os.clock()
        if lastResetTime[player] and (now - lastResetTime[player]) < RESET_COOLDOWN then
            return
        end
        lastResetTime[player] = now
        startRun(player)
    elseif action == "ClaimDailyReward" then
        checkDailyReward(player, state)
    elseif action == "BuyTrail" then
        local trailId = ...
        if type(trailId) ~= "string" then return end
        -- Find trail in config
        for _, trail in ipairs(Config.COSMETICS.TRAILS) do
            if trail.id == trailId then
                if state.data.totalCoins >= trail.cost then
                    -- Check if already owned
                    local alreadyOwned = false
                    for _, owned in ipairs(state.settings.ownedTrails) do
                        if owned == trailId then
                            alreadyOwned = true
                            break
                        end
                    end
                    if not alreadyOwned then
                        state.data.totalCoins -= trail.cost
                        table.insert(state.settings.ownedTrails, trailId)
                        state.settings.equippedTrail = trailId
                        refreshLeaderstats(player, state)
                        task.spawn(function()
                            DataManager.savePlayerData(player, DataManager.cloneData(state.data))
                            DataManager.savePlayerSettings(player, DataManager.cloneSettings(state.settings))
                        end)
                        uiUpdateEvent:FireClient(player, {
                            type = "PurchaseSuccess",
                            data = { item = trailId, type = "trail", cost = trail.cost },
                        })
                    end
                else
                    uiUpdateEvent:FireClient(player, {
                        type = "PurchaseFailed",
                        data = { reason = "not_enough_coins" },
                    })
                end
                break
            end
        end
    end
end)

----------------------------------------------------------------
-- Developer Products (Coin Packs)
-- CRITICAL: Receipt journal prevents duplicate grants on Roblox retry.
----------------------------------------------------------------
local processedReceipts: { [string]: boolean } = {}

MarketplaceService.ProcessReceipt = function(receiptInfo)
    -- Deduplication: if we've already processed this PurchaseId, grant immediately
    local purchaseId = receiptInfo.PurchaseId
    if processedReceipts[purchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    
    local state = playerStates[player]
    if not state then return Enum.ProductPurchaseDecision.NotProcessedYet end
    
    -- Strict ID matching — never use product name for security-critical branching
    for _, product in pairs(Config.DEV_PRODUCTS) do
        if product.id == receiptInfo.ProductId then
            -- Log for audit trail
            print(string.format("[Monetization] Granting %s (%d coins) to %s (PurchaseId: %s)",
                product.name, product.amount, player.Name, purchaseId))
            
            state.data.totalCoins += product.amount
            refreshLeaderstats(player, state)
            
            -- Mark as processed BEFORE async save so retry doesn't re-grant
            processedReceipts[purchaseId] = true
            
            task.spawn(function()
                DataManager.savePlayerData(player, DataManager.cloneData(state.data))
            end)
            
            uiUpdateEvent:FireClient(player, {
                type = "CoinPurchase",
                data = { amount = product.amount },
            })
            
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

----------------------------------------------------------------
-- Player Lifecycle
----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player: Player)
    -- Load all data
    local data = DataManager.loadPlayerData(player)
    local settings = DataManager.loadPlayerSettings(player)
    local daily = DataManager.loadDailyReward(player)
    
    -- Check gamepasses
    local hasDoubleCoins = false
    local hasVIP = false
    local isPremium = false
    
    pcall(function()
        hasDoubleCoins = MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.GAMEPASSES.DOUBLE_COINS.id)
    end)
    pcall(function()
        hasVIP = MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.GAMEPASSES.VIP.id)
    end)
    pcall(function()
        isPremium = player.MembershipType == Enum.MembershipType.Premium
    end)
    
    playerStates[player] = {
        data = data,
        settings = settings,
        daily = daily,
        startTime = nil,
        lastCheckpointTime = nil,
        checkpointsReached = 0,
        coinsCollectedThisRun = {},
        coinsThisRun = 0,
        isRunning = false,
        lastCheckpointPos = nil,
        comboCount = 0,
        comboMultiplier = 1.0,
        lastComboCheckpointTime = nil,
        hasDoubleCoins = hasDoubleCoins,
        hasVIP = hasVIP,
        isPremium = isPremium,
    }

    setupLeaderstats(player, data)
    
    -- VIP tag
    if hasVIP then
        local tag = Instance.new("StringValue")
        tag.Name = "VIPTag"
        tag.Value = "[VIP]"
        tag.Parent = player
    end

    -- Auto-start after delay
    task.delay(AUTO_START_DELAY, function()
        if not player.Parent then return end
        local state = playerStates[player]
        if not state then return end
        if state.isRunning then return end

        uiUpdateEvent:FireClient(player, {
            type = "DataLoaded",
            data = {
                bestTime = data.bestRunTimeSeconds,
                totalCoins = data.totalCoins,
                totalRuns = data.totalRuns,
                totalCheckpoints = totalCheckpoints,
                hasDoubleCoins = hasDoubleCoins,
                hasVIP = hasVIP,
                isPremium = isPremium,
                settings = settings,
                daily = daily,
            },
        })
        startRun(player)
    end)

    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if not player.Parent then return end
        local state = playerStates[player]
        if not state then return end
        if not character.Parent then return end
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if not hrp or not hrp:IsA("BasePart") then return end
        if state.isRunning and state.lastCheckpointPos then
            hrp.CFrame = CFrame.new(state.lastCheckpointPos)
        else
            startRun(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    local state = playerStates[player]
    if state then
        local dataSnapshot = DataManager.cloneData(state.data)
        local settingsSnapshot = DataManager.cloneSettings(state.settings)
        local dailySnapshot = DataManager.cloneDaily(state.daily)
        playerStates[player] = nil
        task.spawn(function()
            DataManager.savePlayerData(player, dataSnapshot)
            DataManager.savePlayerSettings(player, settingsSnapshot)
            DataManager.saveDailyReward(player, dailySnapshot)
        end)
    end
    lastResetTime[player] = nil
    lastTouchTime[player] = nil
    lastTouchPart[player] = nil
end)

----------------------------------------------------------------
-- BindToClose
----------------------------------------------------------------
game:BindToClose(function()
    local activeSaves = 0
    local bindThread = coroutine.running()

    local statesToSave: { [Player]: PlayerState } = {}
    for player, state in pairs(playerStates) do
        statesToSave[player] = state
        playerStates[player] = nil
    end

    for player, state in pairs(statesToSave) do
        local dataSnapshot = DataManager.cloneData(state.data)
        local settingsSnapshot = DataManager.cloneSettings(state.settings)
        local dailySnapshot = DataManager.cloneDaily(state.daily)
        activeSaves += 1
        task.spawn(function()
            DataManager.savePlayerData(player, dataSnapshot)
            DataManager.savePlayerSettings(player, settingsSnapshot)
            DataManager.saveDailyReward(player, dailySnapshot)
            activeSaves -= 1
            if activeSaves == 0 and coroutine.status(bindThread) == "suspended" then
                task.spawn(bindThread)
            end
        end)
    end
    
    if activeSaves > 0 then
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
print("[GameServer] Brainrot Checkpoint Obby S-TIER initialized!")
