--[[
    LocalScript: StarterGui/ObbyHUD
    Client-side. Builds the HUD programmatically and listens to UIUpdate.
    Maximizes UI/UX with premium animations and glassmorphic designs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local uiUpdate = remotes:WaitForChild("UIUpdate")
local playerAction = remotes:WaitForChild("PlayerAction")

----------------------------------------------------------------
-- Premium Color Palette
----------------------------------------------------------------
local C = {
    bg       = Color3.fromRGB(15, 16, 22),
    accent   = Color3.fromRGB(0, 195, 255),
    gold     = Color3.fromRGB(255, 200, 50),
    green    = Color3.fromRGB(50, 255, 150),
    red      = Color3.fromRGB(255, 65, 85),
    white    = Color3.fromRGB(250, 250, 255),
    dimWhite = Color3.fromRGB(160, 165, 180),
}

----------------------------------------------------------------
-- Build ScreenGui
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Top Container (Glassmorphism effect)
local panel = Instance.new("Frame")
panel.Name = "TopPanel"
panel.Size = UDim2.new(0, 320, 0, 160)
panel.Position = UDim2.new(0.5, -160, 0, -200) -- Start offscreen for entrance animation
panel.BackgroundColor3 = C.bg
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel = 0
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local panelGradient = Instance.new("UIGradient", panel)
panelGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.8, 0.8))
})
panelGradient.Rotation = 45

local stroke = Instance.new("UIStroke", panel)
stroke.Color = C.white
stroke.Thickness = 1.5
stroke.Transparency = 0.8

-- Title / Header
local headerLabel = Instance.new("TextLabel")
headerLabel.Name = "Header"
headerLabel.Size = UDim2.new(1, 0, 0, 20)
headerLabel.Position = UDim2.new(0, 0, 0, 8)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "SPEEDRUN"
headerLabel.TextColor3 = C.dimWhite
headerLabel.TextSize = 12
headerLabel.Font = Enum.Font.GothamBlack
headerLabel.Parent = panel

-- Timer
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, 0, 0, 50)
timerLabel.Position = UDim2.new(0, 0, 0, 24)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "0:00.00"
timerLabel.TextColor3 = C.white
timerLabel.TextSize = 46
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.Parent = panel

-- Inner Container for Stats
local statsFrame = Instance.new("Frame")
statsFrame.Name = "Stats"
statsFrame.Size = UDim2.new(1, -24, 0, 36)
statsFrame.Position = UDim2.new(0, 12, 0, 78)
statsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
statsFrame.BackgroundTransparency = 0.6
statsFrame.Parent = panel
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 8)

-- Best time
local bestLabel = Instance.new("TextLabel")
bestLabel.Name = "BestTime"
bestLabel.Size = UDim2.new(0.5, -10, 1, 0)
bestLabel.Position = UDim2.new(0, 10, 0, 0)
bestLabel.BackgroundTransparency = 1
bestLabel.Text = "Best: --:--"
bestLabel.TextColor3 = C.gold
bestLabel.TextSize = 14
bestLabel.Font = Enum.Font.GothamBold
bestLabel.TextXAlignment = Enum.TextXAlignment.Left
bestLabel.Parent = statsFrame

-- Coins
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "Coins"
coinsLabel.Size = UDim2.new(0.5, -10, 1, 0)
coinsLabel.Position = UDim2.new(0.5, 0, 0, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "💎 0"
coinsLabel.TextColor3 = C.accent
coinsLabel.TextSize = 15
coinsLabel.Font = Enum.Font.GothamBlack
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
coinsLabel.Parent = statsFrame

-- Checkpoint progress
local cpLabel = Instance.new("TextLabel")
cpLabel.Name = "Checkpoints"
cpLabel.Size = UDim2.new(1, -24, 0, 20)
cpLabel.Position = UDim2.new(0, 12, 0, 122)
cpLabel.BackgroundTransparency = 1
cpLabel.Text = "Checkpoints: 0 / 0"
cpLabel.TextColor3 = C.white
cpLabel.TextTransparency = 0.2
cpLabel.TextSize = 14
cpLabel.Font = Enum.Font.GothamBold
cpLabel.TextXAlignment = Enum.TextXAlignment.Left
cpLabel.Parent = panel

-- Reset button
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetRun"
resetBtn.Size = UDim2.new(0, 80, 0, 26)
resetBtn.Position = UDim2.new(1, -92, 0, 119)
resetBtn.BackgroundColor3 = C.red
resetBtn.BackgroundTransparency = 0.1
resetBtn.BorderSizePixel = 0
resetBtn.Text = "RESET"
resetBtn.TextColor3 = C.white
resetBtn.TextSize = 12
resetBtn.Font = Enum.Font.GothamBlack
resetBtn.Parent = panel
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

-- Notification (center screen)
local notif = Instance.new("TextLabel")
notif.Name = "Notification"
notif.Size = UDim2.new(0, 500, 0, 70)
notif.Position = UDim2.new(0.5, -250, 0.25, 0)
notif.AnchorPoint = Vector2.new(0, 0)
notif.BackgroundColor3 = C.bg
notif.BackgroundTransparency = 0.15
notif.BorderSizePixel = 0
notif.Text = ""
notif.TextColor3 = C.green
notif.TextSize = 30
notif.Font = Enum.Font.GothamBlack
notif.Visible = false
notif.Parent = gui
Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 16)

local notifStroke = Instance.new("UIStroke", notif)
notifStroke.Color = C.green
notifStroke.Thickness = 3
notifStroke.Transparency = 0.2

----------------------------------------------------------------
-- Micro-Animations
----------------------------------------------------------------
-- Intro animation
TweenService:Create(panel, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -160, 0, 16)
}):Play()

local function popAnimate(guiObj)
    local origSize = guiObj.Size
    local origPos = guiObj.Position
    -- Expand slightly
    guiObj.Size = UDim2.new(origSize.X.Scale, origSize.X.Offset + 10, origSize.Y.Scale, origSize.Y.Offset + 10)
    guiObj.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset - 5, origPos.Y.Scale, origPos.Y.Offset - 5)
    
    TweenService:Create(guiObj, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = origSize,
        Position = origPos
    }):Play()
end

-- Hover effects
resetBtn.MouseEnter:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(255, 90, 110),
        Size = UDim2.new(0, 84, 0, 28),
        Position = UDim2.new(1, -94, 0, 118)
    }):Play()
end)
resetBtn.MouseLeave:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = C.red,
        Size = UDim2.new(0, 80, 0, 26),
        Position = UDim2.new(1, -92, 0, 119)
    }):Play()
end)

----------------------------------------------------------------
-- State & Local Timer
----------------------------------------------------------------
local currentCP = 0
local totalCP = 0
local runCoins = 0

local runStartTime = 0
local isRunningLocally = false
local timerConnection = nil
local notifVersion = 0

local function formatTime(seconds: number): string
    local mins = math.floor(seconds / 60)
    local secs = seconds - (mins * 60)
    return string.format("%d:%05.2f", mins, secs)
end

local function formatBestTime(bestSeconds: number?): string
    if bestSeconds and bestSeconds < 999999 then
        return "Best: " .. formatTime(bestSeconds)
    end
    return "Best: --:--"
end

local function startLocalTimer()
    if timerConnection then timerConnection:Disconnect() end
    runStartTime = os.clock()
    isRunningLocally = true
    timerConnection = RunService.Heartbeat:Connect(function()
        if isRunningLocally then
            timerLabel.Text = formatTime(os.clock() - runStartTime)
        end
    end)
end

local function stopLocalTimer()
    isRunningLocally = false
    if timerConnection then
        timerConnection:Disconnect()
        timerConnection = nil
    end
end

----------------------------------------------------------------
-- Notification helper
----------------------------------------------------------------
local function showNotification(msg: string, color: Color3?, dur: number?)
    local c = color or C.green
    local d = dur or 2.5

    notifVersion += 1
    local thisVersion = notifVersion

    notif.Text = msg
    notif.TextColor3 = c
    notifStroke.Color = c
    notif.Visible = true
    notif.TextTransparency = 0
    notif.BackgroundTransparency = 0.15

    notif.Position = UDim2.new(0.5, -250, 0.25, -20)
    notif.Size = UDim2.new(0, 500, 0, 70)
    TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -250, 0.25, 0)
    }):Play()

    task.delay(d, function()
        if notifVersion ~= thisVersion then return end
        local fade = TweenService:Create(notif, TweenInfo.new(0.3), {
            TextTransparency = 1,
            BackgroundTransparency = 1,
        })
        fade:Play()
        fade.Completed:Wait()
        if notifVersion == thisVersion then
            notif.Visible = false
        end
    end)
end

----------------------------------------------------------------
-- Reset Actions
----------------------------------------------------------------
local isResetting = false
resetBtn.MouseButton1Click:Connect(function()
    if isResetting then return end
    isResetting = true
    stopLocalTimer()
    timerLabel.Text = "0:00.00"
    playerAction:FireServer("RequestReset")
    
    -- Shake animation
    local origPos = panel.Position
    TweenService:Create(panel, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
        Position = UDim2.new(origPos.X.Scale, origPos.X.Offset - 5, origPos.Y.Scale, origPos.Y.Offset)
    }):Play()
    
    task.delay(1.0, function()
        isResetting = false
    end)
end)

----------------------------------------------------------------
-- UIUpdate handler
----------------------------------------------------------------
type UIPayload = { type: string, data: { [string]: any } }

uiUpdate.OnClientEvent:Connect(function(payload: UIPayload)
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local t = payload.type
    local d = payload.data or {}

    if t == "RunStarted" then
        totalCP = d.totalCheckpoints or 0
        currentCP = 0
        runCoins = 0
        timerLabel.Text = "0:00.00"
        cpLabel.Text = string.format("Checkpoints: 0 / %d", totalCP)
        coinsLabel.Text = "💎 0"
        bestLabel.Text = formatBestTime(d.bestTime)
        showNotification("GO!", C.green, 1.5)
        startLocalTimer()

    elseif t == "CheckpointHit" then
        currentCP = d.checkpoint or currentCP
        totalCP = d.total or totalCP
        cpLabel.Text = string.format("Checkpoints: %d / %d", currentCP, totalCP)
        showNotification(string.format("Checkpoint %d / %d", currentCP, totalCP), C.accent, 1.5)
        popAnimate(cpLabel)

    elseif t == "CoinCollected" then
        runCoins = d.coinsThisRun or (runCoins + 1)
        coinsLabel.Text = string.format("💎 %d", runCoins)
        coinsLabel.TextColor3 = C.white
        popAnimate(coinsLabel)
        TweenService:Create(coinsLabel, TweenInfo.new(0.3), {
            TextColor3 = C.accent,
        }):Play()

    elseif t == "RunFinished" then
        stopLocalTimer()
        timerLabel.Text = d.formattedTime or timerLabel.Text
        coinsLabel.Text = string.format("💎 %d", d.totalCoins or 0)
        popAnimate(timerLabel)
        
        if d.isNewBest then
            bestLabel.Text = formatBestTime(d.bestTime)
            showNotification("NEW BEST TIME! " .. (d.formattedTime or ""), C.gold, 3.5)
        else
            bestLabel.Text = formatBestTime(d.bestTime)
            showNotification("Finished: " .. (d.formattedTime or ""), C.green, 3)
        end

    elseif t == "DataLoaded" then
        totalCP = d.totalCheckpoints or 0
        cpLabel.Text = string.format("Checkpoints: 0 / %d", totalCP)
        coinsLabel.Text = string.format("💎 %d", d.totalCoins or 0)
        bestLabel.Text = formatBestTime(d.bestTime)

    elseif t == "Notification" then
        local color = C.green
        if d.color == "red" then color = C.red
        elseif d.color == "gold" then color = C.gold
        elseif d.color == "blue" then color = C.accent end
        showNotification(d.message or "", color)
    end
end)

print("[ObbyHUD] Premium HUD initialized")
