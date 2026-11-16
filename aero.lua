-- AeroSteal v3.2 : Steal An Egg (Canlı Yumurta Takip Sistemi)
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
	TeleportYOffset = 2.5,
	TeleportVerifyDelay = 0.25,
	TeleportTolerance = 6,
	StealHoldTime = 1.3,        -- 1.2s basılı tutma süresi
	CycleCooldown = 1.2,
	DefaultSpeed = 32,
	MinSpeed = 1,
	MaxSpeed = 200,
	PlayerColor = Color3.fromRGB(255, 70, 70),
	EggColor = Color3.fromRGB(255, 220, 80),
	Accent = Color3.fromRGB(120, 90, 255),
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
	speedOn = false, speed = CONFIG.DefaultSpeed,
	selectedArea = "Tümü",
}
local connections = {}
local playerRecords = {}
local eggRecords = {}
local baseCFrame = nil
local autoToken = 0
local screen, statusLabel, logLabel, logScroll, areaBtn
local logLines = {}

local function track(conn) connections[#connections + 1] = conn; return conn end

-- ---------- Log & Durum ----------
local function refreshLog()
	if not logLabel then return end
	local parts, total = {}, 0
	for i = #logLines, 1, -1 do
		local l = logLines[i]
		total += #l + 1
		if total > 12000 or #parts >= 200 then break end
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
	if #logLines > 1000 then
		logLines = table.move(logLines, #logLines - 799, #logLines, 1, {})
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

-- ---------- Yardımcılar ----------
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

local function makeMarker(adornee, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "AeroMarker"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(190, 22)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.Text = ""
	label.Parent = gui
	gui.Parent = guiRoot
	return gui, label
end

-- ---------- Işınlanma ----------
local function teleportTo(cf)
	if not validPosition(cf.Position) then return false, "Geçersiz hedef." end
	local char, _, root = getCharacter()
	if not char then return false, "Karakter yok." end

	char:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	task.wait(CONFIG.TeleportVerifyDelay)

	local d = (root.Position - cf.Position).Magnitude
	if d <= CONFIG.TeleportTolerance then return true, "ok" end

	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(CONFIG.TeleportVerifyDelay)
	d = (root.Position - cf.Position).Magnitude
	if d <= CONFIG.TeleportTolerance then return true, "ok (2. deneme)" end

	return false, ("Uzakta kalındı: %dm"):format(math.floor(d))
end

-- ---------- Hız Ayarı ----------
local speedHum, speedOriginal
local function applySpeed()
	local _, hum = getCharacter()
	if not hum then return end
	if hum ~= speedHum then
		speedHum = hum
		speedOriginal = hum.WalkSpeed
	end
	if hum.WalkSpeed ~= state.speed then hum.WalkSpeed = state.speed end
end

local function restoreSpeed()
	if speedHum and speedHum.Parent and speedOriginal then
		speedHum.WalkSpeed = speedOriginal
	end
	speedHum, speedOriginal = nil, nil
end

local function setSpeedOn(on)
	state.speedOn = on
	if on then
		applySpeed()
		setStatus(("Hız açık: %g"):format(state.speed))
	else
		restoreSpeed()
		setStatus("Hız kapalı.")
	end
end

-- ---------- ESP ----------
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
		hl.FillTransparency = 0.75
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
	local clientSlots = Workspace:FindFirstChild("AreaEggSlotsClient")
	if clientSlots and inst:IsDescendantOf(clientSlots) and inst:IsA("BasePart") then
		local gui, label = makeMarker(inst, CONFIG.EggColor)
		eggRecords[inst] = { gui = gui, label = label, adornee = inst }
		track(inst.Destroying:Connect(function() clearEgg(inst) end))
	end
end

local function setEggEsp(on)
	state.eggEsp = on
	if on then
		local clientSlots = Workspace:FindFirstChild("AreaEggSlotsClient")
		if clientSlots then
			for _, inst in ipairs(clientSlots:GetDescendants()) do
				if inst:IsA("BasePart") then considerEgg(inst) end
			end
		end
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
			if child:IsA("Folder") or child:IsA("Model") then
				local exists = false
				for _, a in ipairs(areas) do if a == child.Name then exists = true; break end end
				if not exists then areas[#areas + 1] = child.Name end
			end
		end
	end
	return areas
end

-- ---------- SADECE GERÇEKTEN VAR OLAN CANLI YUMURTALARI BUL ----------
local function findLiveEggs(myPos)
	local list = {}
	local clientSlots = Workspace:FindFirstChild("AreaEggSlotsClient")

	if clientSlots then
		for _, slot in ipairs(clientSlots:GetChildren()) do
			-- Bölge kontrolü (Örn: isimde 'Forest' geçiyor mu?)
			local matchArea = true
			if state.selectedArea ~= "Tümü" then
				matchArea = string.find(string.lower(slot.Name), string.lower(state.selectedArea), 1, true) ~= nil
			end

			if matchArea then
				-- Modelin veya Part'ın koordinatını bul
				local part = slot:IsA("BasePart") and slot or slot:FindFirstChildWhichIsA("BasePart", true)
				local pos = part and part.Position or (slot:IsA("Model") and slot:GetPivot().Position)

				if pos and validPosition(pos) then
					local d = (pos - myPos).Magnitude
					list[#list + 1] = { slot = slot, inst = part or slot, pos = pos, dist = d }
				end
			end
		end
	end

	-- Yakından uzağa sırala
	table.sort(list, function(a, b) return a.dist < b.dist end)
	return list
end

-- ---------- ÇALMA DÖNGÜSÜ ----------
local function stealCycle()
	local char, _, root = getCharacter()
	if not char then return false, "Karakter hazır değil." end

	-- Sadece gerçekten spawn olmuş canlı yumurtaları çek
	local liveEggs = findLiveEggs(root.Position)
	if #liveEggs == 0 then
		return false, ("'%s' bölgesinde şu an yumurta yok, bekleniyor..."):format(state.selectedArea)
	end

	local target = liveEggs[1]
	local targetCF = CFrame.new(target.pos + Vector3.new(0, CONFIG.TeleportYOffset, 0))

	-- 1. Canlı yumurtanın üstüne ışınlan
	local okTp, whyTp = teleportTo(targetCF)
	if not okTp then return false, "Yumurtaya ışınlanılamadı: " .. whyTp end
	task.wait(0.25)

	-- 2. Yakındaki Steal / Carry prompt'unu bul
	local stealPrompt = nil
	local smartPart = Workspace:FindFirstChild("SmartPromptPart")
	if smartPart then
		for _, p in ipairs(smartPart:GetChildren()) do
			if p:IsA("ProximityPrompt") and (p.Name == "CarryAreaEgg" or p.ActionText == "Steal") then
				stealPrompt = p; break
			end
		end
	end

	if not stealPrompt then
		for _, p in ipairs(Workspace:GetDescendants()) do
			if p:IsA("ProximityPrompt") and (p.Name == "CarryAreaEgg" or p.ActionText == "Steal") then
				stealPrompt = p; break
			end
		end
	end

	-- 3. Çalma işlemini yap (Hem Prompt hem Remote)
	if stealPrompt and typeof(fpp) == "function" then
		setStatus("Yumurta çalınıyor (1.2s basılı tutuluyor)...")
		fpp(stealPrompt)
		task.wait(CONFIG.StealHoldTime)
	else
		-- Alternatif remote
		pcall(function()
			local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
			local rf = net and net:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
			if rf then rf:InvokeServer(target.slot) end
		end)
		task.wait(0.5)
	end

	-- 4. Kendi Base'ine dön
	local okBack, whyBack = teleportTo(baseCFrame)
	if not okBack then return false, "Base'e dönülemedi: " .. whyBack end

	-- 5. Base'e yumurtayı teslim et
	setStatus("Base'de yumurta teslim ediliyor...")
	pcall(function()
		local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
		local rfDrop = net and net:FindFirstChild("RF/EggWorld/AskFieldEggDrop")
		if rfDrop then rfDrop:InvokeServer() end
	end)
	task.wait(1.0)

	return true, "Yumurta çalındı ve teslim edildi!"
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

-- ---------- GUI ----------
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

local window = Instance.new("Frame")
window.Size = UDim2.new(0, 330, 0.78, 0)
window.Position = UDim2.new(0.5, -165, 0.1, 0)
window.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
window.BorderSizePixel = 0
window.Parent = screen
corner(window, 12)
stroke(window, ACCENT, 1.5)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(44, 44)
toggleBtn.Position = UDim2.new(0, 12, 0.5, -22)
toggleBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "A"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 20
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Parent = screen
corner(toggleBtn, 22)
stroke(toggleBtn, ACCENT, 1.5)
toggleBtn.MouseButton1Click:Connect(function() window.Visible = not window.Visible end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
title.BorderSizePixel = 0
title.Text = "  AERO  •  Steal An Egg v3.2"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = window
corner(title, 12)

local dragging, dragStart, startPos = false, nil, nil
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true; dragStart = input.Position; startPos = window.Position
	end
end)
track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))
track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(0, 48)
content.Size = UDim2.new(1, 0, 1, -84)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 4
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = window
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = content
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12); pad.PaddingTop = UDim.new(0, 4)
pad.Parent = content

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 30)
statusLabel.Position = UDim2.new(0, 8, 1, -34)
statusLabel.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Hazır. Base'de durup 'Base Konumunu Kaydet'e bas."
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextColor3 = Color3.fromRGB(190, 190, 215)
statusLabel.Parent = window
corner(statusLabel, 8)

local function addHeader(text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 20)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamBold
	l.TextSize = 12
	l.TextColor3 = ACCENT
	l.Parent = content
end

local function addToggle(text, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	row.Parent = content
	corner(row, 8)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
	lbl.Parent = row
	local pill = Instance.new("TextButton")
	pill.Size = UDim2.fromOffset(44, 22)
	pill.Position = UDim2.new(1, -56, 0.5, -11)
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.Parent = row
	corner(pill, 11)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = pill
	corner(knob, 8)
	local on = false
	local function render()
		pill.BackgroundColor3 = on and ACCENT or Color3.fromRGB(70, 70, 90)
		TweenService:Create(knob, TweenInfo.new(0.12), { Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) }):Play()
	end
	pill.MouseButton1Click:Connect(function()
		local want = not on
		local result = callback(want)
		if result ~= nil then want = result end
		on = want
		render()
	end)
	render()
end

local function addButton(text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(40, 36, 70)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(235, 235, 255)
	b.Parent = content
	corner(b, 8)
	stroke(b, ACCENT, 1)
	b.MouseButton1Click:Connect(callback)
	return b
end

-- Butonlar
addHeader("BÖLGE SEÇİMİ")
local availableAreas = getAvailableAreas()
local areaIndex = 1
areaBtn = addButton("Hedef Bölge: " .. state.selectedArea, function()
	availableAreas = getAvailableAreas()
	areaIndex = (areaIndex % #availableAreas) + 1
	state.selectedArea = availableAreas[areaIndex]
	areaBtn.Text = "Hedef Bölge: " .. state.selectedArea
	setStatus("Seçilen bölge: " .. state.selectedArea)
end)

addHeader("AUTO STEAL")
addButton("1. Base Konumunu Kaydet (Base'de Dur)", function()
	local _, _, root = getCharacter()
	if not root then setStatus("Karakter yok."); return end
	baseCFrame = root.CFrame
	setStatus("Base kaydedildi! Şimdi Auto Steal'i açabilirsin.")
end)
addButton("Base'e Işınlan", safe(function()
	if baseCFrame == nil then setStatus("Önce base konumunu kaydet."); return end
	local ok, why = teleportTo(baseCFrame)
	setStatus(ok and "Base'e ışınlandın." or ("Hata: " .. why))
end))
addToggle("AUTO STEAL (Sadece Dolu Yuvalara Git)", function(on) return setAutoSteal(on) end)

addHeader("GÖRÜNÜM & HIZ")
addToggle("Oyuncu ESP", function(on) setPlayerEsp(on) end)
addToggle("Canlı Yumurta ESP", function(on) setEggEsp(on) end)
addToggle("Hız Ayarı (32)", function(on) setSpeedOn(on) end)

addHeader("LOG")
local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(1, 0, 0, 140)
logFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
logFrame.Parent = content
corner(logFrame, 8)
logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -8, 1, -8)
logScroll.Position = UDim2.fromOffset(4, 4)
logScroll.BackgroundTransparency = 1
logScroll.ScrollBarThickness = 4
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = logFrame
logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -6, 0, 0)
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.BackgroundTransparency = 1
logLabel.Text = ""
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(190, 220, 190)
logLabel.Parent = logScroll

addButton("Log'u Kopyala", function()
	local ok = copyText(table.concat(logLines, "\n"))
	setStatus(ok and "Log panoya kopyalandı." or "Pano yok.")
end)

local function unload()
	autoToken += 1
	state.autoSteal = false
	state.speedOn = false
	restoreSpeed()
	setEggEsp(false)
	setPlayerEsp(false)
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	if screen then screen:Destroy(); screen = nil end
	env.__AeroSteal = nil
	print("[AeroSteal] Kapatıldı.")
end
env.__AeroSteal = unload

addButton("Kapat (Unload)", unload)

track(RunService.Heartbeat:Connect(function()
	if state.speedOn then applySpeed() end
end))

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift and screen then
		window.Visible = not window.Visible
	end
end))

setStatus("Hazır. Base'de durup 'Base Konumunu Kaydet'e bas.")
