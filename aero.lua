-- AeroSteal v5.1 : Steal An Egg (AskFieldEggCarry Kod Avcısı)
-- Menü: RightShift veya ekrandaki mor "A" düğmesi

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ===== CONFIG =====
local CONFIG = {
	Accent = Color3.fromRGB(130, 95, 255),
	DarkBg = Color3.fromRGB(18, 18, 24),
	CardBg = Color3.fromRGB(26, 26, 36),
}
-- ==================

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

-- ==================== 🎯 NOKTA ATIŞI ÇALMA KODUNU BULUCU ====================
local function findStealSourceCode()
	setStatus("Oyun kodları taranıyor, 'AskFieldEggCarry' aranıyor...")
	task.wait(0.1)

	local decompileFn = decompile or disassemble
	local roots = {
		ReplicatedStorage,
		LocalPlayer:FindFirstChildOfClass("PlayerScripts"),
		LocalPlayer:FindFirstChildOfClass("PlayerGui"),
	}

	local found = false

	for _, root in ipairs(roots) do
		if root then
			for _, desc in ipairs(root:GetDescendants()) do
				if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
					-- Sadece Egg, Carry, Steal, World ile ilgili scriptlere odaklan
					local n = desc.Name:lower()
					local p = desc:GetFullName():lower()
					if string.find(n, "egg") or string.find(n, "carry") or string.find(n, "steal")
						or string.find(p, "eggs") or string.find(p, "networking") or string.find(n, "controller") then

						if typeof(decompileFn) == "function" then
							local ok, src = pcall(decompileFn, desc)
							if ok and type(src) == "string" and string.find(src, "AskFieldEggCarry") then
								found = true
								log("==================================================")
								log("🎯 BULUNDU: " .. desc:GetFullName())
								log("==================================================")

								-- AskFieldEggCarry geçen satırları ve etrafını ayıkla
								local lines = string.split(src, "\n")
								for i, line in ipairs(lines) do
									if string.find(line, "AskFieldEggCarry") then
										local startL = math.max(1, i - 10)
										local endL = math.min(#lines, i + 15)
										log(("-- Kod Parçası (Satır %d-%d):"):format(startL, endL))
										for j = startL, endL do
											log(lines[j])
										end
									end
								end
								copyText(table.concat(logLines, "\n", #logLines - 35, #logLines))
								break
							end
						end
					end
				end
			end
		end
		if found then break end
	end

	if not found then
		log("AskFieldEggCarry doğrudan bulunamadı, Networking paketi aranıyor...")
		-- Alternatif: ReplicatedStorage.Shared.Eggs modüllerini tara
		local eggFolder = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Eggs")
		if eggFolder then
			for _, m in ipairs(eggFolder:GetChildren()) do
				if m:IsA("ModuleScript") and typeof(decompileFn) == "function" then
					local ok, src = pcall(decompileFn, m)
					if ok and type(src) == "string" and (string.find(src, "Carry") or string.find(src, "Steal")) then
						log("Bulunan İlgili Modül: " .. m:GetFullName())
						log(string.sub(src, 1, 800))
						copyText(string.sub(src, 1, 800))
						found = true
						break
					end
				end
			end
		end
	end

	setStatus(found and "Hedef kod bulundu ve panoya kopyalandı!" or "Hedef kod bulunamadı.")
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
mainFrame.Size = UDim2.fromOffset(500, 320)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -160)
mainFrame.BackgroundColor3 = CONFIG.DarkBg
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screen
corner(mainFrame, 10)
stroke(mainFrame, ACCENT, 1.5)

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
titleText.Text = "AERO  •  AskFieldEggCarry Kod Avcısı v5.1"
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 13
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Parent = topBar

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -74)
content.Position = UDim2.fromOffset(10, 42)
content.BackgroundTransparency = 1
content.Parent = mainFrame

local findBtn = Instance.new("TextButton")
findBtn.Size = UDim2.new(1, 0, 0, 36)
findBtn.BackgroundColor3 = CONFIG.CardBg
findBtn.Text = "🎯 ÇALMA KODUNU BUL VE EKRANA BAS (Tek Tık)"
findBtn.Font = Enum.Font.GothamBold
findBtn.TextSize = 13
findBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
findBtn.Parent = content
corner(findBtn, 6)
stroke(findBtn, ACCENT, 1)
findBtn.MouseButton1Click:Connect(safe(findStealSourceCode))

local logBox = Instance.new("Frame")
logBox.Size = UDim2.new(1, 0, 1, -80)
logBox.Position = UDim2.fromOffset(0, 42)
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
logLabel.Text = "Yukarıdaki butona basınca oyunun çalma kod bloğu buraya çıkacak."
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
logLabel.Parent = logScroll

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(1, 0, 0, 32)
copyBtn.Position = UDim2.new(0, 0, 1, -34)
copyBtn.BackgroundColor3 = CONFIG.CardBg
copyBtn.Text = "📋 Çıkan Kodu Kopyala"
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 12
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Parent = content
corner(copyBtn, 6)
copyBtn.MouseButton1Click:Connect(function()
	copyText(table.concat(logLines, "\n"))
	setStatus("Panoya kopyalandı!")
end)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 24)
statusLabel.Position = UDim2.new(0, 10, 1, -28)
statusLabel.BackgroundColor3 = CONFIG.CardBg
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Hazır! Yukarıdaki butona bas."
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame
corner(statusLabel, 6)

-- Kapatma
local function unload()
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	if screen then screen:Destroy(); screen = nil end
	env.__AeroSteal = nil
end
env.__AeroSteal = unload

setStatus("Hazır! Butona bas, çalma kodunu çekelim.")
