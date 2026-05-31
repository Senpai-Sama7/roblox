--[[
    ModuleScript: ServerScriptService/DataManager
    Server-side ONLY. Wraps DataStoreService with pcall + exponential backoff.
    
    Schema v2 per player (core stats - atomic merge):
        bestRunTimeSeconds: number (lower is better, default 999999)
        totalRuns:          number
        totalCoins:         number
    
    Schema v2 per player (settings - SetAsync, no merge needed):
        settings: {
            sfxEnabled: boolean,
            musicEnabled: boolean,
            trailEnabled: boolean,
            trailColor: {r: number, g: number, b: number},
            ownedTrails: {string},
            ownedAuras: {string},
            equippedTrail: string?,
            equippedAura: string?,
        }
        dailyReward: {
            lastClaimDate: string, -- YYYY-MM-DD
            streak: number,
        }
]]

local DataManager = {}

local taskLib = task
if not taskLib then
	local ok, luneTask = pcall(require, "@lune/task")
	if ok then
		taskLib = luneTask
	end
end

function DataManager.setTaskLib(lib: any)
	taskLib = lib
end

assert(taskLib, "[DataManager] task library not available. In Lune, call DataManager.setTaskLib(require('@lune/task')) before use.")

local STORE_NAME = "ObbyPlayerData_v2"
local SETTINGS_NAME = "ObbyPlayerSettings_v1"
local MAX_RETRIES = 3
local BASE_DELAY = 1 -- seconds

type DataStoreLike = {
    GetAsync: (self: DataStoreLike, key: string) -> any?,
    UpdateAsync: (self: DataStoreLike, key: string, transform: (any?) -> any?) -> any?,
    SetAsync: (self: DataStoreLike, key: string, value: any) -> (),
}

-- Lazy-init: dataStore resolved on first use so test environments can inject a mock
local dataStore: DataStoreLike? = nil

local function getDataStore(): DataStoreLike
    if not dataStore then
        local DataStoreService = game:GetService("DataStoreService")
        dataStore = DataStoreService:GetDataStore(STORE_NAME) :: any
    end
    return dataStore :: DataStoreLike
end

local settingsStore: DataStoreLike? = nil

local function getSettingsStore(): DataStoreLike
    if not settingsStore then
        local DataStoreService = game:GetService("DataStoreService")
        settingsStore = DataStoreService:GetDataStore(SETTINGS_NAME) :: any
    end
    return settingsStore :: DataStoreLike
end

-- For unit testing: inject a mock DataStore before any operations
function DataManager.setDataStore(mockStore: DataStoreLike)
    dataStore = mockStore
    settingsStore = mockStore
end

export type PlayerData = {
    bestRunTimeSeconds: number,
    totalRuns: number,
    totalCoins: number,
}

export type PlayerSettings = {
    sfxEnabled: boolean,
    musicEnabled: boolean,
    trailEnabled: boolean,
    trailColor: { r: number, g: number, b: number },
    ownedTrails: { string },
    ownedAuras: { string },
    equippedTrail: string?,
    equippedAura: string?,
}

export type DailyRewardState = {
    lastClaimDate: string,
    streak: number,
}

export type ExtendedPlayerData = {
    stats: PlayerData,
    settings: PlayerSettings,
    dailyReward: DailyRewardState,
}

local DEFAULT_DATA: PlayerData = {
    bestRunTimeSeconds = 999999,
    totalRuns = 0,
    totalCoins = 0,
}

local DEFAULT_SETTINGS: PlayerSettings = {
    sfxEnabled = true,
    musicEnabled = true,
    trailEnabled = true,
    trailColor = { r = 255, g = 255, b = 255 },
    ownedTrails = {},
    ownedAuras = {},
    equippedTrail = nil,
    equippedAura = nil,
}

local DEFAULT_DAILY: DailyRewardState = {
    lastClaimDate = "",
    streak = 0,
}

local function cloneData(original: PlayerData): PlayerData
    return table.clone(original)
end
DataManager.cloneData = cloneData

local function cloneSettings(original: PlayerSettings): PlayerSettings
    local copy = table.clone(original)
    copy.trailColor = table.clone(original.trailColor)
    copy.ownedTrails = table.clone(original.ownedTrails)
    copy.ownedAuras = table.clone(original.ownedAuras)
    return copy
end
DataManager.cloneSettings = cloneSettings

local function cloneDaily(original: DailyRewardState): DailyRewardState
    return table.clone(original)
end
DataManager.cloneDaily = cloneDaily

local function isFinite(n: number): boolean
    return n == n and n ~= math.huge and n ~= -math.huge
end

local function sanitizeNumber(n: number, default: number): number
    if type(n) ~= "number" or not isFinite(n) then
        return default
    end
    return n
end

-- Retry wrapper: attempts `callback` up to MAX_RETRIES with exponential backoff
local function retryAsync(opName: string, callback: () -> any): (boolean, any)
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(callback)
        if success then
            return true, result
        end
        warn(string.format("[DataManager] %s failed (attempt %d/%d): %s",
            opName, attempt, MAX_RETRIES, tostring(result)))
        if attempt < MAX_RETRIES then
            taskLib.wait(BASE_DELAY * (2 ^ (attempt - 1)))
        end
    end
    return false, nil
end

-- ----------------------------------------------------------------
-- Core Stats (atomic merge via UpdateAsync)
-- ----------------------------------------------------------------

function DataManager.loadPlayerData(player: Player): PlayerData
    local key = "Player_" .. player.UserId
    local success, data = retryAsync("GetAsync", function()
        return getDataStore():GetAsync(key)
    end)

    if success and data and type(data) == "table" then
        local merged = cloneData(DEFAULT_DATA)
        for k, v in pairs(data) do
            if DEFAULT_DATA[k] ~= nil and type(v) == type(DEFAULT_DATA[k]) then
                merged[k] = v
            end
        end
        -- NaN + infinite guards
        merged.bestRunTimeSeconds = math.clamp(sanitizeNumber(merged.bestRunTimeSeconds, DEFAULT_DATA.bestRunTimeSeconds), 0, 999999)
        merged.totalRuns = math.max(0, math.floor(sanitizeNumber(merged.totalRuns, DEFAULT_DATA.totalRuns)))
        merged.totalCoins = math.max(0, math.floor(sanitizeNumber(merged.totalCoins, DEFAULT_DATA.totalCoins)))
        print(string.format("[DataManager] Loaded stats for %s", player.Name))
        return merged
    end

    print(string.format("[DataManager] Using default stats for %s", player.Name))
    return cloneData(DEFAULT_DATA)
end

function DataManager.savePlayerData(player: Player, data: PlayerData, forceOverwrite: boolean?): boolean
    -- Pre-sanitize: NaN or non-finite values in the incoming snapshot corrupt the merge.
    local safeData: PlayerData = {
        bestRunTimeSeconds = math.clamp(sanitizeNumber(data.bestRunTimeSeconds, DEFAULT_DATA.bestRunTimeSeconds), 0, 999999),
        totalRuns = math.max(0, math.floor(sanitizeNumber(data.totalRuns, DEFAULT_DATA.totalRuns))),
        totalCoins = math.max(0, math.floor(sanitizeNumber(data.totalCoins, DEFAULT_DATA.totalCoins))),
    }
    
    local key = "Player_" .. player.UserId
    local success, _ = retryAsync("UpdateAsync", function()
        return getDataStore():UpdateAsync(key, function(oldData)
            if forceOverwrite or not oldData or type(oldData) ~= "table" then
                return safeData
            end
            local oldBest = sanitizeNumber(oldData.bestRunTimeSeconds or 999999, 999999)
            local oldRuns = math.floor(sanitizeNumber(oldData.totalRuns or 0, 0))
            local oldCoins = math.floor(sanitizeNumber(oldData.totalCoins or 0, 0))

            return {
                bestRunTimeSeconds = math.min(safeData.bestRunTimeSeconds, oldBest),
                totalRuns = math.max(safeData.totalRuns, oldRuns),
                totalCoins = math.max(safeData.totalCoins, oldCoins),
            }
        end)
    end)

    if success then
        print(string.format("[DataManager] Saved stats for %s", player.Name))
    else
        warn(string.format("[DataManager] FAILED to save stats for %s after %d retries",
            player.Name, MAX_RETRIES))
    end
    return success
end

-- ----------------------------------------------------------------
-- Settings (SetAsync - per-player, no cross-server conflict)
-- ----------------------------------------------------------------

function DataManager.loadPlayerSettings(player: Player): PlayerSettings
    local key = "Settings_" .. player.UserId
    local success, data = retryAsync("SettingsGet", function()
        return getSettingsStore():GetAsync(key)
    end)

    if success and data and type(data) == "table" then
        local merged = cloneSettings(DEFAULT_SETTINGS)
        for k, v in pairs(data) do
            if DEFAULT_SETTINGS[k] ~= nil and type(v) == type(DEFAULT_SETTINGS[k]) then
                if type(v) == "table" then
                    merged[k] = table.clone(v)
                else
                    merged[k] = v
                end
            end
        end
        return merged
    end

    return cloneSettings(DEFAULT_SETTINGS)
end

function DataManager.savePlayerSettings(player: Player, settings: PlayerSettings): boolean
    local key = "Settings_" .. player.UserId
    local success, _ = retryAsync("SettingsSet", function()
        getSettingsStore():SetAsync(key, settings)
        return true
    end)

    if not success then
        warn(string.format("[DataManager] FAILED to save settings for %s", player.Name))
    end
    return success
end

-- ----------------------------------------------------------------
-- Daily Rewards (stored in settings store)
-- ----------------------------------------------------------------

function DataManager.loadDailyReward(player: Player): DailyRewardState
    local key = "Daily_" .. player.UserId
    local success, data = retryAsync("DailyGet", function()
        return getSettingsStore():GetAsync(key)
    end)

    if success and data and type(data) == "table" then
        local merged = cloneDaily(DEFAULT_DAILY)
        for k, v in pairs(data) do
            if DEFAULT_DAILY[k] ~= nil and type(v) == type(DEFAULT_DAILY[k]) then
                merged[k] = v
            end
        end
        return merged
    end

    return cloneDaily(DEFAULT_DAILY)
end

function DataManager.saveDailyReward(player: Player, daily: DailyRewardState): boolean
    local key = "Daily_" .. player.UserId
    local success, _ = retryAsync("DailySet", function()
        getSettingsStore():SetAsync(key, daily)
        return true
    end)
    return success
end

-- ----------------------------------------------------------------
-- Utilities
-- ----------------------------------------------------------------

function DataManager.getDefaultData(): PlayerData
    return cloneData(DEFAULT_DATA)
end

function DataManager.getDefaultSettings(): PlayerSettings
    return cloneSettings(DEFAULT_SETTINGS)
end

return DataManager
