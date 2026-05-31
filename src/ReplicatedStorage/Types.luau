--[[
    ModuleScript: ReplicatedStorage/Types
    Shared type definitions used across server and client.
    Ensures type consistency for data payloads and state management.
]]

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
    lastClaimDate: string, -- YYYY-MM-DD
    streak: number,
}

export type UIPayload = {
    type: string,
    data: { [string]: any },
}

export type LeaderboardEntry = {
    userId: number,
    displayName: string,
    bestTime: number,
    totalCoins: number,
    isPremium: boolean,
}

export type ComboState = {
    count: number,
    multiplier: number,
    lastCheckpointTime: number,
}

export type GamepassInfo = {
    id: number,
    name: string,
    owned: boolean,
}

export type NotificationData = {
    message: string,
    color: string?,
    duration: number?,
    sound: string?,
}

return {}
