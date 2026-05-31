local LevelData = {}

--[[
    LevelData: Fallback positions for game-interactive elements.
    
    When a Roblox place lacks CollectionService tags on parts
    (e.g., when the level is loaded from a glTF geometry export),
    the GameServer spawns invisible detection parts at the positions
    defined below.
    
    TO SETUP IN STUDIO:
    1. Place Checkpoint parts (BasePart) anywhere in Workspace with:
       - CollectionService tag: "Checkpoint"
       - Attribute: Order = integer (1, 2, 3...)
    2. Place Coin parts with CollectionService tag: "Coin"
    3. Place a FinishLine part with CollectionService tag: "FinishLine"
    4. The game will auto-detect and use those instead of this fallback.
    
    OR run the helper script: ServerScriptService/GenerateLevelData
    to auto-generate this module from a properly-tagged Studio place.
]]

LevelData.CHECKPOINTS = {
    --[[
    { position = Vector3.new(-304.979, 9.192, 57.847), order = 1 },
    { position = Vector3.new(-363.451, 10.968, 73.157), order = 2 },
    { position = Vector3.new(-338.753, 26.980, 142.131), order = 3 },
    ]]
}

LevelData.COINS = {}

LevelData.FINISH_LINE = nil

LevelData.SPAWN_POSITION = nil

LevelData.USE_FALLBACK = false

return LevelData
