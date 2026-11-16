-- AeroSteal v4.1 : Steal An Egg (Derin Röntgen & Remote Spy)
-- Menü: RightShift veya ekrandaki mor "A" düğmesi

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local fpp = fireproximityprompt

-- ===== AYARLAR =====
local CONFIG = {
	RunHeight = 3.5,
	DefaultSpeed = 70,
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
	antiGuard = true, remoteSpy = true,
	speed = CONFIG.DefaultSpeed,
	selectedArea = "Tümü",
	activeTab = "RemoteSpy",
}
local connections = {}
local playerRecords = {}
local eggRecords = {}
local baseCFrame = nil
local screen, statusLabel, logLabel, logScroll
local logLines = {}
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
		if total > 14000 or #parts >= 200 then break end
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
	refreshLog()
end

local function setStatus(text)
	log(text)
	if statusLabel then statusLabel.Text = text end
end

local function copyText(text)
	local fn = setclipboard or toclipboard
	if typeof(fn) ~= "function" then return false end
	return (pcall(fn, text))
end

-- Serileştirici
local function enc(val)
	if typeof(val) == "Instance" then
		return val:GetFullName()
	elseif type(val) == "table" then
		local ok, s = pcall(function() return HttpService:JSONEncode(val) end)
		return ok and s or "tablo"
	end
	return tostring(val)
end

-- ---------- 🕵️ REMOTE SPY (AĞ DİNLEYİCİSİ - ELİNLE ÇALDIĞINDA YAKALAR) ----------
local hookActive = false
local function initRemoteSpy()
	if hookActive then return end
	local ok, err = pcall(function()
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			local args = { ... }

			if state.remoteSpy and (method == "FireServer" or method == "InvokeServer") then
				local remoteName = self.Name:lower()
				local fullPath = self:GetFullName()

				-- Yumurta, çalma, taşıma veya alan ile ilgili tüm paketleri yakala
				if string.find(remoteName, "egg") or string.find(remoteName, "carry") or string.find(remoteName, "steal")
					or string.find(remoteName, "drop") or string.find(remoteName, "field") or string.find(fullPath:lower(), "eggworld") then
					
					local argStr = {}
					for i, a in ipairs(args) do
						argStr[#argStr + 1] = ("arg%d: %s"):format(i, enc(a))
					end
					log(("[SPY YAKALADI!] %s -> %s\n  Parametreler: %s"):format(method, fullPath, table.concat(argStr, " | ")))
					copyText(("[SPY YAKALADI!] %s -> %s\n  Parametreler: %s"):format(method, fullPath, table.concat(argStr, " | ")))
				end
			end
			return oldNamecall(self, ...)
		end)
	end)
	if ok then
		hookActive = true
		log("[Remote Spy] Aktif! Şimdi elinle gidip 1 tane yumurta çal, paket anında buraya düşecek.")
	else
		log("[Remote Spy] Hook açılamadı: " .. tostring(err))
	end
end

-- ---------- 🔍 DERİN ÇEVRE RÖNTGENİ (YANINDA DURDUĞUN YERİ İNCELER) ----------
local function deepInspectNear()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then setStatus("Karakter yok."); return end

	log("========== DERİN ÇEVRE RÖNTGENİ ==========")
	log(("Oyuncu Konumu: (%.1f, %.1f, %.1f)"):format(root.Position.X, root.Position.Y, root.Position.Z))

	-- 1. Yakındaki (25 stud) tüm ProximityPrompt'lar
	log("-- YAKINDAKİ PROMPT'LAR --")
	local promptCount = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") then
			local pPos = inst.Parent and (inst.Parent:IsA("BasePart") and inst.Parent.Position or (inst.Parent:IsA("Model") and inst.Parent:GetPivot().Position))
			if pPos then
				local dist = (root.Position - pPos).Magnitude
				if dist <= 25 then
					promptCount += 1
					log(("Prompt: %s | Action=%q Object=%q Enabled=%s Hold=%.2f Mesafe=%.1fm"):format(
						inst:GetFullName(), inst.ActionText, inst.ObjectText, tostring(inst.Enabled), inst.HoldDuration, dist
					))
				end
			end
		end
	end
	if promptCount == 0 then log("25 stud içinde hiç ProximityPrompt yok.") end

	-- 2. Yakındaki Modeller ve Attribute'lar
	log("-- YAKINDAKİ NESNELER (15 stud) --")
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if (inst:IsA("Model") or inst:IsA("BasePart")) and not inst:IsDescendantOf(char) then
			local pPos = inst:IsA("BasePart") and inst.Position or (inst:IsA("Model") and inst:GetPivot().Position)
			if pPos and (root.Position - pPos).Magnitude <= 15 then
				local attrs = inst:GetAttributes()
				local attrStr = ""
				for k, v in pairs(attrs) do attrStr = attrStr .. tostring(k) .. "=" .. tostring(v) .. "; " end
				if attrStr ~= "" or string.find(inst.Name:lower(), "egg") or string.find(inst.Name:lower(), "spot") then
					log(("[%s] %s | Attr: %s"):format(inst.ClassName, inst:GetFullName(), attrStr ~= "" and attrStr or "yok"))
				end
			end
		end
	end

	-- 3. Oyuncunun elindeki / çantasındaki nesneler
	log("-- KARAKTER DURUMU --")
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") or c:IsA("Model") then
			log(("Karakter içi: [%s] %s"):format(c.ClassName, c.Name))
		end
	end
	log("========== RÖNTGEN BİTTİ ==========")
	copyText(table.concat(logLines, "\n", #logLines - 30, #logLines))
	setStatus("Röntgen tamamlandı, log'a yazıldı ve panoya kopyalandı!")
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

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(530, 340)
mainFrame.Position = UDim2.new(0.5, -265, 0.5, -170)
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
titleText.Text = "AERO HUB  •  Derin Röntgen & Remote Spy v4.1"
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

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -145, 1, -78)
contentArea.Position = UDim2.fromOffset(140, 44)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -145, 0, 26)
statusLabel.Position = UDim2.new(0, 140, 1, -30)
statusLabel.BackgroundColor3 = CONFIG.CardBg
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Spy Devrede. Elinle bir yumurta çal, logu buraya yapıştıracağız."
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame
corner(statusLabel, 6)
local statPad = Instance.new("UIPadding"); statPad.PaddingLeft = UDim.new(0, 8); statPad.Parent = statusLabel

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

local function addCardButton(container, text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
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

-- ==================== SEKMELER ====================

-- 1. SEKME: REMOTE SPY (AĞ DİNLEYİCİSİ)
local tabSpy = addTab("Remote Spy", "🕵️")
addCardButton(tabSpy, "Remote Spy'ı Yeniden Başlat", safe(initRemoteSpy))
addCardButton(tabSpy, "Yuvanın Yanında Dur & 'Derin Röntgen Çek'", safe(deepInspectNear))

-- Log Kutusu (Büyük)
local logBox = Instance.new("Frame")
logBox.Size = UDim2.new(1, 0, 0, 170)
logBox.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
logBox.Parent = tabSpy
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
logLabel.Text = "Spy bekleniyor... Oyunda bir yumurta çalınca paketler buraya akacak."
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
logLabel.Parent = logScroll

addCardButton(tabSpy, "Tüm Logları Panoya Kopyala", function()
	local ok = copyText(table.concat(logLines, "\n"))
	setStatus(ok and "Log panoya kopyalandı!" or "Pano yok.")
end)

-- Varsayılan Sekme
switchTab("Remote Spy")
initRemoteSpy()

-- Kapatma
local function unload()
	state.remoteSpy = false
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	if screen then screen:Destroy(); screen = nil end
	env.__AeroSteal = nil
	print("[AeroSteal] Kapatıldı.")
end
env.__AeroSteal = unload

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift and screen then
		mainFrame.Visible = not mainFrame.Visible
	end
end))

setStatus("Remote Spy Aktif! Git elinle 1 yumurta çal, logu yakalayalım.")
