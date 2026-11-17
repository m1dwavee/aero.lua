-- ======================================================================
-- AeroSteal v9.5 - Robust Link Box & Auto Stealer
-- ======================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local fpp = fireproximityprompt

-- ======================================================================
-- BÖLGE TIER TABLOSU (En İyiden En Düşüğe)
-- ======================================================================
local AREA_TIERS = {
    ["Alien"]            = 15,
    ["Enchanted Forest"] = 14,
    ["Volcano"]          = 13,
    ["Lake"]             = 12,
    ["Prehistoric"]      = 11,
    ["Jungle"]           = 10,
    ["Titan Temple"]     = 9,
    ["Snow"]             = 8,
    ["Light Dark"]       = 7,
    ["Stormlands"]       = 6,
    ["Cosmic"]           = 5,
    ["Abyss Ocean"]      = 4,
    ["Cherry Blossom"]   = 3,
    ["Desert"]           = 2,
    ["Forest"]           = 1,
}

local AREA_LIST = {
    "Tümü (En İyisi Önce)",
    "Alien",
    "Enchanted Forest",
    "Volcano",
    "Lake",
    "Prehistoric",
    "Jungle",
    "Titan Temple",
    "Snow",
    "Light Dark",
    "Stormlands",
    "Cosmic",
    "Abyss Ocean",
    "Cherry Blossom",
    "Desert",
    "Forest"
}

-- Modüller
local EggState = nil
local AreaData = nil
local AssetData = nil
local SlotIdentity = nil

pcall(function() EggState = require(ReplicatedStorage.Client.EggState) end)
pcall(function() AreaData = require(ReplicatedStorage.Data.Areas) end)
pcall(function() AssetData = require(ReplicatedStorage.Data.Assets) end)
pcall(function() SlotIdentity = require(ReplicatedStorage.Shared.Util.AreaEggSlotIdentity) end)

local function GetSeparationLine()
    local areas = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Areas")
    return areas and areas:FindFirstChild("SeparationLine")
end

-- Durum Değişkenleri
local State = {
    AutoSteal = false,
    Speed = 70,
    SelectedArea = "Tümü (En İyisi Önce)",
    StolenCount = 0,
    Status = "Hazır",
}

local function GetCharacter()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if char and hum and hum.Health > 0 and root then
        return char, hum, root
    end
    return nil, nil, nil
end

-- ======================================================================
-- AKICI HIZLI KOŞU MOTORU
-- ======================================================================
local function RunTo(targetPos)
    local char, hum, root = GetCharacter()
    if not root then return false end

    while State.AutoSteal do
        local c, h, r = GetCharacter()
        if not c or not r or not h or h.Health <= 0 then return false end

        local diff = targetPos - r.Position
        local dist = diff.Magnitude

        if dist <= 3.5 then break end

        local step = math.min(dist, State.Speed * 0.033)
        local newPos = r.Position + (diff.Unit * step)

        r.CFrame = CFrame.lookAt(newPos, newPos + diff.Unit)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.03)
    end
    return true
end

RunService.Stepped:Connect(function()
    if State.AutoSteal then
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
-- HEDEF BULUCU (Oyun Verilerine Göre)
-- ======================================================================
local function ScoreEggRecord(egg)
    local score = 0
    local tier = AREA_TIERS[egg.AreaId] or 1
    score = score + (tier * 100000)

    if AssetData and AssetData.Directory and AssetData.Directory[egg.AssetCategory] then
        local entry = AssetData.Directory[egg.AssetCategory]
        if entry.Rarity then
            local rId = tostring(entry.Rarity._id or "")
            if string.find(rId, "Divine") or string.find(rId, "Secret") then score = score + 80000
            elseif string.find(rId, "Mythic") then score = score + 40000
            elseif string.find(rId, "Legendary") then score = score + 20000
            elseif string.find(rId, "Epic") then score = score + 10000
            end
        end
    end

    score = score + ((egg.AssetScale or 1) * 2000)

    if egg.Mutations and #egg.Mutations > 0 then
        for _, mut in ipairs(egg.Mutations) do
            if string.find(mut, "Rainbow") then score = score + 15000
            elseif string.find(mut, "Golden") then score = score + 8000
            else score = score + 3000 end
        end
    end

    return score
end

local function FindBestTarget()
    local best = nil
    local maxScore = -math.huge

    if EggState then
        local ok, data = pcall(function() return EggState.ReadFieldEggs() end)
        if ok and data and data.Records then
            for _, egg in ipairs(data.Records) do
                if egg.State == "Slot" or egg.State == "Dropped" then
                    if State.SelectedArea == "Tümü (En İyisi Önce)" or egg.AreaId == State.SelectedArea then
                        local sc = ScoreEggRecord(egg)
                        if sc > maxScore then
                            maxScore = sc
                            best = {
                                Uid = egg.Uid,
                                AreaId = egg.AreaId,
                                NestId = egg.NestId,
                                Name = egg.AssetCategory,
                                Position = egg.BottomCFrame.Position,
                            }
                        end
                    end
                end
            end
        end
    end

    if not best then
        local guardAreas = Workspace:FindFirstChild("World")
            and Workspace.World:FindFirstChild("Areas")
            and Workspace.World.Areas:FindFirstChild("GuardAreas")

        if guardAreas then
            for _, areaName in ipairs(AREA_LIST) do
                if areaName ~= "Tümü (En İyisi Önce)" then
                    if State.SelectedArea == "Tümü (En İyisi Önce)" or State.SelectedArea == areaName then
                        local areaModel = guardAreas:FindFirstChild(areaName)
                        local nests = areaModel and areaModel:FindFirstChild("Nests")
                        if nests then
                            for _, nest in ipairs(nests:GetChildren()) do
                                local spot = nest:FindFirstChild("EggSpotBottom")
                                if spot then
                                    best = {
                                        Uid = nil,
                                        AreaId = areaName,
                                        NestId = nest.Name,
                                        Name = areaName .. " Egg",
                                        Position = spot.Position,
                                    }
                                    break
                                end
                            end
                        end
                        if best then break end
                    end
                end
            end
        end
    end

    return best
end

local function PickupEgg(target)
    if target.Uid and EggState and SlotIdentity then
        local slotKey = nil
        if SlotIdentity.LooksLikeFirstAreaUid(target.Uid) then
            slotKey = SlotIdentity.SlotKey(target.AreaId, target.NestId)
        end
        pcall(function() EggState.CarryFieldEgg(target.Uid, slotKey) end)
    end

    local _, _, root = GetCharacter()
    if root then
        local smart = Workspace:FindFirstChild("SmartPromptPart")
        if smart then
            for _, p in ipairs(smart:GetChildren()) do
                if p:IsA("ProximityPrompt") then
                    p.RequiresLineOfSight = false
                    p.MaxActivationDistance = 50
                    if fpp then fpp(p, 0) end
                end
            end
        end

        for _, p in ipairs(Workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and (p.Name == "CarryAreaEgg" or p.ActionText == "Steal") then
                if p.Parent and (p.Parent.Position - root.Position).Magnitude <= 20 then
                    p.RequiresLineOfSight = false
                    p.MaxActivationDistance = 50
                    if fpp then fpp(p, 0) end
                end
            end
        end
    end
end

-- 1-A KURALI (SeparationLine Teslimatı)
local function DeliverEgg()
    local sepLine = GetSeparationLine()
    if sepLine then
        RunTo(sepLine.Position + Vector3.new(-18, 0, 0))
    end

    local timeout = os.clock() + 3
    while State.AutoSteal and os.clock() < timeout do
        local isCarrying = false
        if EggState then
            pcall(function() isCarrying = EggState.ReadCarryState().IsCarrying end)
        end
        if not isCarrying then break end
        task.wait(0.15)
    end
end

-- Ana Döngü
task.spawn(function()
    while true do
        task.wait(0.2)
        if State.AutoSteal then
            local isCarrying = false
            if EggState then
                pcall(function() isCarrying = EggState.ReadCarryState().IsCarrying end)
            end

            if isCarrying then
                State.Status = "🏃 SeparationLine'a koşuluyor..."
                DeliverEgg()
                State.StolenCount = State.StolenCount + 1
                State.Status = "✅ Teslim Edildi!"
                task.wait(0.25)
            else
                State.Status = "🔍 En iyi egg aranıyor..."
                local target = FindBestTarget()

                if target then
                    State.Status = string.format("🎯 [%s] -> %s", target.AreaId, target.Name)
                    local runOk = RunTo(target.Position + Vector3.new(0, 0.5, 0))

                    if runOk and State.AutoSteal then
                        State.Status = "⚡ Alınıyor..."
                        local grabEnd = os.clock() + 2.5
                        while State.AutoSteal and os.clock() < grabEnd do
                            PickupEgg(target)
                            task.wait(0.15)
                            local gotIt = false
                            if EggState then
                                pcall(function() gotIt = EggState.ReadCarryState().IsCarrying end)
                            end
                            if gotIt then break end
                        end
                    end
                else
                    State.Status = "⏳ Yumurta bulunamadı..."
                    task.wait(1.5)
                end
            end
        end
    end
end)

-- ======================================================================
-- ⚡ DPASTE LİNK OLUŞTURUCU (Hafifletilmiş & Garantili)
-- ======================================================================
local function DumpCriticalScripts(onSuccess, onStatus)
    onStatus("Kritik oyun kodları taranıyor...")
    task.wait(0.1)

    local output = {}
    local header = string.rep("=", 70)
    table.insert(output, header)
    table.insert(output, ("-- AEROSTEAL KRİTİK OYUN VERİLERİ & KODLARI"))
    table.insert(output, ("-- Zaman: %s | PlaceId: %d"):format(os.date(), game.PlaceId))
    table.insert(output, header .. "\n")

    local decompileFn = decompile or disassemble
    local targets = {}

    -- Öncelikli ve kritik modülleri seç (Boyut patlamasını önler!)
    local function AddTarget(inst)
        if inst and (inst:IsA("ModuleScript") or inst:IsA("LocalScript")) then
            targets[#targets + 1] = inst
        end
    end

    -- ReplicatedStorage altındaki kritik dosyalar
    if ReplicatedStorage:FindFirstChild("Client") then
        for _, m in ipairs(ReplicatedStorage.Client:GetDescendants()) do AddTarget(m) end
    end
    if ReplicatedStorage:FindFirstChild("Data") then
        for _, m in ipairs(ReplicatedStorage.Data:GetDescendants()) do AddTarget(m) end
    end
    if ReplicatedStorage:FindFirstChild("Shared") then
        for _, m in ipairs(ReplicatedStorage.Shared:GetDescendants()) do
            if #targets < 45 then AddTarget(m) end
        end
    end

    local count = 0
    for _, desc in ipairs(targets) do
        count = count + 1
        table.insert(output, header)
        table.insert(output, ("-- [%d] %s (%s)"):format(count, desc:GetFullName(), desc.ClassName))
        table.insert(output, header)

        local extracted = false
        if typeof(decompileFn) == "function" then
            local okDec, code = pcall(decompileFn, desc)
            if okDec and type(code) == "string" and #code > 5 then
                table.insert(output, code)
                extracted = true
            end
        end

        if not extracted and desc:IsA("ModuleScript") then
            local okReq, res = pcall(require, desc)
            if okReq then
                pcall(function()
                    table.insert(output, "return " .. HttpService:JSONEncode(res))
                    extracted = true
                end)
            end
        end

        if not extracted then
            table.insert(output, "-- [Kod korumalı veya okunamadı]")
        end
        table.insert(output, "\n\n")
    end

    local fullText = table.concat(output, "\n")
    onStatus("Link üretiliyor (dpaste)...")

    -- 1. Dosyaya yaz (Emülatör workspace)
    if typeof(writefile) == "function" then
        pcall(function() writefile("AeroSteal_Dump.lua", fullText) end)
    end

    -- 2. Web API isteği
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    local link = nil

    if req then
        local okPost, res = pcall(function()
            return req({
                Url = "https://dpaste.org/api/",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
                Body = "content=" .. HttpService:UrlEncode(fullText) .. "&format=url"
            })
        end)
        if okPost and res and res.Body then
            link = string.match(res.Body, "https://dpaste%.org/[%w]+")
        end
    end

    if link then
        if setclipboard then pcall(setclipboard, link) end
        onSuccess(link)
    else
        if setclipboard then pcall(setclipboard, fullText:sub(1, 4000)) end
        onSuccess("Link sunucusu yanıt vermedi, dosya 'AeroSteal_Dump.lua' kaydedildi.")
    end
end

-- ======================================================================
-- ARAYÜZ (Gelişmiş Link Kutulu Cyber UI)
-- ======================================================================
local parentGui = nil
pcall(function() parentGui = game:GetService("CoreGui") end)
if not parentGui or not pcall(function() return parentGui.Name end) then
    parentGui = LocalPlayer:WaitForChild("PlayerGui")
end

local old = parentGui:FindFirstChild("AeroSteal_v95")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AeroSteal_v95"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = parentGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 340, 0, 420)
MainFrame.Position = UDim2.new(0.05, 0, 0.18, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(99, 102, 241)

-- TopBar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.04, 0, 0, 0)
Title.Text = "⚡ AEROSTEAL <font color=\"#818cf8\">v9.5 PRO</font>"
Title.RichText = true
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Parent = TopBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(0.88, 0, 0.16, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 46)
MinBtn.Text = "─"
MinBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.Parent = TopBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local isMin = false
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        MainFrame:TweenSize(UDim2.new(0, 340, 0, 42), "Out", "Quad", 0.2, true)
        MinBtn.Text = "□"
    else
        MainFrame:TweenSize(UDim2.new(0, 340, 0, 420), "Out", "Quad", 0.2, true)
        MinBtn.Text = "─"
    end
end)

-- İçerik
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -42)
Content.Position = UDim2.new(0, 0, 0, 42)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- Durum Kutusu
local StatusBox = Instance.new("TextLabel")
StatusBox.Size = UDim2.new(0.92, 0, 0, 44)
StatusBox.Position = UDim2.new(0.04, 0, 0.03, 0)
StatusBox.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
StatusBox.TextColor3 = Color3.fromRGB(52, 211, 153)
StatusBox.Font = Enum.Font.Gotham
StatusBox.TextSize = 12
StatusBox.TextWrapped = true
StatusBox.Text = "Hazır. Auto Steal'i başlatabilirsin."
StatusBox.Parent = Content
Instance.new("UICorner", StatusBox).CornerRadius = UDim.new(0, 8)

-- Auto Steal Butonu
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.92, 0, 0, 42)
ToggleBtn.Position = UDim2.new(0.04, 0, 0.17, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
ToggleBtn.Text = "AUTO STEAL BAŞLAT"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.Parent = Content
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

ToggleBtn.MouseButton1Click:Connect(function()
    State.AutoSteal = not State.AutoSteal
    if State.AutoSteal then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        ToggleBtn.Text = "AUTO STEAL: AKTİF"
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
        ToggleBtn.Text = "AUTO STEAL BAŞLAT"
        StatusBox.Text = "Durduruldu."
    end
end)

-- Bölge Seçici
local AreaBtn = Instance.new("TextButton")
AreaBtn.Size = UDim2.new(0.92, 0, 0, 34)
AreaBtn.Position = UDim2.new(0.04, 0, 0.30, 0)
AreaBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
AreaBtn.Text = "Bölge: Tümü (En İyisi Önce)"
AreaBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
AreaBtn.Font = Enum.Font.GothamMedium
AreaBtn.TextSize = 12
AreaBtn.Parent = Content
Instance.new("UICorner", AreaBtn).CornerRadius = UDim.new(0, 8)

local areaIdx = 1
AreaBtn.MouseButton1Click:Connect(function()
    areaIdx = (areaIdx % #AREA_LIST) + 1
    State.SelectedArea = AREA_LIST[areaIdx]
    AreaBtn.Text = "Bölge: " .. State.SelectedArea
end)

-- Hız Butonları
local SpeedRow = Instance.new("Frame")
SpeedRow.Size = UDim2.new(0.92, 0, 0, 30)
SpeedRow.Position = UDim2.new(0.04, 0, 0.41, 0)
SpeedRow.BackgroundTransparency = 1
SpeedRow.Parent = Content

local function AddSpeedBtn(txt, spd, xPos, isDef)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.31, 0, 1, 0)
    b.Position = UDim2.new(xPos, 0, 0, 0)
    b.BackgroundColor3 = isDef and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(26, 28, 38)
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = SpeedRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local sp50 = AddSpeedBtn("50 Güvenli", 50, 0, false)
local sp70 = AddSpeedBtn("70 Hızlı", 70, 0.345, true)
local sp90 = AddSpeedBtn("90 Turbo", 90, 0.69, false)

local function PickSpeed(val, btn)
    State.Speed = val
    for _, b in ipairs({sp50, sp70, sp90}) do
        b.BackgroundColor3 = (b == btn) and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(26, 28, 38)
    end
end
sp50.MouseButton1Click:Connect(function() PickSpeed(50, sp50) end)
sp70.MouseButton1Click:Connect(function() PickSpeed(70, sp70) end)
sp90.MouseButton1Click:Connect(function() PickSpeed(90, sp90) end)

-- Kodları Çek Butonu
local DumpBtn = Instance.new("TextButton")
DumpBtn.Size = UDim2.new(0.92, 0, 0, 36)
DumpBtn.Position = UDim2.new(0.04, 0, 0.52, 0)
DumpBtn.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
DumpBtn.Text = "⚡ TÜM OYUN KODLARINI ÇEK & LİNK YAP"
DumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DumpBtn.Font = Enum.Font.GothamBold
DumpBtn.TextSize = 12
DumpBtn.Parent = Content
Instance.new("UICorner", DumpBtn).CornerRadius = UDim.new(0, 8)

-- DOĞRUDAN EKRANDA GÖRÜNEN KOPYALANABİLİR LİNK KUTUSU (TextBox)
local LinkBox = Instance.new("TextBox")
LinkBox.Size = UDim2.new(0.92, 0, 0, 34)
LinkBox.Position = UDim2.new(0.04, 0, 0.64, 0)
LinkBox.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
LinkBox.TextColor3 = Color3.fromRGB(129, 140, 248)
LinkBox.Font = Enum.Font.Gotham
LinkBox.TextSize = 11
LinkBox.ClearTextOnFocus = false
LinkBox.Text = "Link burada çıkacak (üzerine tıklayıp kopyala)"
LinkBox.Parent = Content
Instance.new("UICorner", LinkBox).CornerRadius = UDim.new(0, 6)
local LinkStroke = Instance.new("UIStroke", LinkBox)
LinkStroke.Thickness = 1
LinkStroke.Color = Color3.fromRGB(45, 48, 64)

DumpBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        DumpCriticalScripts(function(resUrl)
            LinkBox.Text = resUrl
            StatusBox.Text = "🎉 Link Oluştu! Aşağıdaki kutudan kopyala."
        end, function(st)
            StatusBox.Text = st
        end)
    end)
end)

-- Alt Bilgi
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(0.92, 0, 0, 28)
Footer.Position = UDim2.new(0.04, 0, 0.88, 0)
Footer.BackgroundTransparency = 1
Footer.TextColor3 = Color3.fromRGB(150, 150, 170)
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 11
Footer.Text = "Çalınan: 0 | Teslim: 1-A (SeparationLine)"
Footer.Parent = Content

task.spawn(function()
    while true do
        if State.AutoSteal then
            StatusBox.Text = State.Status
        end
        Footer.Text = string.format("Çalınan: %d adet | Hız: %d s/s | Teslim: 1-A", State.StolenCount, State.Speed)
        task.wait(0.25)
    end
end)
