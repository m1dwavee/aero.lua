-- ======================================================================
-- AeroSteal v8.5 ULTRA - Cyber Neon Edition
-- ======================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local function GetCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 10)
    local hum = char:WaitForChild("Humanoid", 10)
    return char, root, hum
end

-- ======================================================================
-- GÖRSEL ARAYÜZ (Ultra Modern Cyber UI)
-- ======================================================================
local parentGui = nil
pcall(function() parentGui = CoreGui end)
if not parentGui or not pcall(function() return parentGui.Name end) then
    parentGui = LocalPlayer:WaitForChild("PlayerGui")
end

local existing = parentGui:FindFirstChild("AeroSteal_Ultra_UI")
if existing then existing:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AeroSteal_Ultra_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = parentGui

-- Ana Pencere
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 330, 0, 380)
MainFrame.Position = UDim2.new(0.05, 0, 0.22, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(80, 70, 220)

-- Üst Bar (Header)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.04, 0, 0, 0)
Title.Text = "⚡ AEROSTEAL <font color=\"#60a5fa\">ULTRA</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Parent = TopBar

-- Küçültme (Minimize) Butonu
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(0.88, 0, 0.16, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
MinBtn.Text = "─"
MinBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.Parent = TopBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- İçerik Taşıyıcı
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -42)
Content.Position = UDim2.new(0, 0, 0, 42)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- Canlı Durum Kartı
local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(0.92, 0, 0, 52)
StatusCard.Position = UDim2.new(0.04, 0, 0.04, 0)
StatusCard.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
StatusCard.Parent = Content
Instance.new("UICorner", StatusCard).CornerRadius = UDim.new(0, 8)
local StatusStroke = Instance.new("UIStroke", StatusCard)
StatusStroke.Thickness = 1
StatusStroke.Color = Color3.fromRGB(45, 48, 62)

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0.04, 0, 0.22, 0)
StatusDot.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
StatusDot.Parent = StatusCard
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(0.84, 0, 0.4, 0)
StatusText.Position = UDim2.new(0.1, 0, 0.12, 0)
StatusText.Text = "Sistem Durduruldu"
StatusText.TextColor3 = Color3.fromRGB(220, 220, 230)
StatusText.Font = Enum.Font.GothamMedium
StatusText.TextSize = 12
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.BackgroundTransparency = 1
StatusText.Parent = StatusCard

local TargetInfo = Instance.new("TextLabel")
TargetInfo.Size = UDim2.new(0.84, 0, 0.4, 0)
TargetInfo.Position = UDim2.new(0.1, 0, 0.52, 0)
TargetInfo.Text = "Hedef: Bekleniyor..."
TargetInfo.TextColor3 = Color3.fromRGB(120, 130, 150)
TargetInfo.Font = Enum.Font.Gotham
TargetInfo.TextSize = 11
TargetInfo.TextXAlignment = Enum.TextXAlignment.Left
TargetInfo.BackgroundTransparency = 1
TargetInfo.Parent = StatusCard

-- Ana AUTO STEAL Aç/Kapa Butonu
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.92, 0, 0, 44)
ToggleBtn.Position = UDim2.new(0.04, 0, 0.23, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
ToggleBtn.Text = "AUTO STEAL BAŞLAT"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.Parent = Content
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

-- Base Konumu Kaydet Butonu
local SetBaseBtn = Instance.new("TextButton")
SetBaseBtn.Size = UDim2.new(0.92, 0, 0, 36)
SetBaseBtn.Position = UDim2.new(0.04, 0, 0.38, 0)
SetBaseBtn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
SetBaseBtn.Text = "📍 Bulunduğum Yeri Base Kaydet"
SetBaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SetBaseBtn.Font = Enum.Font.GothamMedium
SetBaseBtn.TextSize = 12
SetBaseBtn.Parent = Content
Instance.new("UICorner", SetBaseBtn).CornerRadius = UDim.new(0, 8)

-- Filtre Butonu
local FilterBtn = Instance.new("TextButton")
FilterBtn.Size = UDim2.new(0.92, 0, 0, 34)
FilterBtn.Position = UDim2.new(0.04, 0, 0.50, 0)
FilterBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
FilterBtn.Text = "✨ Filtre: Tüm Yumurtalar"
FilterBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
FilterBtn.Font = Enum.Font.Gotham
FilterBtn.TextSize = 12
FilterBtn.Parent = Content
Instance.new("UICorner", FilterBtn).CornerRadius = UDim.new(0, 8)
local FilterStroke = Instance.new("UIStroke", FilterBtn)
FilterStroke.Thickness = 1
FilterStroke.Color = Color3.fromRGB(50, 54, 70)

-- Hız Seçim Çubuğu
local SpeedBar = Instance.new("Frame")
SpeedBar.Size = UDim2.new(0.92, 0, 0, 32)
SpeedBar.Position = UDim2.new(0.04, 0, 0.62, 0)
SpeedBar.BackgroundTransparency = 1
SpeedBar.Parent = Content

local function CreateSpeedBtn(name, speedVal, posX, isDefault)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.31, 0, 1, 0)
    btn.Position = UDim2.new(posX, 0, 0, 0)
    btn.BackgroundColor3 = isDefault and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(26, 28, 36)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.Parent = SpeedBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local spd50 = CreateSpeedBtn("50 Güvenli", 50, 0, false)
local spd70 = CreateSpeedBtn("70 Hızlı", 70, 0.345, true)
local spd90 = CreateSpeedBtn("90 Turbo", 90, 0.69, false)

-- İstatistik Altlığı
local StatsCard = Instance.new("Frame")
StatsCard.Size = UDim2.new(0.92, 0, 0, 48)
StatsCard.Position = UDim2.new(0.04, 0, 0.74, 0)
StatsCard.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
StatsCard.Parent = Content
Instance.new("UICorner", StatsCard).CornerRadius = UDim.new(0, 8)

local StatStolen = Instance.new("TextLabel")
StatStolen.Size = UDim2.new(0.48, 0, 1, 0)
StatStolen.Position = UDim2.new(0.02, 0, 0, 0)
StatStolen.Text = "🥚 Çalınan: <font color=\"#10b981\">0</font>"
StatStolen.RichText = true
StatStolen.TextColor3 = Color3.fromRGB(160, 160, 180)
StatStolen.Font = Enum.Font.GothamMedium
StatStolen.TextSize = 12
StatStolen.BackgroundTransparency = 1
StatStolen.Parent = StatsCard

local StatSpeed = Instance.new("TextLabel")
StatSpeed.Size = UDim2.new(0.48, 0, 1, 0)
StatSpeed.Position = UDim2.new(0.5, 0, 0, 0)
StatSpeed.Text = "⚡ Hız: <font color=\"#60a5fa\">70 s/s</font>"
StatSpeed.RichText = true
StatSpeed.TextColor3 = Color3.fromRGB(160, 160, 180)
StatSpeed.Font = Enum.Font.GothamMedium
StatSpeed.TextSize = 12
StatSpeed.BackgroundTransparency = 1
StatSpeed.Parent = StatsCard

-- ======================================================================
-- MOTOR AYARLARI
-- ======================================================================
local Config = {
    AutoSteal = false,
    Speed = 70,
    BaseCFrame = nil,
    OnlyMutations = false,
    StolenCount = 0,
}

local EggState = nil
local RemoteCarry = nil

pcall(function()
    EggState = require(ReplicatedStorage.Client.EggState)
    RemoteCarry = ReplicatedStorage.Packages.Networking.RF.EggWorld.AskFieldEggCarry
end)

local _, initialRoot = GetCharacter()
if initialRoot then Config.BaseCFrame = initialRoot.CFrame end

-- Hız Butonları Mantığı
local function SetSpeed(val, activeBtn)
    Config.Speed = val
    StatSpeed.Text = string.format("⚡ Hız: <font color=\"#60a5fa\">%d s/s</font>", val)
    for _, b in ipairs({spd50, spd70, spd90}) do
        b.BackgroundColor3 = (b == activeBtn) and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(26, 28, 36)
    end
end

spd50.MouseButton1Click:Connect(function() SetSpeed(50, spd50) end)
spd70.MouseButton1Click:Connect(function() SetSpeed(70, spd70) end)
spd90.MouseButton1Click:Connect(function() SetSpeed(90, spd90) end)

-- Minimize Butonu
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 330, 0, 42), "Out", "Quad", 0.2, true)
        MinBtn.Text = "□"
    else
        MainFrame:TweenSize(UDim2.new(0, 330, 0, 380), "Out", "Quad", 0.2, true)
        MinBtn.Text = "─"
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if Config.AutoSteal then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end
end)

-- ======================================================================
-- AKICI TWEEN HAREKET MOTORU
-- ======================================================================
local currentTween = nil
local bodyVelocity = nil

local function TweenGlide(targetPos)
    local char, root = GetCharacter()
    if not root then return false end

    if not bodyVelocity or bodyVelocity.Parent ~= root then
        if bodyVelocity then bodyVelocity:Destroy() end
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = root
    end

    local distance = (targetPos - root.Position).Magnitude
    local duration = distance / Config.Speed

    local tInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(root, tInfo, { CFrame = CFrame.new(targetPos) })
    currentTween:Play()

    local completed = false
    local conn
    conn = currentTween.Completed:Connect(function()
        completed = true
        if conn then conn:Disconnect() end
    end)

    while not completed and Config.AutoSteal do
        task.wait(0.05)
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    return completed
end

local function StopGlide()
    if currentTween then currentTween:Cancel() end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
end

-- ======================================================================
-- EN İYİ YUMURTA RADARI
-- ======================================================================
local function GetBestEgg()
    if not EggState then return nil end
    local data = nil
    pcall(function() data = EggState.ReadFieldEggs() end)
    if not data or not data.Records then return nil end

    local bestEgg = nil
    local bestScore = -math.huge
    local _, root = GetCharacter()

    for _, egg in ipairs(data.Records) do
        if egg.State == "Slot" or egg.State == "Dropped" then
            local isMut = egg.Mutations and #egg.Mutations > 0
            if not Config.OnlyMutations or isMut then
                local score = 0
                if isMut then
                    for _, m in ipairs(egg.Mutations) do
                        if string.find(m, "Rainbow") then score = score + 100000
                        elseif string.find(m, "Golden") then score = score + 40000
                        else score = score + 10000 end
                    end
                end

                score = score + ((egg.AssetScale or 1) * 800)

                if root and egg.BottomCFrame then
                    score = score - ((root.Position - egg.BottomCFrame.Position).Magnitude * 0.05)
                end

                if score > bestScore then
                    bestScore = score
                    bestEgg = egg
                end
            end
        end
    end

    return bestEgg
end

local function TriggerSteal(egg)
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Name == "CarryAreaEgg" then
            local char, root = GetCharacter()
            if root and prompt.Parent and (prompt.Parent.Position - root.Position).Magnitude < 18 then
                if fireproximityprompt then
                    fireproximityprompt(prompt, 0)
                end
            end
        end
    end

    pcall(function()
        if RemoteCarry and egg then
            RemoteCarry:InvokeServer({ Uid = egg.Uid })
        end
    end)
end

-- ======================================================================
-- BUTON ETKİLEŞİMLERİ
-- ======================================================================
ToggleBtn.MouseButton1Click:Connect(function()
    Config.AutoSteal = not Config.AutoSteal
    if Config.AutoSteal then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        ToggleBtn.Text = "AUTO STEAL AKTİF"
        StatusDot.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        StatusText.Text = "Sistem Çalışıyor"
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
        ToggleBtn.Text = "AUTO STEAL BAŞLAT"
        StatusDot.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        StatusText.Text = "Sistem Durduruldu"
        TargetInfo.Text = "Hedef: Bekleniyor..."
        StopGlide()
    end
end)

SetBaseBtn.MouseButton1Click:Connect(function()
    local _, root = GetCharacter()
    if root then
        Config.BaseCFrame = root.CFrame
        StatusText.Text = "📍 Base Konumu Güncellendi"
    end
end)

FilterBtn.MouseButton1Click:Connect(function()
    Config.OnlyMutations = not Config.OnlyMutations
    if Config.OnlyMutations then
        FilterBtn.Text = "✨ Filtre: Sadece Rainbow / Gold"
        FilterBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
    else
        FilterBtn.Text = "✨ Filtre: Tüm Yumurtalar"
        FilterBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    end
end)

-- ======================================================================
-- ANA DÖNGÜ (State Machine)
-- ======================================================================
task.spawn(function()
    while true do
        task.wait(0.2)
        if Config.AutoSteal and EggState then
            local carry = nil
            pcall(function() carry = EggState.ReadCarryState() end)

            -- Taşıma Durumu -> Base'e Kaçış
            if carry and carry.IsCarrying then
                StatusText.Text = "🏃 Base'e Taşınıyor..."
                if Config.BaseCFrame then
                    TweenGlide(Config.BaseCFrame.Position)
                end

                local giveUp = os.clock() + 4
                while EggState.ReadCarryState().IsCarrying and os.clock() < giveUp do
                    task.wait(0.2)
                end

                if not EggState.ReadCarryState().IsCarrying then
                    Config.StolenCount = Config.StolenCount + 1
                    StatStolen.Text = string.format("🥚 Çalınan: <font color=\"#10b981\">%d</font>", Config.StolenCount)
                    StatusText.Text = "✅ Teslim Edildi!"
                    task.wait(0.6)
                end

            -- Arama Durumu
            else
                StatusText.Text = "🔍 En İyi Egg Taranıyor..."
                local target = GetBestEgg()

                if target then
                    local mutStr = (target.Mutations and #target.Mutations > 0) and table.concat(target.Mutations, "+") or "Normal"
                    TargetInfo.Text = string.format("🎯 %s [%s] (%s)", target.AssetCategory, mutStr, target.AreaId)

                    local targetPos = target.BottomCFrame.Position + Vector3.new(0, 3.5, 0)
                    local reached = TweenGlide(targetPos)

                    if reached and Config.AutoSteal then
                        StatusText.Text = "⚡ Yumurta Alınıyor..."
                        local endT = os.clock() + 2.5
                        while not EggState.ReadCarryState().IsCarrying and os.clock() < endT and Config.AutoSteal do
                            TriggerSteal(target)
                            task.wait(0.15)
                        end
                    end
                else
                    TargetInfo.Text = "⏳ Uygun yumurta bulunamadı"
                    task.wait(1.5)
                end
            end
        end
    end
end)
