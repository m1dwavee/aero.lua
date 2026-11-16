-- AeroSteal v5.2 : Steal An Egg (Auto Steal & Kod Dökücü Bir Arada)
-- Menü: RightShift veya ekrandaki mor "A" düğmesi

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local fpp = fireproximityprompt

-- ===== AYARLAR =====
local CONFIG = {
	StealHoldTime = 1.35,
	BaseWait = 1.0,
	DefaultSpeed = 50,
	Accent = Color3.fromRGB(130, 95, 255),
	DarkBg = Color3.fromRGB(18, 18, 24),
	CardBg = Color3.fromRGB(26, 26, 36),
	SidebarBg = Color3.fromRGB(14, 14, 20),
	DumpFile = "AeroSteal/OyunKodlari.lua",
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
	speed = CONFIG.DefaultSpeed,
	selectedArea = "Forest",
	activeTab = "AutoSteal",
}
local connections = {}
local baseCFrame = nil
local autoToken = 0
local screen, statusLabel, logLabel, logScroll
local logLines = {}
local nestIndex = 1
local tabContainers = {}
local tabButtons = {}

local function track(conn) connections[#connections + 1] = conn; return conn end

-- ---------- Log & Durum ----------
local function refreshLog()
	if not logLabel then return end
	local parts, total = {}, 0
	for i = #logLines, 1, -1 do
		local l = logLines[i]
		total += #l + 1
		if total > 10000 or #parts >= 150 then break end
		parts[#parts + 1] = l
	end
	local n = #parts
	for i = 1, math.floor(n / 2) do
		parts[i], parts[n - i + 1] = parts[n - i + 1], parts[i]
	end
	logLabel.Text = table.concat(parts, "\n")
	if logScroll then logScroll.CanvasPosition = Vector2.new(0, 1000000) end
end

local function log(text)
	text = tostring(text)
	print("[AeroSteal] " .. text)
	logLines[#logLines + 1] = text
	if #logLines > 800 then
		logLines = table.move(logLines, #logLines - 599, #logLines, 1, {})
	end
	refreshLog()
end

local function setStatus(text)
	log(text)
	if statusLabel then statusLabel.Text = tostring(text) end
end

local function copyText(text)
	local fn = setclipboard or toclipboard
	if typeof(fn) ~= "function" then return false end
	return (pcall(fn, text))
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

-- ---------- AKICI KOŞU (YERE YAKIN, MESAFEYİ KORUR) ----------
local function runTo(targetPos)
	local char, hum, root = getCharacter()
	if not char then return false end

	while state.autoSteal do
		local c, h, r = getCharacter()
		if not c or h.Health <= 0 then return false end

		local diff = targetPos - r.Position
		local dist = diff.Magnitude

		if dist <= 2.5 then break end

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

	-- Yuvaya tam yer seviyesinde koş (+0.5 stud) ki prompt tetiklensin!
	setStatus(("Yuva %d/%d koşuluyor..."):format(currentIdx, #nests))
	local okRun = runTo(currentSpot.Position + Vector3.new(0, 0.5, 0))
	if not okRun then return false, "Yuvaya gidilemedi." end

	task.wait(0.2)

	-- Prompt'u bul ve engelleri aş (Line of Sight engelini kaldır)
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
				if (root.Position - p.Parent.Position).Magnitude <= 18 then
					stealPrompt = p; break
				end
			end
		end
	end

	-- Yuva boşsa hemen sıradakine koş
	if not stealPrompt then
		setStatus(("Yuva %d boş, sıradakine koşuluyor..."):format(currentIdx))
		return true
	end

	-- YUMURTA VAR! Çalma işlemini yap
	setStatus(("Yuva %d DOLU! Alınıyor..."):format(currentIdx))
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.MaxActivationDistance = 50

	if typeof(fpp) == "function" then
		fpp(stealPrompt)
		task.wait(CONFIG.StealHoldTime)
	end

	-- Base'e koş
	setStatus("Base'e dönülüyor...")
	runTo(baseCFrame.Position + Vector3.new(0, 1.0, 0))

	-- Base'de teslim beklemesi
	setStatus("Base'de yumurta teslim ediliyor...")
	task.wait(CONFIG.BaseWait)

	return true
end

local function setAutoSteal(on)
	autoToken += 1
	local token = autoToken
	if not on then
		state.autoSteal = false
		setStatus("Auto Steal durduruldu.")
		return false
	end
	if baseCFrame == nil then
		state.autoSteal = false
		setStatus("HATA: Önce Base'de durup 'Base Konumunu Kaydet'e bas!")
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

-- ==================== ⚡ TÜM OYUN KODLARINI DÖK ====================
local function dumpAllGameScripts()
	setStatus("Tüm oyun kodları taranıyor ve decompile ediliyor, lütfen bekle...")
	task.wait(0.1)

	local output = {}
	local header = string.rep("=", 80)
	table.insert(output, header)
	table.insert(output, ("-- AEROSTEAL TAM OYUN KODLARI DÖKÜMÜ"))
	table.insert(output, header .. "\n")

	local roots = {
		{ name = "ReplicatedStorage", inst = ReplicatedStorage },
		{ name = "PlayerScripts", inst = LocalPlayer:FindFirstChildOfClass("PlayerScripts") },
		{ name = "PlayerGui", inst = LocalPlayer:FindFirstChildOfClass("PlayerGui") },
	}

	local scriptCount = 0
	local decompileFn = decompile or disassemble

	for _, root in ipairs(roots) do
		if root.inst then
			for _, desc in ipairs(root.inst:GetDescendants()) do
				if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
					scriptCount += 1
					if scriptCount > 80 then break end

					table.insert(output, header)
					table.insert(output, ("-- [DOSYA %d]: %s (%s)"):format(scriptCount, desc:GetFullName(), desc.ClassName))
					table.insert(output, header)

					local codeExtracted = false
					if typeof(decompileFn) == "function" then
						local okDec, code = pcall(decompileFn, desc)
						if okDec and type(code) == "string" and #code > 10 then
							table.insert(output, code)
							codeExtracted = true
						end
					end

					if not codeExtracted and desc:IsA("ModuleScript") then
						local okReq, result = pcall(require, desc)
						if okReq then
							local okEnc, json = pcall(function() return HttpService:JSONEncode(result) end)
							table.insert(output, okEnc and ("return " .. json) or "-- (tablo)")
							codeExtracted = true
						end
					end

					if not codeExtracted then
						table.insert(output, "-- [Kod korumalı veya decompile edilemedi]")
					end
					table.insert(output, "\n\n")
				end
			end
		end
	end

	local fullText = table.concat(output, "\n")
	
	-- Dosyaya yaz
	if typeof(writefile) == "function" then
		pcall(function()
			if typeof(makefolder) == "function" and not isfolder("AeroSteal") then makefolder("AeroSteal") end
			writefile(CONFIG.DumpFile, fullText)
		end)
	end

	-- Panoya kopyala
	copyText(fullText)
	setStatus(("Tamamlandı! %d script çıkarıldı. Panona kopyalandı!"):format(scriptCount))
	log("Tüm kodlar panona kopyalandı! Masaüstünde bir metin belgesi açıp Ctrl+V yapabilirsin.")
end

-- ==================== GUI ====================
local ACCENT = CONFIG.Accent
local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst
end
local function stroke(inst, color, th)
	local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = th; s.Parent = inst
end
local function safe(fn)
	return function()
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then setStatus("Hata: " .. tostring(err)) end
		end)
	end
end

screen = Instance.new("ScreenGui")
screen.Name = "AeroGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 999
screen.Parent = guiRoot

-- Dikdörtgen Panel (480x300)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(480, 300)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -150)
mainFrame.BackgroundColor3 = CONFIG.DarkBg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screen
corner(mainFrame, 10)
stroke(mainFrame, ACCENT, 1.5)

-- A Butonu
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(42, 42)
toggleBtn.Position = UDim2.new(0, 15, 0.5, -21)
toggleBtn.BackgroundColor3 = CONFIG.SidebarBg
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
topBar.BackgroundColor3 = CONFIG.SidebarBg
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
corner(topBar, 10)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.fromOffset(12, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "AERO HUB  •  Steal An Egg v5.2 PRO"
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

-- Sol Kenar Menüsü
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -36)
sidebar.Position = UDim2.fromOffset(0, 36)
sidebar.BackgroundColor3 = CONFIG.SidebarBg
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
corner(sidebar, 8)

local sidebarLayout = Instance.new("UIListLayout"); sidebarLayout.Padding = UDim.new(0, 4); sidebarLayout.Parent = sidebar
local sidebarPad = Instance.new("UIPadding"); sidebarPad.PaddingTop = UDim.new(0, 8); sidebarPad.PaddingLeft = UDim.new(0, 6); sidebarPad.PaddingRight = UDim.new(0, 6); sidebarPad.Parent = sidebar

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -140, 1, -70)
contentArea.Position = UDim2.fromOffset(136, 40)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -140, 0, 24)
statusLabel.Position = UDim2.new(0, 136, 1, -28)
statusLabel.BackgroundColor3 = CONFIG.CardBg
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Hazır! Base'de durup 1. butona bas."
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame
corner(statusLabel, 6)
local statPad = Instance.new("UIPadding"); statPad.PaddingLeft = UDim.new(0, 8); statPad.Parent = statusLabel

local function switchTab(tabName)
	state.activeTab = tabName
	for name, container in pairs(tabContainers) do container.Visible = (name == tabName) end
	for name, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (name == tabName) and ACCENT or Color3.fromRGB(24, 24, 34)
		btn.TextColor3 = (name == tabName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 190)
	end
end

local function addTab(name, iconText)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
	btn.BorderSizePixel = 0
	btn.Text = iconText .. " " .. name
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(170, 170, 190)
	btn.Parent = sidebar
	corner(btn, 6)

	local container = Instance.new("ScrollingFrame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 4
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.Visible = false
	container.Parent = contentArea

	local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 6); lay.Parent = container
	local p = Instance.new("UIPadding"); p.PaddingRight = UDim.new(0, 6); p.Parent = container

	tabButtons[name] = btn
	tabContainers[name] = container
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
	return container
end

local function makeBtn(container, text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = CONFIG.CardBg
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(240, 240, 255)
	b.Parent = container
	corner(b, 6)
	stroke(b, ACCENT, 1)
	b.MouseButton1Click:Connect(callback)
	return b
end

-- ==================== SEKMELER ====================

-- 1. SEKME: AUTO STEAL
local tabSteal = addTab("Auto Steal", "🥚")

makeBtn(tabSteal, "1. Base Konumunu Kaydet (Base'de Dur)", function()
	local _, _, root = getCharacter()
	if not root then setStatus("Karakter yok."); return end
	baseCFrame = root.CFrame
	setStatus("Base kaydedildi! Şimdi Auto Steal'i açabilirsin.")
end)

local autoToggleBtn
autoToggleBtn = makeBtn(tabSteal, "AUTO STEAL: KAPALI", function()
	local want = not state.autoSteal
	setAutoSteal(want)
	autoToggleBtn.Text = state.autoSteal and "AUTO STEAL: AÇIK ✅" or "AUTO STEAL: KAPALI ❌"
	autoToggleBtn.BackgroundColor3 = state.autoSteal and ACCENT or CONFIG.CardBg
end)

local areaBtn
local areas = { "Forest", "Tümü" }
local aIdx = 1
areaBtn = makeBtn(tabSteal, "Hedef Bölge: " .. state.selectedArea, function()
	aIdx = (aIdx % #areas) + 1
	state.selectedArea = areas[aIdx]
	areaBtn.Text = "Hedef Bölge: " .. state.selectedArea
	nestIndex = 1
	setStatus("Bölge: " .. state.selectedArea)
end)

-- 2. SEKME: KOD DÖKÜCÜ
local tabDump = addTab("Kod Dökücü", "⚡")
makeBtn(tabDump, "⚡ TÜM OYUN KODLARINI DÖK VE KOPYALA", safe(dumpAllGameScripts))

local dumpInfo = Instance.new("TextLabel")
dumpInfo.Size = UDim2.new(1, 0, 0, 80)
dumpInfo.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
dumpInfo.Text = "Bu butona bastığında oyunun 80-100 adet kaynak kodunu tek seferde decompile eder ve panona kopyalar. Bilgisayarında masaüstüne boş bir metin belgesi açıp Ctrl+V ile yapıştırabilirsin!"
dumpInfo.TextColor3 = Color3.fromRGB(160, 160, 185)
dumpInfo.Font = Enum.Font.Gotham
dumpInfo.TextSize = 11
dumpInfo.TextWrapped = true
dumpInfo.Parent = tabDump
corner(dumpInfo, 6)

-- 3. SEKME: LOGLAR
local tabLog = addTab("Loglar", "📜")
local logBox = Instance.new("Frame")
logBox.Size = UDim2.new(1, 0, 0, 150)
logBox.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
logBox.Parent = tabLog
corner(logBox, 6)

logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -6, 1, -6)
logScroll.Position = UDim2.fromOffset(3, 3)
logScroll.BackgroundTransparency = 1
logScroll.ScrollBarThickness = 4
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = logBox

logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -4, 0, 0)
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.BackgroundTransparency = 1
logLabel.Text = "Loglar burada görünür..."
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
logLabel.Parent = logScroll

makeBtn(tabLog, "Logları Panoya Kopyala", function()
	copyText(table.concat(logLines, "\n"))
	setStatus("Log panoya kopyalandı.")
end)

switchTab("Auto Steal")

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

setStatus("Aero v5.2 Hazır! Base'de durup 1. butona bas.")
