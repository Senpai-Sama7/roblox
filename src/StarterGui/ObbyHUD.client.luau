--[[
    LocalScript: StarterGui/ObbyHUD
    S-TIER HUD. Glassmorphism, animated progress, combo system, daily rewards.
    Designed for maximum dopamine and retention.
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
local dailyRewardEvent = remotes:WaitForChild("DailyReward")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

----------------------------------------------------------------
-- Premium Color Palette (S-tier edition)
----------------------------------------------------------------
local C = {
    bg       = Color3.fromRGB(12, 13, 20),
    bgLight  = Color3.fromRGB(25, 28, 40),
    accent   = Color3.fromRGB(0, 195, 255),
    gold     = Color3.fromRGB(255, 200, 50),
    green    = Color3.fromRGB(50, 255, 150),
    red      = Color3.fromRGB(255, 65, 85),
    white    = Color3.fromRGB(250, 250, 255),
    dimWhite = Color3.fromRGB(160, 165, 180),
    purple   = Color3.fromRGB(180, 50, 255),
    orange   = Color3.fromRGB(255, 150, 50),
}

----------------------------------------------------------------
-- Helper: Create rounded frame with glassmorphism
----------------------------------------------------------------
local function createGlassFrame(name: string, parent: Instance, size: UDim2, pos: UDim2): Frame
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = size
    frame.Position = pos
    frame.BackgroundColor3 = C.bg
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = C.white
    stroke.Thickness = 1
    stroke.Transparency = 0.85
    
    return frame
end

----------------------------------------------------------------
-- Main GUI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

----------------------------------------------------------------
-- Top Panel (Main HUD)
----------------------------------------------------------------
local panel = createGlassFrame("TopPanel", gui,
    UDim2.new(0, 380, 0, 180),
    UDim2.new(0.5, -190, 0, -200))

-- Animated gradient background
local panelGradient = Instance.new("UIGradient", panel)
panelGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.new(0.9, 0.9, 0.95)),
    ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.8, 0.9)),
})
panelGradient.Rotation = 45

-- Entrance animation
TweenService:Create(panel, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -190, 0, 16)
}):Play()

----------------------------------------------------------------
-- Header Row
----------------------------------------------------------------
local headerLabel = Instance.new("TextLabel")
headerLabel.Name = "Header"
headerLabel.Size = UDim2.new(1, -20, 0, 18)
headerLabel.Position = UDim2.new(0, 10, 0, 8)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "SPEEDRUN"
headerLabel.TextColor3 = C.dimWhite
headerLabel.TextSize = 11
headerLabel.Font = Enum.Font.GothamBlack
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Parent = panel

-- Premium/VIP badges
local badgeContainer = Instance.new("Frame")
badgeContainer.Name = "Badges"
badgeContainer.Size = UDim2.new(0, 0, 0, 16)
badgeContainer.Position = UDim2.new(1, -10, 0, 9)
badgeContainer.BackgroundTransparency = 1
badgeContainer.Parent = panel

local function addBadge(text: string, color: Color3)
    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, text:len() * 7 + 10, 1, 0)
    badge.BackgroundColor3 = color
    badge.BackgroundTransparency = 0.3
    badge.Text = text
    badge.TextColor3 = C.white
    badge.TextSize = 9
    badge.Font = Enum.Font.GothamBold
    badge.Parent = badgeContainer
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)
    
    -- Adjust container width
    local currentWidth = badgeContainer.Size.X.Offset
    badgeContainer.Size = UDim2.new(0, currentWidth + badge.Size.X.Offset + 4, 0, 16)
    badge.Position = UDim2.new(0, currentWidth, 0, 0)
end

----------------------------------------------------------------
-- Timer Display
----------------------------------------------------------------
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, 0, 0, 52)
timerLabel.Position = UDim2.new(0, 0, 0, 24)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "0:00.00"
timerLabel.TextColor3 = C.white
timerLabel.TextSize = 48
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.Parent = panel

-- Timer glow
local timerGlow = Instance.new("UIStroke", timerLabel)
timerGlow.Color = C.accent
timerGlow.Thickness = 0.5
timerGlow.Transparency = 0.9

----------------------------------------------------------------
-- Combo Counter (hidden by default)
----------------------------------------------------------------
local comboLabel = Instance.new("TextLabel")
comboLabel.Name = "Combo"
comboLabel.Size = UDim2.new(1, 0, 0, 20)
comboLabel.Position = UDim2.new(0, 0, 0, 72)
comboLabel.BackgroundTransparency = 1
comboLabel.Text = ""
comboLabel.TextColor3 = C.gold
comboLabel.TextSize = 14
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.Parent = panel
comboLabel.Visible = false

----------------------------------------------------------------
-- Progress Bar
----------------------------------------------------------------
local progressBarContainer = Instance.new("Frame")
progressBarContainer.Name = "ProgressBar"
progressBarContainer.Size = UDim2.new(1, -24, 0, 6)
progressBarContainer.Position = UDim2.new(0, 12, 0, 96)
progressBarContainer.BackgroundColor3 = C.bgLight
progressBarContainer.BackgroundTransparency = 0.5
progressBarContainer.BorderSizePixel = 0
progressBarContainer.Parent = panel
Instance.new("UICorner", progressBarContainer).CornerRadius = UDim.new(0, 3)

local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = C.accent
progressFill.BackgroundTransparency = 0.1
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBarContainer
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 3)

-- Progress glow
local progressGlow = Instance.new("UIGradient", progressFill)
progressGlow.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0.7, 0.9, 1)),
})

----------------------------------------------------------------
-- Stats Row
----------------------------------------------------------------
local statsFrame = createGlassFrame("Stats", panel,
    UDim2.new(1, -24, 0, 34),
    UDim2.new(0, 12, 0, 108))
statsFrame.BackgroundTransparency = 0.5

-- Best time
local bestLabel = Instance.new("TextLabel")
bestLabel.Name = "BestTime"
bestLabel.Size = UDim2.new(0.33, -4, 1, 0)
bestLabel.Position = UDim2.new(0, 6, 0, 0)
bestLabel.BackgroundTransparency = 1
bestLabel.Text = "Best: --:--"
bestLabel.TextColor3 = C.gold
bestLabel.TextSize = 12
bestLabel.Font = Enum.Font.GothamBold
bestLabel.TextXAlignment = Enum.TextXAlignment.Left
bestLabel.Parent = statsFrame

-- Coins
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "Coins"
coinsLabel.Size = UDim2.new(0.33, -4, 1, 0)
coinsLabel.Position = UDim2.new(0.33, 2, 0, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "💎 0"
coinsLabel.TextColor3 = C.accent
coinsLabel.TextSize = 13
coinsLabel.Font = Enum.Font.GothamBlack
coinsLabel.TextXAlignment = Enum.TextXAlignment.Center
coinsLabel.Parent = statsFrame

-- Runs
local runsLabel = Instance.new("TextLabel")
runsLabel.Name = "Runs"
runsLabel.Size = UDim2.new(0.33, -4, 1, 0)
runsLabel.Position = UDim2.new(0.66, 2, 0, 0)
runsLabel.BackgroundTransparency = 1
runsLabel.Text = "Runs: 0"
runsLabel.TextColor3 = C.dimWhite
runsLabel.TextSize = 12
runsLabel.Font = Enum.Font.GothamBold
runsLabel.TextXAlignment = Enum.TextXAlignment.Right
runsLabel.Parent = statsFrame

----------------------------------------------------------------
-- Checkpoint Text
----------------------------------------------------------------
local cpLabel = Instance.new("TextLabel")
cpLabel.Name = "Checkpoints"
cpLabel.Size = UDim2.new(1, -24, 0, 18)
cpLabel.Position = UDim2.new(0, 12, 0, 146)
cpLabel.BackgroundTransparency = 1
cpLabel.Text = "Checkpoints: 0 / 0"
cpLabel.TextColor3 = C.white
cpLabel.TextTransparency = 0.2
cpLabel.TextSize = 13
cpLabel.Font = Enum.Font.GothamBold
cpLabel.TextXAlignment = Enum.TextXAlignment.Left
cpLabel.Parent = panel

----------------------------------------------------------------
-- Reset Button
----------------------------------------------------------------
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetRun"
resetBtn.Size = UDim2.new(0, 90, 0, 28)
resetBtn.Position = UDim2.new(1, -102, 0, 144)
resetBtn.BackgroundColor3 = C.red
resetBtn.BackgroundTransparency = 0.1
resetBtn.BorderSizePixel = 0
resetBtn.Text = "RESET"
resetBtn.TextColor3 = C.white
resetBtn.TextSize = 12
resetBtn.Font = Enum.Font.GothamBlack
resetBtn.Parent = panel
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

local resetStroke = Instance.new("UIStroke", resetBtn)
resetStroke.Color = C.white
resetStroke.Thickness = 1
resetStroke.Transparency = 0.6

-- Hover effects
resetBtn.MouseEnter:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(255, 90, 110),
        Size = UDim2.new(0, 94, 0, 30),
        Position = UDim2.new(1, -104, 0, 143),
    }):Play()
end)
resetBtn.MouseLeave:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = C.red,
        Size = UDim2.new(0, 90, 0, 28),
        Position = UDim2.new(1, -102, 0, 144),
    }):Play()
end)

----------------------------------------------------------------
-- Notification System (Queue-based)
----------------------------------------------------------------
local notifQueue: { { msg: string, color: Color3, dur: number } } = {}
local isNotifActive = false

local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.Size = UDim2.new(0, 400, 0, 300)
notifContainer.Position = UDim2.new(0.5, -200, 0.5, -50)
notifContainer.BackgroundTransparency = 1
notifContainer.ZIndex = 10
notifContainer.Parent = gui

local function showNotificationInternal(msg: string, color: Color3, dur: number)
    isNotifActive = true
    
    local notif = Instance.new("TextLabel")
    notif.Size = UDim2.new(0, 400, 0, 50)
    notif.BackgroundColor3 = C.bg
    notif.BackgroundTransparency = 0.1
    notif.BorderSizePixel = 0
    notif.Text = msg
    notif.TextColor3 = color
    notif.TextSize = 22
    notif.Font = Enum.Font.GothamBlack
    notif.Parent = notifContainer
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    
    -- Entrance
    notif.Position = UDim2.new(0, 0, 0, -60)
    TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()
    
    task.delay(dur, function()
        -- Exit
        local fade = TweenService:Create(notif, TweenInfo.new(0.3), {
            Position = UDim2.new(0, 0, 0, -60),
            TextTransparency = 1,
            BackgroundTransparency = 1,
        })
        local strokeFade = TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 })
        fade:Play()
        strokeFade:Play()
        -- SAFETY: use a timeout so a stuck tween can't block the queue forever
        local completed = false
        fade.Completed:Once(function()
            completed = true
        end)
        local start = os.clock()
        while not completed and (os.clock() - start) < 1.0 do
            task.wait(0.05)
        end
        if notif and notif.Parent then
            notif:Destroy()
        end
        
        -- Process queue
        if #notifQueue > 0 then
            local nextNotif = table.remove(notifQueue, 1)
            showNotificationInternal(nextNotif.msg, nextNotif.color, nextNotif.dur)
        else
            isNotifActive = false
        end
    end)
end

local function showNotification(msg: string, color: Color3?, dur: number?)
    local c = color or C.green
    local d = dur or 2.5
    
    if isNotifActive then
        table.insert(notifQueue, { msg = msg, color = c, dur = d })
    else
        showNotificationInternal(msg, c, d)
    end
end

----------------------------------------------------------------
-- Daily Reward Popup
----------------------------------------------------------------
local dailyPopup = createGlassFrame("DailyReward", gui,
    UDim2.new(0, 300, 0, 220),
    UDim2.new(0.5, -150, 0.5, -300))
dailyPopup.Visible = false
dailyPopup.ZIndex = 10

local dailyTitle = Instance.new("TextLabel")
dailyTitle.Size = UDim2.new(1, -20, 0, 30)
dailyTitle.Position = UDim2.new(0, 10, 0, 10)
dailyTitle.BackgroundTransparency = 1
dailyTitle.Text = "Daily Reward"
dailyTitle.TextColor3 = C.gold
dailyTitle.TextSize = 24
dailyTitle.Font = Enum.Font.GothamBlack
dailyTitle.Parent = dailyPopup

local dailyStreak = Instance.new("TextLabel")
dailyStreak.Size = UDim2.new(1, -20, 0, 20)
dailyStreak.Position = UDim2.new(0, 10, 0, 45)
dailyStreak.BackgroundTransparency = 1
dailyStreak.Text = "Streak: 0 days"
dailyStreak.TextColor3 = C.dimWhite
dailyStreak.TextSize = 14
dailyStreak.Font = Enum.Font.GothamBold
dailyStreak.Parent = dailyPopup

local dailyRewardAmount = Instance.new("TextLabel")
dailyRewardAmount.Size = UDim2.new(1, -20, 0, 40)
dailyRewardAmount.Position = UDim2.new(0, 10, 0, 70)
dailyRewardAmount.BackgroundTransparency = 1
dailyRewardAmount.Text = "+50 💎"
dailyRewardAmount.TextColor3 = C.accent
dailyRewardAmount.TextSize = 32
dailyRewardAmount.Font = Enum.Font.GothamBlack
dailyRewardAmount.Parent = dailyPopup

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 200, 0, 40)
claimBtn.Position = UDim2.new(0.5, -100, 1, -55)
claimBtn.BackgroundColor3 = C.green
claimBtn.BorderSizePixel = 0
claimBtn.Text = "CLAIM"
claimBtn.TextColor3 = C.white
claimBtn.TextSize = 16
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.Parent = dailyPopup
Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 8)

claimBtn.MouseButton1Click:Connect(function()
    playerAction:FireServer("ClaimDailyReward")
    dailyPopup.Visible = false
end)

----------------------------------------------------------------
-- Floating Combat Text (for coin pickups)
----------------------------------------------------------------
local fctContainer = Instance.new("Frame")
fctContainer.Name = "FCT"
fctContainer.Size = UDim2.new(1, 0, 1, 0)
fctContainer.BackgroundTransparency = 1
fctContainer.Parent = gui

local function spawnFloatingText(text: string, color: Color3, screenPos: Vector2?)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 100, 0, 30)
    if screenPos then
        label.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y)
    else
        label.Position = UDim2.new(0.5, -50, 0.5, 0)
    end
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 18
    label.Font = Enum.Font.GothamBlack
    label.Parent = fctContainer
    
    TweenService:Create(label, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(label.Position.X.Scale, label.Position.X.Offset, label.Position.Y.Scale, label.Position.Y.Offset - 60),
        TextTransparency = 1,
    }):Play()
    
    task.delay(1.0, function()
        label:Destroy()
    end)
end

----------------------------------------------------------------
-- Micro-Animations
----------------------------------------------------------------
-- Weak table: prevents retention of destroyed GUI objects, avoiding memory growth.
local canonicalSizes: { [GuiObject]: { size: UDim2, pos: UDim2 } } = setmetatable({}, { __mode = "k" })

local function popAnimate(guiObj: GuiObject)
    if not canonicalSizes[guiObj] then
        canonicalSizes[guiObj] = { size = guiObj.Size, pos = guiObj.Position }
    end
    local canon = canonicalSizes[guiObj]
    local origSize = canon.size
    local origPos = canon.pos
    
    guiObj.Size = UDim2.new(origSize.X.Scale, origSize.X.Offset + 10, origSize.Y.Scale, origSize.Y.Offset + 10)
    guiObj.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset - 5, origPos.Y.Scale, origPos.Y.Offset - 5)
    
    TweenService:Create(guiObj, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = origSize,
        Position = origPos,
    }):Play()
end

----------------------------------------------------------------
-- State & Local Timer
----------------------------------------------------------------
local currentCP = 0
local totalCP = 0
local runCoins = 0
local currentCombo = 0
local comboMultiplier = 1.0

local runStartTime = 0
local isRunningLocally = false
local timerConnection: RBXScriptConnection? = nil

local function isFinite(n: number): boolean
    return n == n and n ~= math.huge and n ~= -math.huge
end

local function formatTime(seconds: number): string
    if not isFinite(seconds) then return "--:--" end
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
            local elapsed = os.clock() - runStartTime
            timerLabel.Text = formatTime(elapsed)
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
-- Reset Actions
----------------------------------------------------------------
local isResetting = false
resetBtn.MouseButton1Click:Connect(function()
    if isResetting then return end
    isResetting = true
    stopLocalTimer()
    timerLabel.Text = "0:00.00"
    comboLabel.Visible = false
    currentCombo = 0
    comboMultiplier = 1.0
    playerAction:FireServer("RequestReset")
    
    -- Shake animation
    local origPos = panel.Position
    TweenService:Create(panel, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
        Position = UDim2.new(origPos.X.Scale, origPos.X.Offset - 5, origPos.Y.Scale, origPos.Y.Offset),
    }):Play()
    
    task.delay(1.0, function()
        isResetting = false
    end)
end)

----------------------------------------------------------------
-- Daily Reward Handler
----------------------------------------------------------------
dailyRewardEvent.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then return end
    local t = payload.type
    local d: any = payload.data or {}
    
    if t == "RewardAvailable" then
        dailyStreak.Text = string.format("Streak: %d days", d.streak)
        dailyRewardAmount.Text = string.format("+%d 💎", d.reward)
        if d.isPremium then
            dailyRewardAmount.Text ..= " (+Premium)"
        end
        -- Reset button state in case it was set to CLOSE from a previous AlreadyClaimed
        claimBtn.Text = "CLAIM"
        claimBtn.BackgroundColor3 = C.green
        dailyPopup.Visible = true
        -- Slide in from top
        dailyPopup.Position = UDim2.new(0.5, -150, 0.5, -400)
        TweenService:Create(dailyPopup, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -150, 0.5, -150),
        }):Play()
        
    elseif t == "AlreadyClaimed" then
        dailyStreak.Text = string.format("Streak: %d days", d.streak)
        dailyRewardAmount.Text = "Come back tomorrow!"
        claimBtn.Text = "CLOSE"
        claimBtn.BackgroundColor3 = C.dimWhite
        dailyPopup.Visible = true
    end
end)

----------------------------------------------------------------
-- UIUpdate Handler (Main)
----------------------------------------------------------------
type UIPayload = { type: string, data: { [string]: any } }

uiUpdate.OnClientEvent:Connect(function(payload: UIPayload)
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local t = payload.type
    local d: any = payload.data or {}

    if t == "RunStarted" then
        totalCP = d.totalCheckpoints or 0
        currentCP = 0
        runCoins = 0
        currentCombo = 0
        comboMultiplier = 1.0
        timerLabel.Text = "0:00.00"
        timerLabel.TextColor3 = C.white
        timerGlow.Transparency = 0.9
        cpLabel.Text = string.format("Checkpoints: 0 / %d", totalCP)
        coinsLabel.Text = "💎 0"
        bestLabel.Text = formatBestTime(d.bestTime)
        comboLabel.Visible = false
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        
        -- Badges
        badgeContainer:ClearAllChildren()
        badgeContainer.Size = UDim2.new(0, 0, 0, 16)
        if d.hasVIP then addBadge("VIP", C.gold) end
        if d.isPremium then addBadge("PREMIUM", C.purple) end
        if d.hasDoubleCoins then addBadge("2x", C.orange) end
        
        showNotification("GO!", C.green, 1.5)
        startLocalTimer()

    elseif t == "CheckpointHit" then
        currentCP = d.checkpoint or currentCP
        totalCP = d.total or totalCP
        cpLabel.Text = string.format("Checkpoints: %d / %d", currentCP, totalCP)
        showNotification(string.format("Checkpoint %d / %d", currentCP, totalCP), C.accent, 1.5)
        popAnimate(cpLabel)
        
        -- Update progress bar
        local progress = if totalCP > 0 then currentCP / totalCP else 0
        TweenService:Create(progressFill, TweenInfo.new(Config.PROGRESS_BAR_ANIMATION, Enum.EasingStyle.Quad), {
            Size = UDim2.new(progress, 0, 1, 0),
        }):Play()
        
        -- Combo display
        local comboCount = d.comboCount or 0
        if comboCount >= 2 then
            comboLabel.Visible = true
            local tier = d.comboLabel or ("x" .. tostring(d.comboMultiplier or 1.0))
            comboLabel.Text = string.format("COMBO x%d! %s", comboCount, tier)
            
            local comboColor = C.gold
            if comboCount >= 5 then comboColor = C.orange end
            if comboCount >= 8 then comboColor = C.red end
            comboLabel.TextColor3 = comboColor
            
            TweenService:Create(comboLabel, TweenInfo.new(0.2), { TextSize = 18 }):Play()
            task.delay(0.2, function()
                TweenService:Create(comboLabel, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), { TextSize = 14 }):Play()
            end)
        end

    elseif t == "CoinCollected" then
        runCoins = d.coinsThisRun or (runCoins + 1)
        local mult = d.comboMultiplier or 1.0
        coinsLabel.Text = string.format("💎 %d (x%.1f)", runCoins, mult)
        coinsLabel.TextColor3 = C.white
        popAnimate(coinsLabel)
        TweenService:Create(coinsLabel, TweenInfo.new(0.3), { TextColor3 = C.accent }):Play()
        
        -- Floating text
        spawnFloatingText("+1 💎", C.gold)

    elseif t == "RunFinished" then
        stopLocalTimer()
        timerLabel.Text = d.formattedTime or timerLabel.Text
        comboLabel.Visible = false
        currentCombo = 0
        comboMultiplier = 1.0
        coinsLabel.Text = string.format("💎 %d", d.totalCoins or 0)
        runsLabel.Text = string.format("Runs: %d", d.totalRuns or 0)
        popAnimate(timerLabel)
        
        if d.isNewBest then
            timerLabel.TextColor3 = C.gold
            timerGlow.Transparency = 0.3
            TweenService:Create(timerGlow, TweenInfo.new(2.0), { Transparency = 0.9 }):Play()
            bestLabel.Text = formatBestTime(d.bestTime)
            showNotification("NEW BEST! " .. (d.formattedTime or ""), C.gold, 4)
        else
            bestLabel.Text = formatBestTime(d.bestTime)
            showNotification("Finished: " .. (d.formattedTime or ""), C.green, 3)
        end

    elseif t == "DataLoaded" then
        totalCP = d.totalCheckpoints or 0
        cpLabel.Text = string.format("Checkpoints: 0 / %d", totalCP)
        coinsLabel.Text = string.format("💎 %d", d.totalCoins or 0)
        bestLabel.Text = formatBestTime(d.bestTime)
        runsLabel.Text = string.format("Runs: %d", d.totalRuns or 0)
        
        -- Badges
        badgeContainer:ClearAllChildren()
        badgeContainer.Size = UDim2.new(0, 0, 0, 16)
        if d.hasVIP then addBadge("VIP", C.gold) end
        if d.isPremium then addBadge("PREMIUM", C.purple) end
        if d.hasDoubleCoins then addBadge("2x", C.orange) end

    elseif t == "Notification" then
        local color = C.green
        if d.color == "red" then color = C.red
        elseif d.color == "gold" then color = C.gold
        elseif d.color == "blue" then color = C.accent end
        showNotification(d.message or "", color, d.duration or 2.5)

    elseif t == "PurchaseSuccess" then
        showNotification("Purchased: " .. (d.item or ""), C.green, 3)
        
    elseif t == "PurchaseFailed" then
        showNotification("Not enough coins!", C.red, 3)
        
    elseif t == "CoinPurchase" then
        spawnFloatingText("+" .. (d.amount or 0) .. " 💎", C.gold)
    end
end)

print("[ObbyHUD] S-tier HUD initialized")
