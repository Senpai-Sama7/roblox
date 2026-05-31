--[[
    LocalScript: StarterPlayerScripts/ObbyEffects
    Screen effects, character trails, post-processing, and environmental VFX.
    The visual layer that makes the game feel S-tier.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- Post-Processing Stack
----------------------------------------------------------------
local function setupPostProcessing()
    -- Bloom for glow effects
    local bloom = Lighting:FindFirstChild("ObbyBloom")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "ObbyBloom"
        bloom.Intensity = 0.4
        bloom.Size = 24
        bloom.Threshold = 0.8
        bloom.Parent = Lighting
    end
    
    -- Color correction for dynamic mood
    local colorCorrection = Lighting:FindFirstChild("ObbyColorCorrection")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Name = "ObbyColorCorrection"
        colorCorrection.Brightness = 0.05
        colorCorrection.Contrast = 0.1
        colorCorrection.Saturation = 0.15
        colorCorrection.TintColor = Color3.fromRGB(255, 248, 240)
        colorCorrection.Parent = Lighting
    end
    
    -- Vignette (darken edges for focus)
    local vignette = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("VignetteOverlay")
    if not vignette then
        local gui = Instance.new("ScreenGui")
        gui.Name = "VignetteOverlay"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = 1000
        
        local frame = Instance.new("Frame")
        frame.Name = "Vignette"
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 0
        frame.Parent = gui
        
        local radial = Instance.new("UIGradient")
        radial.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0, 0, 0)),
            ColorSequenceKeypoint.new(0.7, Color3.new(0, 0, 0)),
            ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
        })
        radial.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.85),
            NumberSequenceKeypoint.new(0.7, 0.6),
            NumberSequenceKeypoint.new(1, 0.3),
        })
        radial.Rotation = 0
        radial.Parent = frame
        
        gui.Parent = player:WaitForChild("PlayerGui")
    end
end

setupPostProcessing()

----------------------------------------------------------------
-- Screen Flash Effect
----------------------------------------------------------------
local flashGui = Instance.new("ScreenGui")
flashGui.Name = "ScreenFlash"
flashGui.ResetOnSpawn = false
flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
flashGui.DisplayOrder = 999

local flashFrame = Instance.new("Frame")
flashFrame.Name = "Flash"
flashFrame.Size = UDim2.new(1, 0, 1, 0)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.Parent = flashGui

flashGui.Parent = player:WaitForChild("PlayerGui")

local function screenFlash(color: Color3?, duration: number?)
    local c = color or Color3.new(1, 1, 1)
    local dur = duration or 0.3
    if activeFlashTween then
        activeFlashTween:Cancel()
    end
    flashFrame.BackgroundColor3 = c
    flashFrame.BackgroundTransparency = 0
    
    activeFlashTween = TweenService:Create(flashFrame, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    })
    activeFlashTween:Play()
end

----------------------------------------------------------------
-- Character Trail System
----------------------------------------------------------------
local currentTrail: Trail? = nil
local trailAttachment0: Attachment? = nil
local trailAttachment1: Attachment? = nil

local function clearTrail()
    if currentTrail then
        currentTrail:Destroy()
        currentTrail = nil
    end
    if trailAttachment0 then
        trailAttachment0:Destroy()
        trailAttachment0 = nil
    end
    if trailAttachment1 then
        trailAttachment1:Destroy()
        trailAttachment1 = nil
    end
end

local function createTrail(color: Color3?, isRainbow: boolean?)
    clearTrail()
    
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return end
    
    trailAttachment0 = Instance.new("Attachment")
    trailAttachment0.Position = Vector3.new(0, -1, 0.5)
    trailAttachment0.Parent = hrp
    
    trailAttachment1 = Instance.new("Attachment")
    trailAttachment1.Position = Vector3.new(0, -1, -0.5)
    trailAttachment1.Parent = hrp
    
    currentTrail = Instance.new("Trail")
    currentTrail.Attachment0 = trailAttachment0
    currentTrail.Attachment1 = trailAttachment1
    currentTrail.Lifetime = 0.5
    currentTrail.MinLength = 0.1
    currentTrail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    
    if isRainbow then
        -- Animated rainbow via gradient
        currentTrail.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        })
    elseif color then
        currentTrail.Color = ColorSequence.new(color)
    else
        currentTrail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    end
    
    currentTrail.Parent = hrp
end

----------------------------------------------------------------
-- Speed-Based Chromatic Aberration
----------------------------------------------------------------
local chromaticGui = Instance.new("ScreenGui")
chromaticGui.Name = "ChromaticAberration"
chromaticGui.ResetOnSpawn = false
chromaticGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
chromaticGui.DisplayOrder = 500

local chromaticFrame = Instance.new("Frame")
chromaticFrame.Name = "Chromatic"
chromaticFrame.Size = UDim2.new(1, 0, 1, 0)
chromaticFrame.BackgroundTransparency = 1
chromaticFrame.Parent = chromaticGui

-- Red channel offset
local redOffset = Instance.new("Frame")
redOffset.Size = UDim2.new(1, 0, 1, 0)
redOffset.BackgroundTransparency = 1
redOffset.Parent = chromaticFrame

-- Blue channel offset
local blueOffset = Instance.new("Frame")
blueOffset.Size = UDim2.new(1, 0, 1, 0)
blueOffset.BackgroundTransparency = 1
blueOffset.Parent = chromaticFrame

chromaticGui.Parent = player:WaitForChild("PlayerGui")

-- Speed-based chromatic aberration (subtle, based on velocity)
local chromaticConnection = RunService.RenderStepped:Connect(function(dt: number)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local vel = hrp.AssemblyLinearVelocity
    local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    local intensity = math.clamp((speed - 30) / 70, 0, 0.008)
    
    redOffset.Position = UDim2.new(-intensity, 0, 0, 0)
    blueOffset.Position = UDim2.new(intensity, 0, 0, 0)
end)

----------------------------------------------------------------
-- Event Listeners
----------------------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local uiUpdate = remotes:WaitForChild("UIUpdate")

local uiUpdateConn: RBXScriptConnection? = nil
local activeFlashTween: Tween? = nil
local activeBloomTween: Tween? = nil

uiUpdateConn = uiUpdate.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local t = payload.type
    local d: any = payload.data or {}
    
    if t == "RunStarted" then
        -- Setup trail based on equipped
        local settings = d.settings
        if settings and settings.trailEnabled then
            if settings.equippedTrail then
                -- Look up trail color from config
                local Config = require(ReplicatedStorage:WaitForChild("Config"))
                for _, trail in ipairs(Config.COSMETICS.TRAILS) do
                    if trail.id == settings.equippedTrail then
                        createTrail(trail.color, trail.id == "rainbow")
                        break
                    end
                end
            end
        end
        
    elseif t == "CheckpointHit" then
        -- Combo flash
        if d.comboCount and d.comboCount >= 3 then
            local comboColor = Color3.fromRGB(255, 200, 50)
            if d.comboCount >= 5 then comboColor = Color3.fromRGB(255, 100, 50) end
            if d.comboCount >= 8 then comboColor = Color3.fromRGB(255, 50, 100) end
            screenFlash(comboColor, 0.1)
        end
        
    elseif t == "RunFinished" then
        if d.isNewBest then
            screenFlash(Color3.fromRGB(255, 215, 0), 0.5)
            -- Dramatic bloom spike
            local bloom = Lighting:FindFirstChild("ObbyBloom")
            if bloom then
                if activeBloomTween then
                    activeBloomTween:Cancel()
                end
                bloom.Intensity = 2.0
                activeBloomTween = TweenService:Create(bloom, TweenInfo.new(2.0), {
                    Intensity = 0.4,
                })
                activeBloomTween:Play()
            end
        else
            screenFlash(Color3.fromRGB(50, 255, 150), 0.2)
        end
        clearTrail()
    end
end)

----------------------------------------------------------------
-- Character respawn handler (re-attach trail)
----------------------------------------------------------------
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    -- Trail will be re-created on next RunStarted event
end)

----------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------
script.Destroying:Connect(function()
    clearTrail()
    if chromaticConnection then
        chromaticConnection:Disconnect()
        chromaticConnection = nil
    end
    if uiUpdateConn then
        uiUpdateConn:Disconnect()
        uiUpdateConn = nil
    end
    if activeFlashTween then
        activeFlashTween:Cancel()
        activeFlashTween = nil
    end
    if activeBloomTween then
        activeBloomTween:Cancel()
        activeBloomTween = nil
    end
end)

print("[ObbyEffects] S-tier visual effects initialized")
