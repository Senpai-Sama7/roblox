--[[
    LocalScript: StarterPlayerScripts/ObbyClient
    Client-side. VFX and SFX feedback for game events.
    Listens to UIUpdate for checkpoint, coin, and finish events.
    Includes dynamic FOV scaling for speed immersion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local uiUpdate = remotes:WaitForChild("UIUpdate")

local camera = workspace.CurrentCamera
local baseFov = 70

----------------------------------------------------------------
-- VFX: Dynamic Speed FOV
----------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local speed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
            -- Expand FOV slightly based on speed to give a sense of momentum
            local targetFov = baseFov + math.clamp((speed / 50) * 12, 0, 12)
            camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * (dt * 6)
        end
    end
end)

----------------------------------------------------------------
-- VFX: Camera Shake
----------------------------------------------------------------
local function shakeCamera(intensity, duration)
    local shakeStart = os.clock()
    local conn; conn = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - shakeStart
        if elapsed > duration then
            conn:Disconnect()
            return
        end
        local fade = 1 - (elapsed / duration)
        local dx = (math.random() - 0.5) * intensity * fade
        local dy = (math.random() - 0.5) * intensity * fade
        camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(dx), math.rad(dy), 0)
    end)
end

----------------------------------------------------------------
-- VFX: short particle burst at a world position
----------------------------------------------------------------
local function spawnBurst(position: Vector3, color: Color3, count: number?, lifetime: number?)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
    emitter.Lifetime = NumberRange.new(lifetime or 0.6)
    emitter.Speed = NumberRange.new(8, 16)
    emitter.SpreadAngle = Vector2.new(360, 360)
    emitter.Rate = 0
    emitter.LightEmission = 1
    emitter.Parent = part

    emitter:Emit(count or 20)

    task.delay(2, function()
        part:Destroy()
    end)
end

----------------------------------------------------------------
-- SFX: short beep / ding using a generated tone
----------------------------------------------------------------
local function playTone(pitch: number?, volume: number?)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/impact_water.mp3"
    sound.Volume = volume or 0.5
    sound.PlaybackSpeed = pitch or 1.2
    sound.Parent = workspace
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    task.delay(3, function()
        if sound and sound.Parent then
            sound:Destroy()
        end
    end)
end

----------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------
type UIPayload = { type: string, data: { [string]: any } }

uiUpdate.OnClientEvent:Connect(function(payload: UIPayload)
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local t = payload.type
    local d = payload.data or {}

    if t == "CheckpointHit" then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                spawnBurst(hrp.Position, Color3.fromRGB(0, 195, 255), 25, 0.7)
            end
        end
        playTone(1.3, 0.4)

    elseif t == "CoinCollected" then
        if typeof(d.position) == "Vector3" then
            spawnBurst(d.position, Color3.fromRGB(255, 200, 50), 15, 0.5)
        end
        playTone(1.6, 0.3)

    elseif t == "RunFinished" then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local c = if d.isNewBest then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(50, 255, 150)
                spawnBurst(hrp.Position, c, 50, 1.0)
                shakeCamera(2, 0.4)
            end
        end
        playTone(1.0, 0.6)

    elseif t == "RunStarted" then
        playTone(0.9, 0.3)
    end
end)

print("[ObbyClient] VFX/SFX handler initialized")
