-- AeroSteal v5.0 FINAL : Steal An Egg (Temiz & Güvenli Sürüm)
-- Menü: RightShift veya ekrandaki mor "A" düğmesi

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local fpp = fireproximityprompt

-- ===== AYARLAR =====
local CONFIG = {
	StealHoldTime = 1.3,
	BaseWait = 1.2,
	DefaultSpeed = 45,
	PlayerColor = Color3.fromRGB(255, 75, 75),
	EggColor = Color3.fromRGB(255, 215, 0),
	Accent = Color3.fromRGB(130, 95, 255),
	DarkBg = Color3.fromRGB(18, 18, 24),
	CardBg = Color3.fromRGB(26, 26, 36),
}
-- ====================

local env = (getgenv and getgenv()) or _G
local previous = env.__AeroSteal
if type(previous) == "function" then pcall(previous) end
env.__AeroSteal = true

local function getGuiRoot()
	local ok, ui = pcall(function() return gethui and gethui() or nil end)
	if ok and ui then return ui end
	local okCore = pcall(function() return game:GetService("CoreGui"):GetChildren() end)
	if okCore then return game:GetService("CoreGui") end
	return LocalPlayer:WaitForChild("PlayerGui")
end
local guiRoot = getGuiRoot()

local state = {
	autoSteal = false,
	speedOn = false,
	speed = CONFIG.DefaultSpeed,
	selectedArea = "Forest",
}
local connections = {}
local baseCFrame = nil
local autoToken = 0
local screen, statusLabel
local nestIndex = 1

local function track(conn) connections[#connections + 1] = conn; return conn end

local function setStatus(text)
	print("[AeroSteal] " .. tostring(text))
	if statusLabel then statusLabel.Text = tostring(text) end
end

local function getCharacter()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if char and hum and hum.Health > 0 and root and root:IsA("BasePart") then
		return char, hum, root
	end
	return nil
end

-- ---------- GÜVENLİ VE AKICI KOŞU (BOZMA YAPMAZ) ----------
local function runTo(targetPos)
	local char, hum, root = getCharacter()
	if not char then return false end

	while state.autoSteal do
		local c, h, r = getCharacter()
		if not c or h.Health <= 0 then return false end

		local diff = targetPos - r.Position
		local dist = diff.Magnitude

		if dist <= 3.0 then break end

		local step = math.min(dist, state.speed * 0.03)
		local newPos = r.Position + (diff.Unit * step)

		r.CFrame = CFrame.lookAt(newPos, newPos + diff.Unit)
		r.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.03)
	end
	return true
end

-- ---------- YUVALARI BUL ----------
local function getNests()
	local list = {}
	local guardAreas = Workspace:FindFirstChild("World")
		and Workspace.World:FindFirstChild("Areas")
		and Workspace.World.Areas:FindFirstChild("GuardAreas")

	local scanRoot = guardAreas or Workspace
	for _, inst in ipairs(scanRoot:GetDescendants()) do
		if inst.Name == "EggSpotBottom" and inst:IsA("BasePart") then
			if state.selectedArea == "Tümü" or string.find(inst:GetFullName(), state.selectedArea) then
				list[#list + 1] = inst
			end
		end
	end
	return list
end

-- ---------- ÇALMA DÖNGÜSÜ ----------
local function stealCycle()
	local char, hum, root = getCharacter()
	if not char then return false, "Karakter yok." end

	local nests = getNests()
	if #nests == 0 then return false, "Yuva bulunamadı." end

	if nestIndex > #nests then nestIndex = 1 end
	local currentSpot = nests[nestIndex]
	local currentIdx = nestIndex
	nestIndex = (nestIndex % #nests) + 1

	-- 1. Yuvaya koş
	setStatus(("Yuva %d/%d koşuluyor..."):format(currentIdx, #nests))
	local okRun = runTo(currentSpot.Position + Vector3.new(0, 3.5, 0))
	if not okRun then return false, "Yuvaya gidilemedi." end

	task.wait(0.2)

	-- 2. Prompt'u bul
	local stealPrompt = nil
	local smartPart = Workspace:FindFirstChild("SmartPromptPart")
	if smartPart then
		for _, p in ipairs(smartPart:GetChildren()) do
			if p:IsA("ProximityPrompt") and p.Enabled then
				stealPrompt = p; break
			end
		end
	end

	if not stealPrompt then
		for _, p in ipairs(Workspace:GetDescendants()) do
			if p:IsA("ProximityPrompt") and (p.Name == "CarryAreaEgg" or p.ActionText == "Steal") and p.Enabled then
				if (root.Position - p.Parent.Position).Magnitude <= 15 then
					stealPrompt = p; break
				end
			end
		end
	end

	-- Yuva boşsa sıradakine geç
	if not stealPrompt then
		setStatus(("Yuva %d boş, sıradakine geçiliyor..."):format(currentIdx))
		return true
	end

	-- Yumurta var! Al
	setStatus(("Yuva %d dolu! Alınıyor..."):format(currentIdx))
	if typeof(fpp) == "function" then
		fpp(stealPrompt)
		task.wait(CONFIG.StealHoldTime)
	end

	-- 3. Base'e koş
	setStatus("Base'e dönülüyor...")
	runTo(baseCFrame.Position + Vector3.new(0, 1.5, 0))

	-- 4. Base'de teslim beklemesi
	setStatus("Yumurta teslim ediliyor...")
	task.wait(CONFIG.BaseWait)

	return true
end

local function setAutoSteal(on)
	autoToken += 1
	local token = autoToken
	if not on then
		state.autoSteal = false
		setStatus("Auto Steal kapalı.")
		return false
	end
	if baseCFrame == nil then
		state.autoSteal = false
		setStatus("Önce Base'de durup 'Base Konumunu Kaydet'e bas!")
		return false
	end
	state.autoSteal = true
	task.spawn(function()
		while autoToken == token and state.autoSteal do
			pcall(stealCycle)
			task.wait(0.3)
		end
	end)
	return true
end

-- ---------- GUI ----------
local ACCENT = CONFIG.Accent
local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst
end
local function stroke(inst, color, th)
	local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = th; s.Parent = inst
end

screen = Instance.new("ScreenGui")
screen.Name = "AeroGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 999
screen.Parent = guiRoot

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(360, 240)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -120)
mainFrame.BackgroundColor3 = CONFIG.DarkBg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screen
corner(mainFrame, 10)
stroke(mainFrame, ACCENT, 1.5)

-- A Butonu
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(42, 42)
toggleBtn.Position = UDim2.new(0, 15, 0.5, -21)
toggleBtn.BackgroundColor3 = CONFIG.CardBg
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "A"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 20
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Parent = screen
corner(toggleBtn, 21)
stroke(toggleBtn, ACCENT, 1.5)
toggleBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
corner(topBar, 10)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.fromOffset(12, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "AERO STEAL  •  v5.0 Stable"
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 13
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Parent = topBar

-- Sürükleme
local dragging, dragStart, startPos = false, nil, nil
topBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true; dragStart = input.Position; startPos = mainFrame.Position
	end
end)
track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))
track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -74)
content.Position = UDim2.fromOffset(10, 42)
content.BackgroundTransparency = 1
content.Parent = mainFrame
local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = content

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 24)
statusLabel.Position = UDim2.new(0, 10, 1, -28)
statusLabel.BackgroundColor3 = CONFIG.CardBg
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Hazır. Base'de durup 'Base Konumunu Kaydet'e bas."
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame
corner(statusLabel, 6)
local statPad = Instance.new("UIPadding"); statPad.PaddingLeft = UDim.new(0, 8); statPad.Parent = statusLabel

local function makeBtn(text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = CONFIG.CardBg
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(240, 240, 255)
	b.Parent = content
	corner(b, 6)
	stroke(b, ACCENT, 1)
	b.MouseButton1Click:Connect(callback)
	return b
end

makeBtn("1. Base Konumunu Kaydet (Base'de Dur)", function()
	local _, _, root = getCharacter()
	if not root then setStatus("Karakter yok."); return end
	baseCFrame = root.CFrame
	setStatus("Base kaydedildi! Şimdi Auto Steal'i açabilirsin.")
end)

local autoToggleBtn
autoToggleBtn = makeBtn("AUTO STEAL: KAPALI", function()
	local want = not state.autoSteal
	setAutoSteal(want)
	autoToggleBtn.Text = state.autoSteal and "AUTO STEAL: AÇIK ✅" or "AUTO STEAL: KAPALI ❌"
	autoToggleBtn.BackgroundColor3 = state.autoSteal and ACCENT or CONFIG.CardBg
end)

local areaBtn
local areas = { "Forest", "Tümü" }
local aIdx = 1
areaBtn = makeBtn("Bölge: " .. state.selectedArea, function()
	aIdx = (aIdx % #areas) + 1
	state.selectedArea = areas[aIdx]
	areaBtn.Text = "Bölge: " .. state.selectedArea
	nestIndex = 1
	setStatus("Bölge: " .. state.selectedArea)
end)

-- Kapatma
local function unload()
	state.autoSteal = false
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	if screen then screen:Destroy(); screen = nil end
	env.__AeroSteal = nil
end
env.__AeroSteal = unload

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift and screen then
		mainFrame.Visible = not mainFrame.Visible
	end
end))

setStatus("AeroSteal v5.0 Hazır! Base'de durup 1. butona bas.")
