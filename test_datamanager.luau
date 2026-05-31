--[[
    Test: test_datamanager.luau
    S-TIER test suite for DataManager v2.
    Tests core stats, settings, daily rewards, and NaN recovery.
]]

local taskModule = task
if not taskModule then
	taskModule = require("@lune/task")
end

local task_orig_wait = taskModule.wait
local taskProxy = {
	wait = function(_sec: number?)
		return
	end,
	spawn = taskModule.spawn,
	delay = taskModule.delay,
	cancel = taskModule.cancel,
	defer = taskModule.defer,
}

-- ----------------------------------------------------------------
-- Mock DataStore (v2: supports SetAsync)
-- ----------------------------------------------------------------
local dataStoreStore: {[string]: any} = {}
local mockFailuresCount = 0
local mockFailuresTarget = 0

local mockDataStore = {}

function mockDataStore:GetAsync(key: string): any?
    if mockFailuresCount < mockFailuresTarget then
        mockFailuresCount += 1
        error("Simulated transient GetAsync error for key: " .. key)
    end
    return dataStoreStore[key]
end

function mockDataStore:UpdateAsync(key: string, callback: (any?) -> any?): any?
    if mockFailuresCount < mockFailuresTarget then
        mockFailuresCount += 1
        error("Simulated transient UpdateAsync error for key: " .. key)
    end
    local oldVal = dataStoreStore[key]
    local newVal = callback(oldVal)
    if newVal ~= nil then
        dataStoreStore[key] = newVal
    end
    return newVal
end

function mockDataStore:SetAsync(key: string, value: any)
    if mockFailuresCount < mockFailuresTarget then
        mockFailuresCount += 1
        error("Simulated transient SetAsync error for key: " .. key)
    end
    dataStoreStore[key] = value
end

-- ----------------------------------------------------------------
-- Mock Player
-- ----------------------------------------------------------------
type MockPlayer = {
    UserId: number,
    Name: string,
}

local function createMockPlayer(id: number, name: string): MockPlayer
    return { UserId = id, Name = name }
end

-- ----------------------------------------------------------------
-- Load DataManager with mock store injected
-- ----------------------------------------------------------------
local DataManager = require("./src/ServerScriptService/DataManager")
DataManager.setDataStore(mockDataStore)
DataManager.setTaskLib(taskProxy)

-- ----------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------
local function clearDb()
    dataStoreStore = {}
    mockFailuresCount = 0
    mockFailuresTarget = 0
end

-- ----------------------------------------------------------------
-- T1: Load player data - returns defaults when no entry exists
-- ----------------------------------------------------------------
local function testLoadDefaultData()
    clearDb()
    local player = createMockPlayer(10001, "Alice")
    local data = DataManager.loadPlayerData(player :: any)

    assert(data.bestRunTimeSeconds == 999999, "T1: Expected default bestRunTimeSeconds")
    assert(data.totalRuns == 0,               "T1: Expected 0 totalRuns")
    assert(data.totalCoins == 0,              "T1: Expected 0 totalCoins")
    print("✓ T1: Default data load verified")
end

-- ----------------------------------------------------------------
-- T2: Save and load round-trip
-- ----------------------------------------------------------------
local function testSaveAndLoad()
    clearDb()
    local player = createMockPlayer(10002, "Bob")
    local customData = {
        bestRunTimeSeconds = 45.67,
        totalRuns = 12,
        totalCoins = 150,
    }

    local ok = DataManager.savePlayerData(player :: any, customData :: any)
    assert(ok, "T2: Expected save to succeed")

    local loaded = DataManager.loadPlayerData(player :: any)
    assert(loaded.bestRunTimeSeconds == 45.67, "T2: Unexpected bestRunTimeSeconds")
    assert(loaded.totalRuns == 12,             "T2: Unexpected totalRuns")
    assert(loaded.totalCoins == 150,           "T2: Unexpected totalCoins")
    print("✓ T2: Standard Save & Load verified")
end

-- ----------------------------------------------------------------
-- T3: Schema merge and sanitization of corrupted data
-- ----------------------------------------------------------------
local function testLoadMergingAndSanitization()
    clearDb()
    local player = createMockPlayer(10003, "Carol")

    dataStoreStore["Player_10003"] = {
        bestRunTimeSeconds = -10,
        totalRuns = 5.6,
        totalCoins = -50,
        unknownField = "hack",
    }

    local loaded = DataManager.loadPlayerData(player :: any)
    assert(loaded.bestRunTimeSeconds == 0,  "T3: bestRunTimeSeconds should clamp to 0")
    assert(loaded.totalRuns == 5,           "T3: totalRuns should floor to 5")
    assert(loaded.totalCoins == 0,          "T3: totalCoins should clamp to 0")
    assert((loaded :: any).unknownField == nil, "T3: unknownField should be stripped")
    print("✓ T3: Schema merge and sanitization verified")
end

-- ----------------------------------------------------------------
-- T4: Transient failures -> retry -> success within MAX_RETRIES
-- ----------------------------------------------------------------
local function testRetrySuccess()
    clearDb()
    local player = createMockPlayer(10004, "Dave")

    mockFailuresTarget = 2
    local ok = DataManager.savePlayerData(player :: any, {
        bestRunTimeSeconds = 30.0,
        totalRuns = 1,
        totalCoins = 10,
    } :: any)
    assert(ok, "T4: Expected save to succeed after 2 retries")
    assert(mockFailuresCount == 2, "T4: Expected exactly 2 simulated failures on save, got " .. mockFailuresCount)

    mockFailuresCount = 0
    mockFailuresTarget = 2
    local loaded = DataManager.loadPlayerData(player :: any)
    assert(loaded.bestRunTimeSeconds == 30.0, "T4: Unexpected bestRunTimeSeconds after retry load")
    assert(mockFailuresCount == 2, "T4: Expected exactly 2 simulated failures on load, got " .. mockFailuresCount)
    print("✓ T4: Transient failure and exponential retry verified")
end

-- ----------------------------------------------------------------
-- T5: Exceeds MAX_RETRIES -> returns failure + safe default on load
-- ----------------------------------------------------------------
local function testRetryFailure()
    clearDb()
    local player = createMockPlayer(10005, "Eve")

    mockFailuresTarget = 4
    local ok = DataManager.savePlayerData(player :: any, {
        bestRunTimeSeconds = 30.0,
        totalRuns = 1,
        totalCoins = 10,
    } :: any)
    assert(not ok, "T5: Expected save to fail after exceeding MAX_RETRIES")

    mockFailuresCount = 0
    mockFailuresTarget = 4
    local loaded = DataManager.loadPlayerData(player :: any)
    assert(loaded.bestRunTimeSeconds == 999999, "T5: Expected default fallback on permanent load failure")
    print("✓ T5: Absolute retry bounds and safe fallback verified")
end

-- ----------------------------------------------------------------
-- T6: Atomic merge conflict resolution
-- ----------------------------------------------------------------
local function testAtomicMergeConflict()
    clearDb()
    local player = createMockPlayer(10006, "Frank")

    dataStoreStore["Player_10006"] = {
        bestRunTimeSeconds = 120.0,
        totalRuns = 5,
        totalCoins = 50,
    }

    DataManager.savePlayerData(player :: any, {
        bestRunTimeSeconds = 150.0,
        totalRuns = 6,
        totalCoins = 100,
    } :: any)

    local v1 = DataManager.loadPlayerData(player :: any)
    assert(v1.bestRunTimeSeconds == 120.0, "T6a: Expected retained best time (120s), got " .. v1.bestRunTimeSeconds)
    assert(v1.totalRuns == 6,              "T6a: Expected max totalRuns (6), got " .. v1.totalRuns)
    assert(v1.totalCoins == 100,           "T6a: Expected max totalCoins (100), got " .. v1.totalCoins)

    DataManager.savePlayerData(player :: any, {
        bestRunTimeSeconds = 90.0,
        totalRuns = 4,
        totalCoins = 30,
    } :: any)

    local v2 = DataManager.loadPlayerData(player :: any)
    assert(v2.bestRunTimeSeconds == 90.0, "T6b: Expected new best time (90s), got " .. v2.bestRunTimeSeconds)
    assert(v2.totalRuns == 6,             "T6b: Expected retained max totalRuns (6), got " .. v2.totalRuns)
    assert(v2.totalCoins == 100,          "T6b: Expected retained max totalCoins (100), got " .. v2.totalCoins)

    print("✓ T6: Atomic merge conflict resolution verified")
end

-- ----------------------------------------------------------------
-- T7: NaN corruption recovery
-- ----------------------------------------------------------------
local function testNaNRecovery()
    clearDb()
    local player = createMockPlayer(10007, "Grace")

    dataStoreStore["Player_10007"] = {
        bestRunTimeSeconds = 0 / 0,
        totalRuns = 0 / 0,
        totalCoins = 0 / 0,
    }

    local loaded = DataManager.loadPlayerData(player :: any)
    assert(loaded.bestRunTimeSeconds == 999999, "T7: NaN bestRunTimeSeconds should fallback to default")
    assert(loaded.totalRuns == 0,               "T7: NaN totalRuns should fallback to default")
    assert(loaded.totalCoins == 0,              "T7: NaN totalCoins should fallback to default")

    DataManager.savePlayerData(player :: any, {
        bestRunTimeSeconds = 60.0,
        totalRuns = 1,
        totalCoins = 10,
    } :: any)

    local saved = DataManager.loadPlayerData(player :: any)
    assert(saved.bestRunTimeSeconds == 60.0, "T7: Save after NaN recovery should work")
    assert(saved.totalRuns == 1,             "T7: totalRuns after NaN recovery should work")
    assert(saved.totalCoins == 10,           "T7: totalCoins after NaN recovery should work")

    print("✓ T7: NaN corruption recovery verified")
end

-- ----------------------------------------------------------------
-- T8: Settings save and load
-- ----------------------------------------------------------------
local function testSettingsSaveAndLoad()
    clearDb()
    local player = createMockPlayer(10008, "Hannah")

    local defaultSettings = DataManager.getDefaultSettings()
    assert(defaultSettings.sfxEnabled == true, "T8: Default sfxEnabled should be true")
    assert(#defaultSettings.ownedTrails == 0,  "T8: Default ownedTrails should be empty")

    local customSettings = table.clone(defaultSettings)
    customSettings.sfxEnabled = false
    customSettings.trailColor = { r = 255, g = 0, b = 0 }
    customSettings.ownedTrails = { "rainbow", "fire" }
    customSettings.equippedTrail = "rainbow"

    DataManager.savePlayerSettings(player :: any, customSettings)

    local loaded = DataManager.loadPlayerSettings(player :: any)
    assert(loaded.sfxEnabled == false, "T8: sfxEnabled should persist")
    assert(loaded.trailColor.r == 255, "T8: trailColor should persist")
    assert(#loaded.ownedTrails == 2,   "T8: ownedTrails should persist")
    assert(loaded.equippedTrail == "rainbow", "T8: equippedTrail should persist")

    print("✓ T8: Settings save and load verified")
end

-- ----------------------------------------------------------------
-- T9: Daily reward save and load
-- ----------------------------------------------------------------
local function testDailyRewardSaveAndLoad()
    clearDb()
    local player = createMockPlayer(10009, "Ian")

    local daily = {
        lastClaimDate = "2025-12-25",
        streak = 5,
    }

    DataManager.saveDailyReward(player :: any, daily)

    local loaded = DataManager.loadDailyReward(player :: any)
    assert(loaded.lastClaimDate == "2025-12-25", "T9: lastClaimDate should persist")
    assert(loaded.streak == 5,                   "T9: streak should persist")

    print("✓ T9: Daily reward save and load verified")
end

-- ----------------------------------------------------------------
-- Run all test cases
-- ----------------------------------------------------------------
testLoadDefaultData()
testSaveAndLoad()
testLoadMergingAndSanitization()
testRetrySuccess()
testRetryFailure()
testAtomicMergeConflict()
testNaNRecovery()
testSettingsSaveAndLoad()
testDailyRewardSaveAndLoad()

taskProxy.wait = task_orig_wait

print("\nAll DataManager S-tier test suites completed successfully. ✓")
