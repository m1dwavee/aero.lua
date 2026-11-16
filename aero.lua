-- AeroSteal v4.2 : Steal An Egg (Tek Tuşla Tüm Oyun Kodlarını Çekici)
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
	Accent = Color3.fromRGB(130, 95, 255),
	DarkBg = Color3.fromRGB(18, 18, 24),
	CardBg = Color3.fromRGB(26, 26, 36),
	SidebarBg = Color3.fromRGB(14, 14, 20),
	DumpFile = "AeroSteal/OyunKodlari.lua",
	MaxScriptDump = 100, -- Tek seferde çekilecek maksimum kod sayısı
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
	remoteSpy = true,
	activeTab = "Dumper",
}
local connections = {}
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

-- ==================== ⚡ TEK TUŞLA TÜM OYUN KODLARINI DÖKÜCÜ ====================
local function dumpAllGameScripts()
	setStatus("Tüm oyun kodları taranıyor ve decompile ediliyor, lütfen bekle...")
	task.wait(0.1)

	local output = {}
	local header = string.rep("=", 80)
	
	table.insert(output, header)
	table.insert(output, ("-- AEROSTEAL TAM OYUN KODLARI DÖKÜMÜ"))
	table.insert(output, ("-- PlaceId: %d | GameId: %d | Zaman: %s"):format(game.PlaceId, game.GameId, os.date()))
	table.insert(output, header .. "\n")

	local roots = {
		{ name = "ReplicatedStorage", inst = ReplicatedStorage },
		{ name = "PlayerScripts", inst = LocalPlayer:FindFirstChildOfClass("PlayerScripts") },
		{ name = "PlayerGui", inst = LocalPlayer:FindFirstChildOfClass("PlayerGui") },
		{ name = "StarterPlayerScripts", inst = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts") },
	}

	local scriptCount = 0
	local decompileFn = decompile or disassemble

	for _, root in ipairs(roots) do
		if root.inst then
			for _, desc in ipairs(root.inst:GetDescendants()) do
				if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
					scriptCount += 1
					if scriptCount > CONFIG.MaxScriptDump then break end

					table.insert(output, header)
					table.insert(output, ("-- [DOSYA %d]: %s"):format(scriptCount, desc:GetFullName()))
					table.insert(output, ("-- [TÜR]: %s | [İSİM]: %s"):format(desc.ClassName, desc.Name))
					table.insert(output, header)

					local codeExtracted = false

					-- 1. YÖNTEM: Executor decompile fonksiyonu ile kaynak kodu çek
					if typeof(decompileFn) == "function" then
						local okDec, code = pcall(decompileFn, desc)
						if okDec and type(code) == "string" and #code > 10 then
							table.insert(output, code)
							codeExtracted = true
						end
					end

					-- 2. YÖNTEM: Eğer decompile yoksa veya hata verdiyse ve ModuleScript ise require ile içeriğini dök
					if not codeExtracted and desc:IsA("ModuleScript") then
						local okReq, result = pcall(require, desc)
						if okReq then
							table.insert(output, "-- (require ile çekilen modül içeriği):")
							local okEnc, json = pcall(function() return HttpService:JSONEncode(result) end)
							if okEnc then
								table.insert(output, "return " .. json)
							else
								table.insert(output, "-- Modül Tablosu:")
								if type(result) == "table" then
									for k, v in pairs(result) do
										table.insert(output, ("  [%s] = %s"):format(tostring(k), tostring(v)))
									end
								else
									table.insert(output, tostring(result))
								end
							end
							codeExtracted = true
						else
							table.insert(output, "-- require hatası: " .. tostring(result))
						end
					end

					if not codeExtracted then
						table.insert(output, "-- [KOD ÇEKİLEMEDİ: Decompile fonksiyonu desteklenmiyor veya script kilitli]")
					end

					table.insert(output, "\n\n")
				end
			end
		end
	end

	local fullText = table.concat(output, "\n")
	local fileSize = #fullText

	-- Dosyaya yaz
	local savedToFile = false
	if typeof(writefile) == "function" then
		pcall(function()
			if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder("AeroSteal") then
				makefolder("AeroSteal")
			end
		end)
		local okSave = pcall(writefile, CONFIG.DumpFile, fullText)
		savedToFile = okSave
	end

	-- Panoya kopyala
	local copied = copyText(fullText)

	log(("========== KOD DÖKÜMÜ TAMAMLANDI =========="))
	log(("Toplam Çekilen Script: %d"):format(scriptCount))
	log(("Boyut: %d KB"):format(math.floor(fileSize / 1024)))
	log(savedToFile and ("Dosyaya kaydedildi: Delta/workspace/" .. CONFIG.DumpFile) or "Dosyaya yazılamadı.")
	log(copied and "TÜM KODLAR AYRICA PANONA KOPYALANDI!" or "Pano kopyalanamadı (boyut aşıldı, dosyadan bak).")
	log("===========================================")

	setStatus(("Bitti! %d script döküldü (%d KB). Panoya kopyalandı!"):format(scriptCount, math.floor(fileSize / 1024)))
end

-- ==================== 🕵️ REMOTE SPY ====================
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

				if string.find(remoteName, "egg") or string.find(remoteName, "carry") or string.find(remoteName, "steal")
					or string.find(remoteName, "drop") or string.find(remoteName, "field") or string.find(fullPath:lower(), "eggworld") then
					
					local argStr = {}
					for i, a in ipairs(args) do
						local s = typeof(a) == "Instance" and a:GetFullName() or tostring(a)
						argStr[#argStr + 1] = ("arg%d: %s"):format(i, s)
					end
					log(("[SPY YAKALADI!] %s -> %s\n  Argümanlar: %s"):format(method, fullPath, table.concat(argStr, " | ")))
					copyText(("[SPY] %s -> %s\nArgs: %s"):format(method, fullPath, table.concat(argStr, " | ")))
				end
			end
			return oldNamecall(self, ...)
		end)
	end)
	if ok then hookActive = true; log("[Spy] Ağ dinleyicisi devrede!") end
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

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(530, 340)
mainFrame.Position = UDim2.new(0.5, -265, 0.5, -170)
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
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundColor3 = CONFIG.SidebarBg
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
corner(topBar, 10)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.fromOffset(12, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "AERO HUB  •  Tüm Oyun Kodları Dökücüsü & Spy"
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
sidebar.Size = UDim2.new(0, 140, 1, -38)
sidebar.Position = UDim2.fromOffset(0, 38)
sidebar.BackgroundColor3 = CONFIG.SidebarBg
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
corner(sidebar, 8)

local sidebarLayout = Instance.new("UIListLayout"); sidebarLayout.Padding = UDim.new(0, 4); sidebarLayout.Parent = sidebar
local sidebarPad = Instance.new("UIPadding"); sidebarPad.PaddingTop = UDim.new(0, 8); sidebarPad.PaddingLeft = UDim.new(0, 6); sidebarPad.PaddingRight = UDim.new(0, 6); sidebarPad.Parent = sidebar

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -150, 1, -78)
contentArea.Position = UDim2.fromOffset(145, 44)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -150, 0, 26)
statusLabel.Position = UDim2.new(0, 145, 1, -30)
statusLabel.BackgroundColor3 = CONFIG.CardBg
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Hazır. 'Tüm Oyun Kodlarını Dök'e bas."
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
	btn.Size = UDim2.new(1, 0, 0, 34)
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

	local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 8); lay.Parent = container
	local p = Instance.new("UIPadding"); p.PaddingRight = UDim.new(0, 8); p.Parent = container

	tabButtons[name] = btn
	tabContainers[name] = container
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
	return container
end

local function addCardButton(container, text, callback, height)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height or 36)
	b.BackgroundColor3 = CONFIG.CardBg
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(235, 235, 255)
	b.Parent = container
	corner(b, 6)
	stroke(b, ACCENT, 1)
	b.MouseButton1Click:Connect(callback)
	return b
end

-- ==================== SEKMELERİ DOLDUR ====================

-- 1. SEKME: KOD DÖKÜCÜ (DUMPER)
local tabDump = addTab("Kod Dökücü", "⚡")

addCardButton(tabDump, "⚡ TÜM OYUN KODLARINI DÖK (Tek Tuş)", safe(dumpAllGameScripts), 44)

local infoBox = Instance.new("TextLabel")
infoBox.Size = UDim2.new(1, 0, 0, 60)
infoBox.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
infoBox.Text = "Bu düğmeye bastığında oyundaki tüm ModuleScript ve LocalScript'lerin içi çözülür, Delta/workspace/AeroSteal/OyunKodlari.lua dosyasına kaydedilir ve panoya kopyalanır!"
infoBox.TextColor3 = Color3.fromRGB(160, 160, 190)
infoBox.Font = Enum.Font.Gotham
infoBox.TextSize = 11
infoBox.TextWrapped = true
infoBox.Parent = tabDump
corner(infoBox, 6)

-- Log Alanı
local logBox = Instance.new("Frame")
logBox.Size = UDim2.new(1, 0, 0, 110)
logBox.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
logBox.Parent = tabDump
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
logLabel.Text = "Loglar burada görünecek..."
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
logLabel.Parent = logScroll

addCardButton(tabDump, "Logları Panoya Kopyala", function()
	copyText(table.concat(logLines, "\n"))
	setStatus("Log panoya kopyalandı.")
end, 30)

-- Varsayılan Sekme
switchTab("Kod Dökücü")
initRemoteSpy()

-- Kapatma
local function unload()
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

setStatus("Hazır! 'Tüm Oyun Kodlarını Dök' butonuna bas.")
