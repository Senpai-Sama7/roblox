--[[
    GenerateLevelData — Ultimate Studio Utility
    
    Hybrid workflow: Tagged-first, Auto-suggest fallback.
    
    MODE A — TAGGED PARTS:
        If Workspace contains CollectionService-tagged parts
        ("Checkpoint", "Coin", "FinishLine"), exports their positions
        exactly into a LevelData module string.
    
    MODE B — AUTO-SUGGEST (Zero-tag fallback):
        If no tagged parts exist, analyzes ALL BaseParts in Workspace,
        clusters them by height tiers, and auto-generates a playable
        checkpoint/coin/finish layout based on bounding-box geometry.
        This lets you generate LevelData from ANY level, even one
        imported from glTF with zero Roblox metadata.
    
    USAGE:
        1. Place this in ServerScriptService
        2. Run in Studio (Play or Command bar: require(script).generate())
        3. Copy the printed output block into src/ReplicatedStorage/LevelData.luau
        4. Set USE_FALLBACK = true in that module
    
    API:
        require(script).generate()          -> prints LevelData source
        require(script).getSuggestedData()  -> returns {checkpoints, coins, finish, spawn} tables
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GenerateLevelData = {}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function fmtVec3(v: Vector3): string
    return string.format("Vector3.new(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end

local function getTaggedParts(tag: string, classCheck: string?): {BasePart}
    local result = {}
    for _, inst in ipairs(CollectionService:GetTagged(tag)) do
        if inst:IsA(classCheck or "BasePart") then
            table.insert(result, inst)
        end
    end
    return result
end

----------------------------------------------------------------
-- Mode A: Tagged parts extraction
----------------------------------------------------------------

local function extractTagged(): (table, table, Vector3?, Vector3?)
    local checkpoints = {}
    for _, cp in ipairs(getTaggedParts("Checkpoint")) do
        local order = cp:GetAttribute("Order")
        if type(order) ~= "number" then order = 0 end
        table.insert(checkpoints, {
            position = cp.Position,
            order = order,
        })
    end
    table.sort(checkpoints, function(a, b) return a.order < b.order end)

    local coins = {}
    for _, coin in ipairs(getTaggedParts("Coin")) do
        table.insert(coins, coin.Position)
    end

    local finishLine: Vector3? = nil
    for _, fl in ipairs(getTaggedParts("FinishLine")) do
        finishLine = fl.Position
        break
    end

    local spawnPos: Vector3? = nil
    for _, spawn in ipairs(getTaggedParts("SpawnLocation")) do
        spawnPos = spawn.Position
        break
    end
    -- Also check Workspace SpawnLocation by class name
    if not spawnPos then
        for _, child in ipairs(game.Workspace:GetDescendants()) do
            if child:IsA("SpawnLocation") then
                spawnPos = child.Position
                break
            end
        end
    end

    return checkpoints, coins, finishLine, spawnPos
end

----------------------------------------------------------------
-- Mode B: Auto-suggest from workspace geometry
----------------------------------------------------------------

local function getWorkspaceParts(): {BasePart}
    local parts = {}
    for _, desc in ipairs(game.Workspace:GetDescendants()) do
        if desc:IsA("BasePart") and not desc:IsA("Terrain") then
            -- Exclude very small decorative parts to reduce noise
            if desc.Size.Magnitude > 1.5 then
                table.insert(parts, desc)
            end
        end
    end
    return parts
end

local function computeBounds(parts: {BasePart}): (Vector3, Vector3)
    if #parts == 0 then
        return Vector3.new(0, 0, 0), Vector3.new(100, 100, 100)
    end
    local minV = parts[1].Position - parts[1].Size / 2
    local maxV = parts[1].Position + parts[1].Size / 2
    for i = 2, #parts do
        local p = parts[i]
        local pMin = p.Position - p.Size / 2
        local pMax = p.Position + p.Size / 2
        minV = Vector3.new(math.min(minV.X, pMin.X), math.min(minV.Y, pMin.Y), math.min(minV.Z, pMin.Z))
        maxV = Vector3.new(math.max(maxV.X, pMax.X), math.max(maxV.Y, pMax.Y), math.max(maxV.Z, pMax.Z))
    end
    return minV, maxV
end

local function autoSuggestCourse(): (table, table, Vector3, Vector3)
    local parts = getWorkspaceParts()
    local minB, maxB = computeBounds(parts)
    local center = (minB + maxB) / 2
    local size = maxB - minB

    -- Find spawn: prefer actual SpawnLocation, else lowest-center point
    local spawnPos = center
    for _, p in ipairs(parts) do
        if p:IsA("SpawnLocation") then
            spawnPos = p.Position
            break
        end
    end

    -- Height tiers for clustering
    local lowY = minB.Y + size.Y * 0.15
    local midY = minB.Y + size.Y * 0.45
    local highY = minB.Y + size.Y * 0.75

    -- Collect candidate points per tier (use part centers)
    local lowPoints = {}
    local midPoints = {}
    local highPoints = {}
    for _, p in ipairs(parts) do
        local pos = p.Position
        if pos.Y < lowY then
            table.insert(lowPoints, pos)
        elseif pos.Y < midY then
            table.insert(midPoints, pos)
        else
            table.insert(highPoints, pos)
        end
    end

    local function pickExtreme(points: {Vector3}, compareFn): Vector3?
        if #points == 0 then return nil end
        local best = points[1]
        for i = 2, #points do
            if compareFn(points[i], best) then best = points[i] end
        end
        return best
    end

    local function avgOfFarthest(points: {Vector3}, ref: Vector3, count: number): Vector3
        if #points == 0 then return ref end
        local sorted = {}
        for _, p in ipairs(points) do
            table.insert(sorted, {pos = p, dist = (p - ref).Magnitude})
        end
        table.sort(sorted, function(a, b) return a.dist > b.dist end)
        local sum = Vector3.new(0, 0, 0)
        local c = math.min(count, #sorted)
        for i = 1, c do
            sum = sum + sorted[i].pos
        end
        return sum / c
    end

    -- Build a logical path: spawn -> low extremes -> mid extremes -> high extremes -> finish
    local checkpoints = {}
    local function addCp(pos: Vector3, order: number)
        table.insert(checkpoints, {position = pos, order = order})
    end

    addCp(spawnPos, 1)

    -- CP2: farthest low point from spawn (explore outward)
    if #lowPoints > 0 then
        local farLow = pickExtreme(lowPoints, function(a, b)
            return (a - spawnPos).Magnitude > (b - spawnPos).Magnitude
        end)
        if farLow and (farLow - spawnPos).Magnitude > 10 then
            addCp(farLow, 2)
        end
    end

    -- CP3: another low point, different direction
    if #lowPoints > 0 and #checkpoints >= 2 then
        local altLow = pickExtreme(lowPoints, function(a, b)
            return (a - checkpoints[2].position).Magnitude > (b - checkpoints[2].position).Magnitude
        end)
        if altLow and (altLow - checkpoints[2].position).Magnitude > 10 then
            addCp(altLow, 3)
        end
    end

    -- CP4: climb to mid tier (average of farthest mid points from last low)
    if #midPoints > 0 then
        local lastPos = checkpoints[#checkpoints].position
        local midTarget = avgOfFarthest(midPoints, lastPos, 5)
        addCp(midTarget, #checkpoints + 1)
    end

    -- CP5: another mid point
    if #midPoints > 0 then
        local lastPos = checkpoints[#checkpoints].position
        local midTarget = pickExtreme(midPoints, function(a, b)
            return (a - lastPos).Magnitude > (b - lastPos).Magnitude
        end)
        if midTarget and (midTarget - lastPos).Magnitude > 10 then
            addCp(midTarget, #checkpoints + 1)
        end
    end

    -- CP6..N: high tier traversal
    if #highPoints > 0 then
        local lastPos = checkpoints[#checkpoints].position
        local highFar = avgOfFarthest(highPoints, lastPos, 5)
        addCp(highFar, #checkpoints + 1)

        if #highPoints > 0 then
            local highAlt = pickExtreme(highPoints, function(a, b)
                return (a - highFar).Magnitude > (b - highFar).Magnitude
            end)
            if highAlt and (highAlt - highFar).Magnitude > 10 then
                addCp(highAlt, #checkpoints + 1)
            end
        end
    end

    -- Ensure at least 3 checkpoints
    if #checkpoints < 3 then
        -- Fallback: distribute along bounding box diagonal
        local steps = 5
        for i = 2, steps do
            local t = (i - 1) / steps
            local pos = minB:Lerp(maxB, t)
            pos = Vector3.new(pos.X, math.clamp(pos.Y, minB.Y + 2, maxB.Y), pos.Z)
            table.insert(checkpoints, {position = pos, order = i})
        end
    end

    -- Finish line: farthest point from spawn among all parts
    local finishPos = spawnPos
    if #parts > 0 then
        local far = pickExtreme(parts, function(a, b)
            return (a.Position - spawnPos).Magnitude > (b.Position - spawnPos).Magnitude
        end)
        if far then finishPos = far.Position end
    end

    -- Coins: interpolate between checkpoints
    local coins = {}
    for i = 1, #checkpoints - 1 do
        local a = checkpoints[i].position
        local b = checkpoints[i + 1].position
        local steps = math.max(1, math.floor((b - a).Magnitude / 25))
        for s = 1, steps do
            local t = s / (steps + 1)
            local pos = a:Lerp(b, t)
            -- Snap coin Y slightly above ground
            pos = Vector3.new(pos.X, math.max(pos.Y + 2, minB.Y + 2), pos.Z)
            table.insert(coins, pos)
        end
    end
    -- Add a few bonus coins near high points
    if #highPoints > 0 then
        for i = 1, math.min(3, #highPoints) do
            table.insert(coins, highPoints[i] + Vector3.new(0, 3, 0))
        end
    end

    return checkpoints, coins, finishPos, spawnPos
end

----------------------------------------------------------------
-- Source code emitter
----------------------------------------------------------------

local function emitLevelDataSource(checkpoints, coins, finishPos, spawnPos, sourceNote: string): string
    local lines = {}
    table.insert(lines, "local LevelData = {}")
    table.insert(lines, "")
    table.insert(lines, "-- " .. sourceNote)
    table.insert(lines, "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "")
    table.insert(lines, "LevelData.USE_FALLBACK = true")
    table.insert(lines, "")

    table.insert(lines, "LevelData.CHECKPOINTS = {")
    for _, cp in ipairs(checkpoints) do
        table.insert(lines, string.format("    { position = %s, order = %d },", fmtVec3(cp.position), cp.order))
    end
    table.insert(lines, "}")
    table.insert(lines, "")

    table.insert(lines, "LevelData.COINS = {")
    for _, c in ipairs(coins) do
        table.insert(lines, "    " .. fmtVec3(c) .. ",")
    end
    table.insert(lines, "}")
    table.insert(lines, "")

    table.insert(lines, "LevelData.FINISH_LINE = " .. (finishPos and fmtVec3(finishPos) or "nil"))
    table.insert(lines, "")

    table.insert(lines, "LevelData.SPAWN_POSITION = " .. (spawnPos and fmtVec3(spawnPos) or "nil"))
    table.insert(lines, "")

    table.insert(lines, "return LevelData")

    return table.concat(lines, "\n")
end

----------------------------------------------------------------
-- Diff printer (optional diagnostics)
----------------------------------------------------------------

local function printDiff(existing: ModuleScript?, newCheckpoints, newCoins, newFinish, newSpawn)
    print("[GenerateLevelData] --- Diff vs existing LevelData ---")
    if not existing then
        print("  No existing LevelData found.")
        return
    end
    local ok, existingModule = pcall(require, existing)
    if not ok or type(existingModule) ~= "table" then
        print("  Could not parse existing LevelData.")
        return
    end

    local oldCp = existingModule.CHECKPOINTS or {}
    local oldCoins = existingModule.COINS or {}
    print(string.format("  Checkpoints:  existing=%d  new=%d", #oldCp, #newCheckpoints))
    print(string.format("  Coins:        existing=%d  new=%d", #oldCoins, #newCoins))
    if existingModule.FINISH_LINE and newFinish then
        local moved = (existingModule.FINISH_LINE - newFinish).Magnitude
        print(string.format("  Finish moved: %.1f studs", moved))
    end
    if existingModule.SPAWN_POSITION and newSpawn then
        local moved = (existingModule.SPAWN_POSITION - newSpawn).Magnitude
        print(string.format("  Spawn moved:  %.1f studs", moved))
    end
    print("[GenerateLevelData] --- End diff ---")
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function GenerateLevelData.generate()
    local taggedCp, taggedCoins, taggedFinish, taggedSpawn = extractTagged()
    local mode: string
    local checkpoints, coins, finishPos, spawnPos

    if #taggedCp > 0 then
        mode = "TAGGED PARTS"
        checkpoints = taggedCp
        coins = taggedCoins
        finishPos = taggedFinish
        spawnPos = taggedSpawn
    else
        mode = "AUTO-SUGGEST (zero tags found)"
        checkpoints, coins, finishPos, spawnPos = autoSuggestCourse()
    end

    if not finishPos and #checkpoints > 0 then
        finishPos = checkpoints[#checkpoints].position
    end
    if not spawnPos and #checkpoints > 0 then
        spawnPos = checkpoints[1].position
    end

    local sourceNote = "LevelData fallback positions | Source: " .. mode
    local source = emitLevelDataSource(checkpoints, coins, finishPos, spawnPos, sourceNote)

    -- Diff against existing
    local existingModule = ReplicatedStorage:FindFirstChild("LevelData")
    if existingModule and existingModule:IsA("ModuleScript") then
        printDiff(existingModule, checkpoints, coins, finishPos, spawnPos)
    end

    print("=" .. string.rep("=", 70))
    print("GENERATED LEVELDATA — " .. mode)
    print("Checkpoints: " .. tostring(#checkpoints) .. " | Coins: " .. tostring(#coins) .. " | Finish: " .. tostring(finishPos ~= nil))
    print("Copy the block below to src/ReplicatedStorage/LevelData.luau")
    print(string.rep("=", 70))
    print(source)
    print(string.rep("=", 70))

    return source
end

function GenerateLevelData.getSuggestedData(): (table, table, Vector3?, Vector3?)
    local taggedCp, taggedCoins, taggedFinish, taggedSpawn = extractTagged()
    if #taggedCp > 0 then
        return taggedCp, taggedCoins, taggedFinish, taggedSpawn
    end
    return autoSuggestCourse()
end

----------------------------------------------------------------
-- Auto-run when executed as a Script in Studio
----------------------------------------------------------------
if script and script:IsA("Script") then
    task.delay(1, GenerateLevelData.generate)
end

return GenerateLevelData
