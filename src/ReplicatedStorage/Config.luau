--[[
    ModuleScript: ReplicatedStorage/Config
    Central game configuration. Balanced for maximum retention + monetization.
    All tunables live here for rapid iteration without touching game logic.
]]

local Config = {}

----------------------------------------------------------------
-- Economy
----------------------------------------------------------------
Config.COIN_VALUE_PER_COIN = 1
Config.BASE_COIN_MULTIPLIER = 1.0
Config.PREMIUM_COIN_BONUS = 0.20 -- +20% for Roblox Premium members

----------------------------------------------------------------
-- Gamepasses (Developer Products handled via MarketplaceService)
----------------------------------------------------------------
-- WARNING: All id=0 values are placeholders. Replace with actual Roblox asset IDs before publishing.
Config.GAMEPASSES = {
    DOUBLE_COINS = {
        id = 0, -- Replace with actual Gamepass ID when published
        name = "2x Coins",
        description = "Double all coin earnings forever",
        multiplier = 2.0,
    },
    VIP = {
        id = 0, -- Replace with actual Gamepass ID when published
        name = "VIP",
        description = "Golden name, rainbow trail, +50% coins",
        coinBonus = 0.50, -- +50% coins
    },
    SKIP_CHECKPOINT = {
        id = 0, -- Replace with actual Gamepass ID when published
        name = "Skip Checkpoint",
        description = "Skip 1 checkpoint per run",
    },
}

----------------------------------------------------------------
-- Developer Products
----------------------------------------------------------------
-- WARNING: All id=0 values are placeholders. Replace with actual Developer Product IDs before publishing.
Config.DEV_PRODUCTS = {
    COINS_SMALL = { id = 0, name = "Coin Pack (100)", amount = 100 },
    COINS_MEDIUM = { id = 0, name = "Coin Pack (500)", amount = 500 },
    COINS_LARGE = { id = 0, name = "Coin Pack (2,000)", amount = 2000 },
    INSTANT_RESPAWN = { id = 0, name = "Instant Respawn", amount = 0 },
}

----------------------------------------------------------------
-- Daily Rewards
----------------------------------------------------------------
Config.DAILY_REWARD_BASE = 50
Config.DAILY_REWARD_STREAK_MULTIPLIER = 10 -- +10 coins per streak day
Config.DAILY_REWARD_MAX_STREAK = 7
Config.DAILY_REWARD_PREMIUM_BONUS = 50 -- Extra for Premium

----------------------------------------------------------------
-- Combo System
----------------------------------------------------------------
Config.COMBO_WINDOW_SECONDS = 8.0 -- Time between checkpoints to maintain combo
Config.COMBO_TIERS = {
    { threshold = 3, multiplier = 1.5, label = "ON FIRE!" },
    { threshold = 5, multiplier = 2.0, label = "UNSTOPPABLE!" },
    { threshold = 8, multiplier = 3.0, label = "GODLIKE!" },
}

----------------------------------------------------------------
-- Speed Anti-Cheat
----------------------------------------------------------------
Config.MAX_SPEED_STUDS_PER_SEC = 150
Config.COIN_COLLECT_RADIUS = 8  -- Must match GameServer.server.luau COIN_COLLECT_RADIUS constant
Config.FINISH_SPEED_CHECK = true

----------------------------------------------------------------
-- Leaderboards
----------------------------------------------------------------
-- NOTE: LEADERBOARD_SIZE and LEADERBOARD_REFRESH_INTERVAL are reserved for
-- future leaderboard query/display logic (e.g., in-game leaderboard GUI).
Config.LEADERBOARD_SIZE = 50
Config.LEADERBOARD_REFRESH_INTERVAL = 60 -- seconds

----------------------------------------------------------------
-- UI / UX
----------------------------------------------------------------
-- NOTE: HUD_ANIMATION_SPEED, NOTIFICATION_DURATION, and COMBO_DISPLAY_DURATION
-- are reserved for future settings-menu integration. Currently hardcoded in ObbyHUD.client.luau.
Config.HUD_ANIMATION_SPEED = 0.3
Config.NOTIFICATION_DURATION = 2.5
Config.COMBO_DISPLAY_DURATION = 1.5
Config.PROGRESS_BAR_ANIMATION = 0.4 -- Used in ObbyHUD.client.luau progress bar tween

----------------------------------------------------------------
-- Audio
----------------------------------------------------------------
-- NOTE: SFX_VOLUME and MUSIC_VOLUME are reserved for future volume-control UI.
Config.SFX_VOLUME = 0.5
Config.MUSIC_VOLUME = 0.3
Config.COMBO_PITCH_INCREMENT = 0.1 -- Each combo tier raises pitch (used in ObbyClient.client.luau)

----------------------------------------------------------------
-- Cosmetics (Coin Cost)
----------------------------------------------------------------
Config.COSMETICS = {
    TRAILS = {
        { id = "rainbow", name = "Rainbow", cost = 500, color = nil }, -- nil = animated
        { id = "fire", name = "Fire", cost = 1000, color = Color3.fromRGB(255, 100, 0) },
        { id = "ice", name = "Ice", cost = 1000, color = Color3.fromRGB(0, 200, 255) },
        { id = "neon", name = "Neon", cost = 2000, color = Color3.fromRGB(50, 255, 100) },
        { id = "gold", name = "Gold", cost = 5000, color = Color3.fromRGB(255, 215, 0) },
    },
    AURAS = {
        { id = "glow", name = "Glow", cost = 300 },
        { id = "pulse", name = "Pulse", cost = 800 },
        { id = "sparkle", name = "Sparkle", cost = 1500 },
    },
}

return Config
