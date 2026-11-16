-- AeroSteal v4.0 : Steal An Egg (Modern Tabbed UI, Anti-Guard & Smooth Runner)
-- Menü: RightShift veya ekrandaki mor "A" düğmesi

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local fpp = fireproximityprompt

-- ===== AYARLAR =====
local CONFIG = {
	RunHeight = 3.5,            -- Yerden süzülme yüksekliği (tuzakları aşmak için)
	StealHoldTime = 1.25,        -- CarryAreaEgg hold süresi
	BaseDepositWait = 0.8,       -- Base'de yumurta teslim süresi
	CycleCooldown = 0.4,
	DefaultSpeed = 70,           -- Koşma hızı
	MinSpeed = 16,
	MaxSpeed = 200,
	PlayerColor = Color3.fromRGB(255, 75, 75),
	EggColor = Color3.fromRGB(255, 215, 0),
	Accent = Color3.fromRGB(130, 95, 255),
	DarkBg = Color3.fromRGB(18, 18, 24),
	CardBg = Color3.fromRGB(26, 26, 36),
	SidebarBg = Color3.fromRGB(14, 14, 20),
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
	playerEsp = false, eggEsp = false, autoSteal = false,
	antiGuard = true, godMode = false,
	speedOn = false, speed = CONFIG.DefaultSpeed,
	selectedArea = "Tümü",
	activeTab = "AutoSteal",
}
local connections = {}
local playerRecords = {}
local eggRecords = {}
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
end

local function setStatus(text)
	log(text)
	if statusLabel then statusLabel.Text = text end
	refreshLog()
end

local function copyText(text)
	local fn = setclipboard or toclipboard
	if typeof(fn) ~= "function" then return false end
	return (pcall(fn, text))
end

-- ---------- Karakter & Noclip ----------
local function isFinite(v) return v == v and v ~= math.huge and v ~= -math.huge end
local function validPosition(p) return isFinite(p.X) and isFinite(p.Y) and isFinite(p.Z) end

local function getCharacter()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if char and hum and hum.Health > 0 and root and root:IsA("BasePart") and validPosition(root.Position) then
		return char, hum, root
	end
	return nil
end

local function noclipChar()
	local char = LocalPlayer.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end
end

-- ---------- 🛡️ ANTİ-GUARD SİSTEMİ (ÖLÜMSÜZLÜK & MUHAFIZ ETKİSİZLEŞTİRME) ----------
local function neutralizeGuards()
	if not state.antiGuard then return end
	local guardAreas = Workspace:FindFirstChild("World")
		and Workspace.World:FindFirstChild("Areas")
		and Workspace.World.Areas:FindFirstChild("GuardAreas")

	if guardAreas then
		for _, desc in ipairs(guardAreas:GetDescendants()) do
			-- Muhafızların Collider, Hitbox ve TouchInterest'lerini kapat
			if desc.Name == "Collider" or desc.Name == "HumanoidMass" or string.find(desc.Name:lower(), "hitbox") then
				if desc:IsA("BasePart") then
					desc.CanTouch = false
					desc.CanCollide = false
					desc.CanQuery = false
				end
			elseif desc:IsA("TouchTransmitter") then
				desc:Destroy()
			elseif desc:IsA("Humanoid") and desc.Parent and string.find(desc.Parent.Name:lower(), "guard") then
				-- Muhafızın saldırmasını engelle
				desc.WalkSpeed = 0
			end
		end
	end

	-- Yerdeki tuzakları da (PlayerTrap) etkisizleştir
	local transient = Workspace:FindFirstChild("Transient")
	if transient then
		for _, trap in ipairs(transient:GetChildren()) do
			if string.find(trap.Name:lower(), "trap") then
				for _, p in ipairs(trap:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanTouch = false
						p.CanCollide = false
					end
				end
			end
		end
	end
end

track(RunService.Stepped:Connect(function()
	if state.autoSteal then noclipChar() end
	if state.antiGuard then neutralizeGuards() end
end))

-- ---------- KESİNTİSİZ AKICI KOŞU MOTORU (IŞINLANMA YOK!) ----------
local function smoothRunTo(targetPos)
	local char, hum, root = getCharacter()
	if not char then return false, "Karakter yok." end

	local speed = math.clamp(state.speed, 20, 200)

	while state.autoSteal do
		local c, h, r = getCharacter()
		if not c or h.Health <= 0 then return false, "Karakter öldü." end

		local currentPos = r.Position
		local diff = targetPos - currentPos
		local dist = diff.Magnitude

		if dist <= 3.5 then
			r.AssemblyLinearVelocity = Vector3.zero
			break
		end

		local step = math.min(dist, speed * 0.03)
		local newPos = currentPos + (diff.Unit * step)

		r.CFrame = CFrame.lookAt(newPos, newPos + diff.Unit)
		r.AssemblyLinearVelocity = Vector3.zero
		noclipChar()

		task.wait(0.03)
	end

	return true, "Varıldı."
end

-- ---------- ESP ----------
local function makeMarker(adornee, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "AeroMarker"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(160, 20)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Text = ""
	label.Parent = gui
	gui.Parent = guiRoot
	return gui, label
end

local function clearPlayer(plr)
	local rec = playerRecords[plr]
	if not rec then return end
	playerRecords[plr] = nil
	if rec.gui then rec.gui:Destroy() end
	if rec.highlight then rec.highlight:Destroy() end
end

local function refreshPlayer(plr)
	clearPlayer(plr)
	if not state.playerEsp or plr == LocalPlayer then return end
	local char = plr.Character
	if not char then return end
	task.spawn(function()
		local root = char:WaitForChild("HumanoidRootPart", 4)
		if not root or not root:IsA("BasePart") or not state.playerEsp or playerRecords[plr] then return end
		local hl = Instance.new("Highlight")
		hl.FillColor = CONFIG.PlayerColor
		hl.FillTransparency = 0.7
		hl.OutlineColor = CONFIG.PlayerColor
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = char
		local gui, label = makeMarker(root, CONFIG.PlayerColor)
		playerRecords[plr] = { gui = gui, label = label, highlight = hl, adornee = root }
	end)
end

local function setPlayerEsp(on)
	state.playerEsp = on
	for _, plr in ipairs(Players:GetPlayers()) do
		if on then refreshPlayer(plr) else clearPlayer(plr) end
	end
end

local function clearEgg(inst)
	local rec = eggRecords[inst]
	if not rec then return end
	eggRecords[inst] = nil
	if rec.gui then rec.gui:Destroy() end
end

local function considerEgg(inst)
	if eggRecords[inst] then return end
	if inst.Name == "EggSpotBottom" or inst.Name == "EggFitBounds" then
		local p = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart")
		if p then
			local gui, label = makeMarker(p, CONFIG.EggColor)
			eggRecords[inst] = { gui = gui, label = label, adornee = p }
			track(inst.Destroying:Connect(function() clearEgg(inst) end))
		end
	end
end

local function setEggEsp(on)
	state.eggEsp = on
	if on then
		for _, inst in ipairs(Workspace:GetDescendants()) do considerEgg(inst) end
	else
		for inst in pairs(eggRecords) do clearEgg(inst) end
	end
end

-- ---------- BÖLGE LİSTESİ ----------
local function getAvailableAreas()
	local areas = { "Tümü", "Forest" }
	local guardAreas = Workspace:FindFirstChild("World")
		and Workspace.World:FindFirstChild("Areas")
		and Workspace.World.Areas:FindFirstChild("GuardAreas")

	if guardAreas then
		for _, child in ipairs(guardAreas:GetChildren()) do
			local exists = false
			for _, a in ipairs(areas) do if a == child.Name then exists = true; break end end
			if not exists then areas[#areas + 1] = child.Name end
		end
	end
	return areas
end

local function getAllNests()
	local nests = {}
	local guardAreas = Workspace:FindFirstChild("World")
		and Workspace.World:FindFirstChild("Areas")
		and Workspace.World.Areas:FindFirstChild("GuardAreas")

	local scanRoot = guardAreas or Workspace
	for _, inst in ipairs(scanRoot:GetDescendants()) do
		if inst.Name == "EggSpotBottom" and inst:IsA("BasePart") then
			local match = true
			if state.selectedArea ~= "Tümü" then
				match = string.find(inst:GetFullName(), state.selectedArea, 1, true) ~= nil
			end
			if match and validPosition(inst.Position) then
				nests[#nests + 1] = { inst = inst, pos = inst.Position }
			end
		end
	end
	return nests
end

-- ---------- ÇALMA DÖNGÜSÜ ----------
local function stealCycle()
	local char, hum, root = getCharacter()
	if not char then return false, "Karakter hazır değil." end

	local nests = getAllNests()
	if #nests == 0 then
		return false, ("'%s' bölgesinde yuva bulunamadı."):format(state.selectedArea)
	end

	if nestIndex > #nests then nestIndex = 1 end
	local currentTarget = nests[nestIndex]
	local targetNumber = nestIndex
	nestIndex = (nestIndex % #nests) + 1

	-- Yerden 3.5 stud yüksekten süzülerek hedefe git
	local targetPos = currentTarget.pos + Vector3.new(0, CONFIG.RunHeight, 0)

	setStatus(("Yuva %d/%d doğru akıcı koşuluyor..."):format(targetNumber, #nests))
	local okRun, whyRun = smoothRunTo(targetPos)
	if not okRun then return false, "Yuvaya ulaşılamadı: " .. whyRun end

	task.wait(0.15)

	-- Prompt'u bul
	local stealPrompt = nil
	local smartPart = Workspace:FindFirstChild("SmartPromptPart")
	if smartPart then
		for _, p in ipairs(smartPart:GetChildren()) do
			if p:IsA("ProximityPrompt") and (p.Name == "CarryAreaEgg" or p.ActionText == "Steal") and p.Enabled then
				stealPrompt = p; break
			end
		end
	end

	if not stealPrompt then
		for _, p in ipairs(Workspace:GetDescendants()) do
			if p:IsA("ProximityPrompt") and (p.Name == "CarryAreaEgg" or p.ActionText == "Steal") and p.Enabled then
				local dist = (root.Position - p.Parent.Position).Magnitude
				if dist <= 20 then
					stealPrompt = p; break
				end
			end
		end
	end

	-- Yuva boşsa anında sıradakine geç
	if not stealPrompt then
		setStatus(("Yuva %d boş çıktı, sıradakine koşuluyor..."):format(targetNumber))
		return true, "Boş yuva atlandı."
	end

	-- Yumurta var! Çalmayı başlat
	setStatus(("Yuva %d DOLU! Yumurta çalınıyor..."):format(targetNumber))
	if typeof(fpp) == "function" then
		fpp(stealPrompt)
		task.wait(CONFIG.StealHoldTime)
	end

	pcall(function()
		local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
		local rf = net and net:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
		if rf then rf:InvokeServer(currentTarget.inst) end
	end)
	task.wait(0.15)

	-- Base'e doğru akıcı koş
	setStatus("Base'e koşuluyor...")
	local okBack, whyBack = smoothRunTo(baseCFrame.Position + Vector3.new(0, 1.5, 0))
	if not okBack then return false, "Base'e dönülemedi: " .. whyBack end

	-- Base teslimatı
	setStatus("Yumurta teslim ediliyor...")
	pcall(function()
		local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
		local rfDrop = net and net:FindFirstChild("RF/EggWorld/AskFieldEggDrop")
		if rfDrop then rfDrop:InvokeServer() end
	end)
	task.wait(CONFIG.BaseDepositWait)

	return true, ("Yumurta getirildi! (Yuva %d)"):format(targetNumber)
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
		setStatus("HATA: Önce base'inde durup 'Base Konumunu Kaydet'e bas!")
		return false
	end
	state.autoSteal = true
	task.spawn(function()
		while autoToken == token and state.autoSteal do
			local ok, success, msg = pcall(stealCycle)
			if autoToken ~= token then break end
			if not ok then
				setStatus("Hata: " .. tostring(success))
			else
				setStatus(msg)
			end
			task.wait(CONFIG.CycleCooldown)
		end
	end)
	return true
end

-- ---------- 🎨 MODERN DİKDÖRTGEN SEKME GUI ----------
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

-- Ana Dikdörtgen Pencere (520x330)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(520, 330)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -165)
mainFrame.BackgroundColor3 = CONFIG.DarkBg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screen
corner(mainFrame, 10)
stroke(mainFrame, ACCENT, 1.5)

-- Ekrandaki Aç/Kapa Düğmesi (A)
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

-- Üst Başlık Çubuğu
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundColor3 = CONFIG.SidebarBg
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
corner(topBar, 10)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.fromOffset(12, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "AERO HUB  •  Steal An Egg v4.0 PRO"
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
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

-- Sol Kenar Çubuğu (Kategoriler)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 135, 1, -38)
sidebar.Position = UDim2.fromOffset(0, 38)
sidebar.BackgroundColor3 = CONFIG.SidebarBg
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
corner(sidebar, 8)

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 4)
sidebarLayout.Parent = sidebar
local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 8); sidebarPad.PaddingLeft = UDim.new(0, 6); sidebarPad.PaddingRight = UDim.new(0, 6)
sidebarPad.Parent = sidebar

-- Sağ İçerik Alanı
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -145, 1, -78)
contentArea.Position = UDim2.fromOffset(140, 44)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

-- Alt Durum Çubuğu
statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -145, 0, 26)
statusLabel.Position = UDim2.new(0, 140, 1, -30)
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

-- Sekme Değiştirme Fonksiyonu
local function switchTab(tabName)
	state.activeTab = tabName
	for name, container in pairs(tabContainers) do
		container.Visible = (name == tabName)
	end
	for name, btn in pairs(tabButtons) do
		if name == tabName then
			btn.BackgroundColor3 = ACCENT
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
			btn.TextColor3 = Color3.fromRGB(170, 170, 190)
		end
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
	local p = Instance.new("UIPadding"); p.PaddingRight = UDim.new(0, 8); p.Parent = container

	tabButtons[name] = btn
	tabContainers[name] = container

	btn.MouseButton1Click:Connect(function() switchTab(name) end)
	return container
end

-- Arayüz Bileşen Üreticileri
local function addCardToggle(container, text, callback, defaultOn)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = CONFIG.CardBg
	row.Parent = container
	corner(row, 6)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -60, 1, 0)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
	lbl.Parent = row

	local pill = Instance.new("TextButton")
	pill.Size = UDim2.fromOffset(40, 20)
	pill.Position = UDim2.new(1, -48, 0.5, -10)
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.Parent = row
	corner(pill, 10)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Position = defaultOn and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = pill
	corner(knob, 7)

	local on = defaultOn or false
	pill.BackgroundColor3 = on and ACCENT or Color3.fromRGB(60, 60, 75)

	pill.MouseButton1Click:Connect(function()
		on = not on
		pill.BackgroundColor3 = on and ACCENT or Color3.fromRGB(60, 60, 75)
		TweenService:Create(knob, TweenInfo.new(0.1), { Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) }):Play()
		callback(on)
	end)
end

local function addCardButton(container, text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = CONFIG.CardBg
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(235, 235, 255)
	b.Parent = container
	corner(b, 6)
	stroke(b, ACCENT, 1)
	b.MouseButton1Click:Connect(callback)
	return b
end

local function addCardTextBox(container, placeholder, onCommit)
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, 0, 0, 32)
	tb.BackgroundColor3 = CONFIG.CardBg
	tb.PlaceholderText = placeholder
	tb.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
	tb.Text = ""
	tb.Font = Enum.Font.Gotham
	tb.TextSize = 12
	tb.TextColor3 = Color3.fromRGB(240, 240, 255)
	tb.Parent = container
	corner(tb, 6)
	local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 10); p.Parent = tb
	tb.FocusLost:Connect(function() onCommit(tb.Text) end)
end

-- ==================== SEKMELERİ OLUŞTUR ====================

-- 1. SEKME: AUTO STEAL
local tabAuto = addTab("Auto Steal", "🥚")
local availableAreas = getAvailableAreas()
local areaIdx = 1
local areaSelectBtn = addCardButton(tabAuto, "Hedef Bölge: " .. state.selectedArea, function()
	availableAreas = getAvailableAreas()
	areaIdx = (areaIdx % #availableAreas) + 1
	state.selectedArea = availableAreas[areaIdx]
	areaSelectBtn.Text = "Hedef Bölge: " .. state.selectedArea
	nestIndex = 1
	setStatus("Bölge seçildi: " .. state.selectedArea)
end)
addCardButton(tabAuto, "Base Konumunu Kaydet (Base'de Dur)", function()
	local _, _, root = getCharacter()
	if not root then setStatus("Karakter yok."); return end
	baseCFrame = root.CFrame
	setStatus("Base kaydedildi! Şimdi Auto Steal'i açabilirsin.")
end)
addCardButton(tabAuto, "Base'e Akıcı Koş", safe(function()
	if baseCFrame == nil then setStatus("Önce base konumunu kaydet."); return end
	smoothRunTo(baseCFrame.Position + Vector3.new(0, 1.5, 0))
end))
addCardToggle(tabAuto, "AUTO STEAL (Akıcı Koş & Çal)", function(on) setAutoSteal(on) end, false)

-- 2. SEKME: ANTİ-GUARD (GÜVENLİK)
local tabGuard = addTab("Anti-Guard", "🛡️")
addCardToggle(tabGuard, "Anti-Guard & Tuzak İptali (Ölümsüzlük)", function(on)
	state.antiGuard = on
	setStatus(on and "Anti-Guard devrede (Muhafızlar etkisiz)." or "Anti-Guard kapatıldı.")
end, true)
addCardButton(tabGuard, "Tüm Muhafızları Şimdi Etkisizleştir", safe(neutralizeGuards))

-- 3. SEKME: HIZ & HAREKET
local tabMove = addTab("Hareket", "⚡")
addCardTextBox(tabMove, ("Koşu Hızı Ayarla (Şu an: %d)"):format(state.speed), function(txt)
	local n = tonumber(txt)
	if n then
		state.speed = math.clamp(n, CONFIG.MinSpeed, CONFIG.MaxSpeed)
		setStatus(("Hız ayarlandı: %d"):format(state.speed))
	end
end)
addCardToggle(tabMove, "Karakter WalkSpeed Hilesi", function(on)
	state.speedOn = on
	local _, hum = getCharacter()
	if hum then hum.WalkSpeed = on and state.speed or 16 end
end, false)

-- 4. SEKME: ESP & GÖRÜNÜM
local tabEsp = addTab("Görünüm", "👁️")
addCardToggle(tabEsp, "Oyuncu ESP", function(on) setPlayerEsp(on) end, false)
addCardToggle(tabEsp, "Yuva ESP", function(on) setEggEsp(on) end, false)

-- 5. SEKME: LOGLAR
local tabLog = addTab("Loglar", "📜")
local logBox = Instance.new("Frame")
logBox.Size = UDim2.new(1, 0, 0, 160)
logBox.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
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
logLabel.Text = ""
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
logLabel.Parent = logScroll

addCardButton(tabLog, "Log'u Panoya Kopyala", function()
	local ok = copyText(table.concat(logLines, "\n"))
	setStatus(ok and "Log panoya kopyalandı." or "Pano fonksiyonu yok.")
end)

-- Varsayılan Sekmeyi Aç
switchTab("Auto Steal")

-- Kapatma Fonksiyonu
local function unload()
	autoToken += 1
	state.autoSteal = false
	setEggEsp(false)
	setPlayerEsp(false)
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	if screen then screen:Destroy(); screen = nil end
	env.__AeroSteal = nil
	print("[AeroSteal] Kapatıldı.")
end
env.__AeroSteal = unload

-- Kısayollar
track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift and screen then
		mainFrame.Visible = not mainFrame.Visible
	end
end))

setStatus("AERO v4.0 Yüklendi! Base'de durup 'Base Konumunu Kaydet'e bas.")
