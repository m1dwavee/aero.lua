-- AeroSteal v4.3 : Steal An Egg (Derin Tablo Çözücü Spy)
-- Menü: RightShift veya ekrandaki mor "A" düğmesi

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ===== AYARLAR =====
local CONFIG = {
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

local screen, statusLabel, logLabel, logScroll
local logLines = {}
local connections = {}
local function track(conn) connections[#connections + 1] = conn; return conn end

-- ---------- Log & Durum ----------
local function refreshLog()
	if not logLabel then return end
	local parts, total = {}, 0
	for i = #logLines, 1, -1 do
		local l = logLines[i]
		total += #l + 1
		if total > 12000 or #parts >= 150 then break end
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
	if #logLines > 600 then
		logLines = table.move(logLines, #logLines - 399, #logLines, 1, {})
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

-- ==================== 🔍 DERİN TABLO VE NESNE ÇÖZÜCÜ ====================
local function serializeValue(val, depth)
	depth = depth or 0
	if depth > 4 then return "{...}" end

	local t = typeof(val)
	if t == "Instance" then
		return "Instance(" .. val:GetFullName() .. ")"
	elseif t == "table" then
		local s = "{\n"
		local indent = string.rep("  ", depth + 1)
		for k, v in pairs(val) do
			s = s .. indent .. "[" .. tostring(k) .. "] = " .. serializeValue(v, depth + 1) .. ",\n"
		end
		return s .. string.rep("  ", depth) .. "}"
	elseif t == "string" then
		return string.format("%q", val)
	else
		return tostring(val)
	end
end

-- ==================== 🕵️ REMOTE SPY (TABLO İÇERİĞİNİ AÇAR) ====================
local hookActive = false
local function initRemoteSpy()
	if hookActive then return end
	local ok, err = pcall(function()
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			local args = { ... }

			if method == "FireServer" or method == "InvokeServer" then
				local remoteName = self.Name:lower()
				local fullPath = self:GetFullName()

				if string.find(remoteName, "egg") or string.find(remoteName, "carry") or string.find(remoteName, "steal")
					or string.find(remoteName, "drop") or string.find(fullPath:lower(), "eggworld") then
					
					local argText = {}
					for i, a in ipairs(args) do
						argText[#argText + 1] = ("arg%d = %s"):format(i, serializeValue(a, 0))
					end

					local capturedMsg = ("\n🎯 [SPY YAKALADI!]\nFonksiyon: %s -> %s\nArgümanlar:\n%s\n"):format(
						method, fullPath, table.concat(argText, "\n")
					)

					log(capturedMsg)
					copyText(capturedMsg)
				end
			end
			return oldNamecall(self, ...)
		end)
	end)
	if ok then
		hookActive = true
		log("[Spy] Tablo Çözücü Devrede! Git elinle 1 yumurta çal, tablonun içindeki yazıları görelim.")
	else
		log("[Spy] Hata: " .. tostring(err))
	end
end

-- ==================== GUI ====================
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
mainFrame.Size = UDim2.fromOffset(480, 310)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -155)
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
titleText.Text = "AERO  •  Derin Parametre Yakalayıcı v4.3"
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
content.Size = UDim2.new(1, -20, 1, -80)
content.Position = UDim2.fromOffset(10, 44)
content.BackgroundTransparency = 1
content.Parent = mainFrame

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 26)
statusLabel.Position = UDim2.new(0, 10, 1, -32)
statusLabel.BackgroundColor3 = CONFIG.CardBg
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Git elinle 1 tane yumurta çal, tablo içeriği buraya dökülecek."
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame
corner(statusLabel, 6)
local statPad = Instance.new("UIPadding"); statPad.PaddingLeft = UDim.new(0, 8); statPad.Parent = statusLabel

local logBox = Instance.new("Frame")
logBox.Size = UDim2.new(1, 0, 0, 175)
logBox.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
logBox.Parent = content
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
logLabel.Text = "Spy bekleniyor... Elinle 1 yumurta çalınca yakalanan parametreler burada listelenecek."
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
logLabel.Parent = logScroll

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(1, 0, 0, 34)
copyBtn.Position = UDim2.fromOffset(0, 185)
copyBtn.BackgroundColor3 = CONFIG.CardBg
copyBtn.Text = "📋 Yakalanan Tabloyu Panoya Kopyala"
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 13
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Parent = content
corner(copyBtn, 6)
stroke(copyBtn, ACCENT, 1)

copyBtn.MouseButton1Click:Connect(function()
	local ok = copyText(table.concat(logLines, "\n"))
	setStatus(ok and "Panoya kopyalandı!" or "Pano fonksiyonu yok.")
end)

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

setStatus("Spy Hazır! Elinle 1 yumurta çal.")
