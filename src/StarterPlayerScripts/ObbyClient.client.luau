--[[
    LocalScript: StarterPlayerScripts/ObbyClient
    S-TIER VFX and SFX feedback for game events.
    Layered audio, combo pitch shifts, dramatic particles, screen effects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local uiUpdate = remotes:WaitForChild("UIUpdate")

local baseFov = 70

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local Config = require(ReplicatedStorage:WaitForChild("Config"))

----------------------------------------------------------------
-- VFX: Dynamic Speed FOV
-- NOTE: Always read workspace.CurrentCamera live; the reference can go stale.
----------------------------------------------------------------
local fovConnection: RBXScriptConnection? = nil

fovConnection = RunService.RenderStepped:Connect(function(dt: number)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local vel = hrp.AssemblyLinearVelocity
            local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
            local targetFov = baseFov + math.clamp((speed / 50) * 12, 0, 12)
            cam.FieldOfView = cam.FieldOfView + (targetFov - cam.FieldOfView) * (dt * 6)
        end
    end
end)

----------------------------------------------------------------
-- VFX: Camera Shake (Improved)
----------------------------------------------------------------
local activeShakeConn: RBXScriptConnection? = nil
local shakeOffset = CFrame.new()

local function restoreShake()
    local cam = workspace.CurrentCamera
    if not cam then return end
    if shakeOffset ~= CFrame.new() then
        cam.CFrame = cam.CFrame * shakeOffset:Inverse()
        shakeOffset = CFrame.new()
    end
end

local function shakeCamera(intensity: number, duration: number)
    if activeShakeConn then
        activeShakeConn:Disconnect()
        restoreShake()
    end
    local shakeStart = os.clock()
    activeShakeConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local elapsed = os.clock() - shakeStart
        if elapsed > duration then
            restoreShake()
            if activeShakeConn then
                activeShakeConn:Disconnect()
                activeShakeConn = nil
            end
            return
        end
        cam.CFrame = cam.CFrame * shakeOffset:Inverse()
        local fade = 1 - (elapsed / duration)
        local dx = (math.random() - 0.5) * intensity * fade
        local dy = (math.random() - 0.5) * intensity * fade
        shakeOffset = CFrame.Angles(math.rad(dx), math.rad(dy), 0)
        cam.CFrame = cam.CFrame * shakeOffset
    end)
end

----------------------------------------------------------------
-- VFX: Dramatic Particle Burst
----------------------------------------------------------------
local function spawnBurst(position: Vector3, color: Color3, count: number?, lifetime: number?, size: number?)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size or 1.2),
        NumberSequenceKeypoint.new(0.5, (size or 1.2) * 0.6),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Lifetime = NumberRange.new(lifetime or 0.6)
    emitter.Speed = NumberRange.new(6, 18)
    emitter.SpreadAngle = Vector2.new(360, 360)
    emitter.Rate = 0
    emitter.LightEmission = 1
    emitter.LightInfluence = 0
    emitter.Parent = part

    emitter:Emit(count or 20)

    task.delay(2, function()
        if part.Parent then
            part:Destroy()
        end
    end)
end

----------------------------------------------------------------
-- VFX: Ring Explosion (for checkpoints)
----------------------------------------------------------------
local function spawnRing(position: Vector3, color: Color3, radius: number?)
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Parent = workspace

    local targetSize = radius or 8
    TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(targetSize, targetSize, targetSize),
        Transparency = 1,
    }):Play()

    task.delay(0.5, function()
        if part.Parent then part:Destroy() end
    end)
end

----------------------------------------------------------------
-- SFX: Dynamic Audio System
----------------------------------------------------------------
local function playTone(pitch: number?, volume: number?, soundId: string?)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId or "rbxasset://sounds/impact_water.mp3"
    sound.Volume = volume or 0.5
    sound.PlaybackSpeed = pitch or 1.2
    sound.Parent = workspace
    local destroyed = false
    local function cleanup()
        if destroyed then return end
        destroyed = true
        if sound.Parent then
            sound:Destroy()
        end
    end
    sound.Ended:Once(cleanup)
    task.delay(3, cleanup)
    sound:Play()
end

local function playComboTone(comboCount: number)
    local basePitch = 1.0
    local pitchShift = math.min(comboCount * Config.COMBO_PITCH_INCREMENT, 2.0)
    playTone(basePitch + pitchShift, 0.4)
end

local function playSuccessTone(isNewBest: boolean)
    if isNewBest then
        playTone(1.5, 0.7, "rbxasset://sounds/victory.mp3")
    else
        playTone(1.0, 0.5)
    end
end

----------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------
type UIPayload = { type: string, data: { [string]: any } }

local uiUpdateConn: RBXScriptConnection? = nil

uiUpdateConn = uiUpdate.OnClientEvent:Connect(function(payload: UIPayload)
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local t = payload.type
    local d: any = payload.data or {}

    if t == "CheckpointHit" then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                spawnBurst(hrp.Position, Color3.fromRGB(0, 195, 255), 25, 0.7, 1.5)
                spawnRing(hrp.Position, Color3.fromRGB(0, 195, 255), 6)
            end
        end
        
        -- Combo audio
        local comboCount = d.comboCount or 0
        if comboCount >= 2 then
            playComboTone(comboCount)
        else
            playTone(1.3, 0.4)
        end

    elseif t == "CoinCollected" then
        if typeof(d.position) == "Vector3" then
            spawnBurst(d.position, Color3.fromRGB(255, 200, 50), 18, 0.5, 1.0)
            spawnRing(d.position, Color3.fromRGB(255, 200, 50), 4)
        end
        local mult = d.comboMultiplier or 1.0
        if mult > 1.5 then
            playTone(1.8, 0.3)
        else
            playTone(1.6, 0.3)
        end

    elseif t == "RunFinished" then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local isNewBest = d.isNewBest
                local c = if isNewBest then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(50, 255, 150)
                spawnBurst(hrp.Position, c, 60, 1.2, 2.0)
                spawnRing(hrp.Position, c, 12)
                shakeCamera(2, 0.4)
            end
        end
        playSuccessTone(d.isNewBest or false)

    elseif t == "RunStarted" then
        playTone(0.9, 0.3)
    end
end)

print("[ObbyClient] S-tier VFX/SFX handler initialized")

----------------------------------------------------------------
-- Cleanup on script destroy
----------------------------------------------------------------
script.Destroying:Connect(function()
    if fovConnection then
        fovConnection:Disconnect()
        fovConnection = nil
    end
    if activeShakeConn then
        activeShakeConn:Disconnect()
        activeShakeConn = nil
    end
    if uiUpdateConn then
        uiUpdateConn:Disconnect()
        uiUpdateConn = nil
    end
    restoreShake()
end)
