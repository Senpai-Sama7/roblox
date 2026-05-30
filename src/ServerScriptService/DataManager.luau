--[[
    ModuleScript: ServerScriptService/DataManager
    Server-side ONLY. Wraps DataStoreService with pcall + exponential backoff.
    
    Schema per player:
        bestRunTimeSeconds: number (lower is better, default 999999)
        totalRuns:          number
        totalCoins:         number
]]

local DataStoreService = game:GetService("DataStoreService")

local DataManager = {}

local STORE_NAME = "ObbyPlayerData_v1"
local MAX_RETRIES = 3
local BASE_DELAY = 1 -- seconds

local dataStore = DataStoreService:GetDataStore(STORE_NAME)

export type PlayerData = {
    bestRunTimeSeconds: number,
    totalRuns: number,
    totalCoins: number,
}

local DEFAULT_DATA: PlayerData = {
    bestRunTimeSeconds = 999999,
    totalRuns = 0,
    totalCoins = 0,
}

-- Deep copy utility
local function deepCopy(original: PlayerData): PlayerData
    local copy: PlayerData = table.clone(original)
    return copy
end

-- Retry wrapper: attempts `callback` up to MAX_RETRIES with exponential backoff.
local function retryAsync(opName: string, callback: () -> any): (boolean, any)
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(callback)
        if success then
            return true, result
        end
        warn(string.format("[DataManager] %s failed (attempt %d/%d): %s",
            opName, attempt, MAX_RETRIES, tostring(result)))
        if attempt < MAX_RETRIES then
            task.wait(BASE_DELAY * (2 ^ (attempt - 1)))
        end
    end
    return false, nil
end

-- Load player data from DataStore, merging with defaults for forward-compat.
function DataManager.loadPlayerData(player: Player): PlayerData
    local key = "Player_" .. player.UserId
    local success, data = retryAsync("GetAsync", function()
        return dataStore:GetAsync(key)
    end)

    if success and data and type(data) == "table" then
        local merged = deepCopy(DEFAULT_DATA)
        for k, v in pairs(data) do
            -- Only merge fields that exist in the schema and match expected types
            if DEFAULT_DATA[k] ~= nil and type(v) == type(DEFAULT_DATA[k]) then
                merged[k] = v
            end
        end
        -- Sanity-clamp values to prevent corrupted data from breaking the game
        merged.bestRunTimeSeconds = math.clamp(merged.bestRunTimeSeconds, 0, 999999)
        merged.totalRuns = math.max(0, math.floor(merged.totalRuns))
        merged.totalCoins = math.max(0, math.floor(merged.totalCoins))
        print(string.format("[DataManager] Loaded data for %s", player.Name))
        return merged
    end

    print(string.format("[DataManager] Using defaults for %s", player.Name))
    return deepCopy(DEFAULT_DATA)
end

-- Save player data to DataStore using UpdateAsync with true atomic merge.
-- If another server wrote data between our read and write, we merge
-- by taking the best (lowest) run time and the highest coin/run totals.
-- This prevents last-write-wins data loss during cross-server saves.
function DataManager.savePlayerData(player: Player, data: PlayerData): boolean
    local key = "Player_" .. player.UserId
    local success, _ = retryAsync("UpdateAsync", function()
        return dataStore:UpdateAsync(key, function(oldData)
            if not oldData or type(oldData) ~= "table" then
                return data
            end
            -- Atomic merge: resolve conflicts conservatively
            return {
                bestRunTimeSeconds = math.min(
                    data.bestRunTimeSeconds,
                    oldData.bestRunTimeSeconds or 999999
                ),
                totalRuns = math.max(
                    data.totalRuns,
                    oldData.totalRuns or 0
                ),
                totalCoins = math.max(
                    data.totalCoins,
                    oldData.totalCoins or 0
                ),
            }
        end)
    end)

    if success then
        print(string.format("[DataManager] Saved data for %s", player.Name))
    else
        warn(string.format("[DataManager] FAILED to save for %s after %d retries",
            player.Name, MAX_RETRIES))
    end
    return success
end

function DataManager.getDefaultData(): PlayerData
    return deepCopy(DEFAULT_DATA)
end

return DataManager
