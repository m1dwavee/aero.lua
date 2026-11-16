-- AeroSteal v2.1 : Steal An Egg helper (Luau, executor ortamı)
-- RightShift veya ekrandaki "A" düğmesi: pencereyi gizle/göster

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local fpp = fireproximityprompt -- executor fonksiyonu, yoksa nil

-- ===== CONFIG: nil = unset (bilinmiyor). Doğrulanmadan doldurma. =====
local CONFIG = {
	ExpectedPlaceId = nil,       -- unset
	EggKeywords = { "egg" },     -- tahmin: dökümden doğrula
	NestKeywords = { "nest" },   -- tahmin
	MaxScan = 60000,
	MaxEggMarkers = 150,
	MaxDumpLines = 300,
	UpdateInterval = 0.1,
	RequirePrompt = true,        -- tahmin: çalma ProximityPrompt ile
	TeleportYOffset = 3,
	TeleportSettle = 0.25,
	StealTimeout = 3,
	CycleCooldown = 1.5,
	PlayerColor = Color3.fromRGB(255, 70, 70),
	EggColor = Color3.fromRGB(255, 220, 80),
	Accent = Color3.fromRGB(120, 90, 255),
}
-- =====================================================================

-- Eski kopya varsa kapat, hata sonrası kalan kilit varsa yoksay
local env = (getgenv and getgenv()) or _G
local previous = env.__AeroSteal
if type(previous) == "function" then pcall(previous) end
env.__AeroSteal = true

print(("[AeroSteal] PlaceId=%d GameId=%d"):format(game.PlaceId, game.GameId))
if CONFIG.ExpectedPlaceId ~= nil and game.PlaceId ~= CONFIG.ExpectedPlaceId then
	warn("[AeroSteal] PlaceId beklenenden farklı, çıkılıyor.")
	env.__AeroSteal = nil
	return
end

local function getGuiRoot()
	local ok, ui = pcall(function() return gethui and gethui() or nil end)
	if ok and ui then return ui end
	local okCore = pcall(function() return game:GetService("CoreGui"):GetChildren() end)
	if okCore then return game:GetService("CoreGui") end
	return LocalPlayer:WaitForChild("PlayerGui")
end
local guiRoot = getGuiRoot()

local state = { playerEsp = false, eggEsp = false, autoSteal = false, priority = {} }
local connections = {}
local playerRecords = {}
local eggRecords = {}
local eggCount = 0
local baseCFrame = nil
local autoToken = 0
local screen, statusLabel

local function track(conn) connections[#connections + 1] = conn; return conn end

local function setStatus(text)
	print("[AeroSteal] " .. text)
	if statusLabel then statusLabel.Text = text end
end

-- ---------- saf yardımcılar ----------
local function nameMatches(name, keywords)
	local lower = string.lower(name)
	for _, k in ipairs(keywords) do
		if string.find(lower, k, 1, true) then return true end
	end
	return false
end

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

local function adorneeFor(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function findPrompt(inst)
	if inst:IsA("ProximityPrompt") then return inst end
	return inst:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function insideAnyCharacter(inst)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character and inst:IsDescendantOf(plr.Character) then return true end
	end
	return false
end

local function parsePriority(text)
	local list = {}
	for token in string.gmatch(text, "[^,]+") do
		local t = string.lower(string.match(token, "^%s*(.-)%s*$"))
		if #t > 0 then list[#list + 1] = t end
	end
	return list
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
	label.TextSize = 14
	label.Text = ""
	label.Parent = gui
	gui.Parent = guiRoot
	return gui, label
end

-- ---------- oyuncu ESP ----------
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
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if not root or not root:IsA("BasePart") then return end
		if plr.Character ~= char or not state.playerEsp or playerRecords[plr] then return end
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

local function hookPlayer(plr)
	if plr == LocalPlayer then return end
	track(plr.CharacterAdded:Connect(function() refreshPlayer(plr) end))
	track(plr.CharacterRemoving:Connect(function() clearPlayer(plr) end))
	refreshPlayer(plr)
end

local function setPlayerEsp(on)
	state.playerEsp = on
	for _, plr in ipairs(Players:GetPlayers()) do
		if on then refreshPlayer(plr) else clearPlayer(plr) end
	end
end

-- ---------- egg/nest ESP (isim tahminine dayalı) ----------
local function clearEgg(inst)
	local rec = eggRecords[inst]
	if not rec then return end
	eggRecords[inst] = nil
	eggCount -= 1
	if rec.gui then rec.gui:Destroy() end
end

local function considerEgg(inst)
	if eggRecords[inst] or eggCount >= CONFIG.MaxEggMarkers then return end
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
	if not (nameMatches(inst.Name, CONFIG.EggKeywords) or nameMatches(inst.Name, CONFIG.NestKeywords)) then return end
	if insideAnyCharacter(inst) then return end
	local adornee = adorneeFor(inst)
	if not adornee then return end
	local gui, label = makeMarker(adornee, CONFIG.EggColor)
	eggRecords[inst] = { gui = gui, label = label, adornee = adornee }
	eggCount += 1
	track(inst.Destroying:Connect(function() clearEgg(inst) end))
end

local eggDescConn
local function setEggEsp(on)
	state.eggEsp = on
	if on then
		local scanned = 0
		for _, inst in ipairs(Workspace:GetDescendants()) do
			scanned += 1
			if scanned > CONFIG.MaxScan then warn("[AeroSteal] MaxScan aşıldı."); break end
			considerEgg(inst)
		end
		eggDescConn = Workspace.DescendantAdded:Connect(function(inst)
			if state.eggEsp then considerEgg(inst) end
		end)
	else
		if eggDescConn then eggDescConn:Disconnect(); eggDescConn = nil end
		for inst in pairs(eggRecords) do clearEgg(inst) end
	end
end

-- ---------- keşif dökümü ----------
local function dump()
	print("========== AeroSteal DISCOVERY ==========")
	print(("PlaceId=%d GameId=%d"):format(game.PlaceId, game.GameId))
	local lines, scanned = 0, 0
	print("-- Workspace adayları (egg/nest) --")
	for _, inst in ipairs(Workspace:GetDescendants()) do
		scanned += 1
		if scanned > CONFIG.MaxScan or lines >= CONFIG.MaxDumpLines then break end
		if nameMatches(inst.Name, CONFIG.EggKeywords) or nameMatches(inst.Name, CONFIG.NestKeywords) then
			print(("[%s] %s"):format(inst.ClassName, inst:GetFullName()))
			lines += 1
		end
	end
	print("-- ReplicatedStorage remote'ları --")
	lines = 0
	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		if lines >= CONFIG.MaxDumpLines then break end
		if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
			print(("[%s] %s"):format(inst.ClassName, inst:GetFullName()))
			lines += 1
		end
	end
	print("========== END ==========")
	setStatus("Döküm konsola yazıldı.")
end

-- ---------- otomatik çalma ----------
local function pickTarget(myPos)
	local best, bestRank, bestDist
	local scanned = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		scanned += 1
		if scanned > CONFIG.MaxScan then break end
		if (inst:IsA("Model") or inst:IsA("BasePart"))
			and (nameMatches(inst.Name, CONFIG.EggKeywords) or nameMatches(inst.Name, CONFIG.NestKeywords))
			and not insideAnyCharacter(inst) then
			local prompt = findPrompt(inst)
			local adornee = adorneeFor(inst)
			if adornee and validPosition(adornee.Position)
				and (prompt ~= nil or not CONFIG.RequirePrompt)
				and (prompt == nil or prompt.Enabled) then
				local rank = math.huge
				local lower = string.lower(inst.Name)
				for i, k in ipairs(state.priority) do
					if string.find(lower, k, 1, true) then rank = i; break end
				end
				local dist = (adornee.Position - myPos).Magnitude
				if best == nil or rank < bestRank or (rank == bestRank and dist < bestDist) then
					best = { inst = inst, adornee = adornee, prompt = prompt, rank = rank, dist = dist }
					bestRank, bestDist = rank, dist
				end
			end
		end
	end
	return best
end

local function previewTarget()
	local _, _, root = getCharacter()
	if not root then setStatus("Karakter yok veya ölü."); return end
	local t = pickTarget(root.Position)
	if not t then setStatus("Uygun hedef bulunamadı."); return end
	local rankText = (t.rank == math.huge) and "listede yok" or ("öncelik " .. t.rank)
	setStatus(("Hedef: %s | %s | %dm"):format(t.inst.Name, rankText, math.floor(t.dist)))
end

local function stealCycle()
	local char, _, root = getCharacter()
	if not char then return false, "Karakter yok veya ölü." end
	local target = pickTarget(root.Position)
	if not target then return false, "Uygun egg bulunamadı." end
	if not target.prompt then return false, "Hedefte ProximityPrompt yok." end

	char:PivotTo(CFrame.new(target.adornee.Position + Vector3.new(0, CONFIG.TeleportYOffset, 0)))
	task.wait(CONFIG.TeleportSettle)
	if not target.inst:IsDescendantOf(Workspace) or not target.prompt.Parent then
		return false, "Hedef kayboldu."
	end

	local confirmed = false
	local c1 = char.ChildAdded:Connect(function(ch) if ch:IsA("Tool") then confirmed = true end end)
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local c2 = backpack and backpack.ChildAdded:Connect(function(ch) if ch:IsA("Tool") then confirmed = true end end)

	fpp(target.prompt)
	local t0 = os.clock()
	while os.clock() - t0 < CONFIG.StealTimeout and not confirmed do
		if not target.inst:IsDescendantOf(Workspace) then confirmed = true; break end
		task.wait(0.05)
	end
	c1:Disconnect()
	if c2 then c2:Disconnect() end

	local char2 = getCharacter()
	if char2 and baseCFrame then char2:PivotTo(baseCFrame) end
	return true, ("%s: %s"):format(target.inst.Name, confirmed and "alındı sinyali var, base'e dönüldü" or "ateşlendi, doğrulanamadı, base'e dönüldü")
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
		setStatus("Önce 'Base konumunu kaydet' düğmesine bas.")
		return false
	end
	if typeof(fpp) ~= "function" then
		state.autoSteal = false
		setStatus("Bu executor'da fireproximityprompt yok.")
		return false
	end
	state.autoSteal = true
	task.spawn(function()
		while autoToken == token and state.autoSteal do
			local ok, success, msg = pcall(stealCycle)
			if autoToken ~= token then break end
			if not ok then setStatus("Hata: " .. tostring(success))
			else setStatus(msg) end
			task.wait(CONFIG.CycleCooldown)
		end
	end)
	return true
end

-- ---------- güncelleme döngüsü ----------
local acc = 0
track(RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < CONFIG.UpdateInterval then return end
	acc = 0
	local _, _, root = getCharacter()
	local me = root and root.Position
	for plr, rec in pairs(playerRecords) do
		if rec.adornee.Parent and me and validPosition(rec.adornee.Position) then
			rec.label.Text = ("%s [%dm]"):format(plr.DisplayName, math.floor((rec.adornee.Position - me).Magnitude))
		end
	end
	for inst, rec in pairs(eggRecords) do
		if not rec.adornee.Parent then
			clearEgg(inst)
		elseif me and validPosition(rec.adornee.Position) then
			rec.label.Text = ("%s [%dm]"):format(inst.Name, math.floor((rec.adornee.Position - me).Magnitude))
		end
	end
end))

-- ---------- kapanış (tek yol) ----------
local function unload()
	autoToken += 1
	state.autoSteal = false
	setEggEsp(false)
	setPlayerEsp(false)
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	statusLabel = nil
	if screen then screen:Destroy(); screen = nil end
	env.__AeroSteal = nil
	print("[AeroSteal] kapatıldı.")
end
env.__AeroSteal = unload

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

local window = Instance.new("Frame")
window.Size = UDim2.new(0, 340, 0.85, 0)
window.Position = UDim2.new(0.5, -170, 0.075, 0)
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
title.Active = true
title.Text = "  AERO  •  Steal An Egg"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = window
corner(title, 12)

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(0, 120, 1, 0)
hint.Position = UDim2.new(1, -130, 0, 0)
hint.Text = "RightShift / A"
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(150, 150, 175)
hint.Parent = title

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
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = window
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12); pad.PaddingTop = UDim.new(0, 4)
pad.Parent = content

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 30)
statusLabel.Position = UDim2.new(0, 8, 1, -34)
statusLabel.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Hazır."
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
	row.BorderSizePixel = 0
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
	pill.BorderSizePixel = 0
	pill.Parent = row
	corner(pill, 11)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
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
	b.BorderSizePixel = 0
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(235, 235, 255)
	b.Parent = content
	corner(b, 8)
	stroke(b, ACCENT, 1)
	b.MouseButton1Click:Connect(callback)
end

local function addTextBox(placeholder, onCommit)
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, 0, 0, 34)
	tb.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	tb.BorderSizePixel = 0
	tb.PlaceholderText = placeholder
	tb.PlaceholderColor3 = Color3.fromRGB(120, 120, 145)
	tb.Text = ""
	tb.ClearTextOnFocus = false
	tb.Font = Enum.Font.Gotham
	tb.TextSize = 13
	tb.TextColor3 = Color3.fromRGB(235, 235, 245)
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.Parent = content
	corner(tb, 8)
	local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 10); p.Parent = tb
	tb.FocusLost:Connect(function() onCommit(tb.Text) end)
end

addHeader("GÖRÜNÜM")
addToggle("Oyuncu ESP", function(on) setPlayerEsp(on) end)
addToggle("Egg / Nest ESP", function(on) setEggEsp(on) end)

addHeader("OTOMATİK ÇALMA")
addButton("Base konumunu kaydet (base'de dur)", function()
	local _, _, root = getCharacter()
	if not root then setStatus("Karakter yok veya ölü."); return end
	baseCFrame = root.CFrame
	setStatus("Base konumu kaydedildi.")
end)
addTextBox("Öncelik: en iyiden en kötüye, virgülle", function(text)
	state.priority = parsePriority(text)
	setStatus(("Öncelik listesi: %d kayıt."):format(#state.priority))
end)
addButton("Hedefi önizle (ışınlanmaz)", previewTarget)
addToggle("Auto Steal (en iyi egg → base)", function(on) return setAutoSteal(on) end)

addHeader("ARAÇLAR")
addButton("Keşif dökümü (konsola yazar)", dump)
addButton("Kapat (unload)", unload)

track(Players.PlayerAdded:Connect(hookPlayer))
track(Players.PlayerRemoving:Connect(clearPlayer))
for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift and screen then
		window.Visible = not window.Visible
	end
end))

setStatus("Hazır. Önce base'i kaydet, sonra dökümü al.")
