local LevelData = {}

--[[
    LevelData: Fallback positions for game-interactive elements.
    
    SOURCES:
    - Primary: Derived from Export.gltf real node coordinates (SpawnLocation,
      OB_BallPlatform_a, Carousel, Ivy_Hanging_a clusters, etc.)
    - Secondary: Interpolated midpoints for playable jump distances and
      logical vertical progression.
    
    When a Roblox place lacks CollectionService tags on parts (e.g., when the
    level is loaded from a glTF geometry export), GameServer spawns invisible
    detection parts at the positions defined below.
    
    STUDIO UPGRADE PATH:
    1. Place Checkpoint parts (BasePart) with CollectionService tag "Checkpoint"
       and Attribute Order = integer (1, 2, 3...)
    2. Place Coin parts with tag "Coin"
    3. Place FinishLine part with tag "FinishLine"
    4. Run ServerScriptService/GenerateLevelData to auto-export positions.
    5. Paste output into this module, or set USE_FALLBACK = false if tags
       are present and authoritative.
    
    COURSE LAYOUT (9 checkpoints, 12 coins, 1 finish line):
    Spawn  ->  Southwest Loop  ->  Carousel Climb  ->  High Ridge Traverse
    (-305,9,58)   (-363,11,73)      (-339,27,142)        (-213,57,153)
]]

----------------------------------------------------------------
-- CHECKPOINTS
-- Order 1..N. Player must hit them sequentially.
----------------------------------------------------------------
LevelData.CHECKPOINTS = {
    -- CP1: Start pad (same as spawn)
    { position = Vector3.new(-304.979, 9.192, 57.847), order = 1 },

    -- CP2: Southwest spotlight platform (glTF OB_Spotlight_a)
    { position = Vector3.new(-343.286, 9.108, 34.672), order = 2 },

    -- CP3: Ball platform area (glTF OB_BallPlatform_a)
    { position = Vector3.new(-363.451, 10.968, 73.157), order = 3 },

    -- CP4: Carousel (glTF Carousel — first major climb)
    { position = Vector3.new(-338.753, 26.980, 142.131), order = 4 },

    -- CP5: Far northeast ivy (glTF Ivy_Hanging_a)
    { position = Vector3.new(-295.698, 18.460, 181.381), order = 5 },

    -- CP6: Mid-loop ivy (glTF Ivy_Hanging_a)
    { position = Vector3.new(-267.865, 17.850, 156.710), order = 6 },

    -- CP7: Interpolated climb midpoint (low -> high ridge transition)
    { position = Vector3.new(-240.000, 35.000, 100.000), order = 7 },

    -- CP8: High ridge west (glTF Ivy_Hanging_a cluster)
    { position = Vector3.new(-220.002, 57.738, 18.271), order = 8 },

    -- CP9: High ridge east (glTF Ivy_Hanging_a cluster)
    { position = Vector3.new(-212.874, 56.718, 151.319), order = 9 },
}

----------------------------------------------------------------
-- COINS
-- Scattered between checkpoints for risk/reward collection.
----------------------------------------------------------------
LevelData.COINS = {
    -- Between CP1 and CP2
    Vector3.new(-320.000, 9.192, 45.000),

    -- Near CP3 (ball platform)
    Vector3.new(-353.000, 11.000, 55.000),

    -- Between CP3 and CP4 (approaching carousel)
    Vector3.new(-350.000, 18.000, 110.000),

    -- Near CP4 (carousel)
    Vector3.new(-315.000, 22.000, 160.000),

    -- Between CP4 and CP5
    Vector3.new(-290.000, 18.500, 170.000),

    -- Near CP5
    Vector3.new(-280.000, 18.500, 168.000),

    -- Between CP5 and CP6
    Vector3.new(-260.000, 18.000, 150.000),

    -- Climb start (CP6 -> CP7)
    Vector3.new(-250.000, 25.000, 120.000),

    -- Mid climb (CP7 -> CP8)
    Vector3.new(-235.000, 42.000, 70.000),

    -- High ridge west (near CP8)
    Vector3.new(-215.000, 57.500, 35.000),

    -- High ridge mid (CP8 -> CP9)
    Vector3.new(-215.000, 57.500, 85.000),

    -- Near finish
    Vector3.new(-213.000, 57.500, 145.000),
}

----------------------------------------------------------------
-- FINISH LINE
-- Must be touched after all checkpoints to complete the run.
----------------------------------------------------------------
LevelData.FINISH_LINE = Vector3.new(-213.397, 57.085, 153.043)

----------------------------------------------------------------
-- SPAWN POSITION
-- Player character spawn / reset location.
----------------------------------------------------------------
LevelData.SPAWN_POSITION = Vector3.new(-304.979, 9.192, 57.847)

----------------------------------------------------------------
-- MASTER SWITCH
-- true  = Use the fallback positions above (safe for glTF-only places).
-- false = Rely exclusively on CollectionService-tagged parts in Workspace.
----------------------------------------------------------------
LevelData.USE_FALLBACK = true

return LevelData
