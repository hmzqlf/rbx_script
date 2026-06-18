local cfg = getgenv().HmzHub
if not cfg then
	return
end

if getgenv().HmzLoader_Executed then
	return
end
getgenv().HmzLoader_Executed = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
end

local function copyText(text)
	if setclipboard then
		setclipboard(text)
		notify(cfg.hub, "Copied to clipboard", 3)
	end
end

local function hmzFetch(url)
	local token = getgenv and getgenv().HMZ_GITHUB_TOKEN
	local reqFn = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request
	if token and reqFn then
		local ok, res = pcall(function()
			return reqFn({
				Url = url,
				Method = "GET",
				Headers = {
					Authorization = "token " .. token,
					Accept = "application/vnd.github.raw",
				},
			})
		end)
		if ok and res then
			local body = res.Body or res.body
			local code = res.StatusCode or res.status or res.Status
			if type(body) == "string" and #body > 0 and (code == 200 or code == nil) then
				return body
			end
		end
	end
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and #body > 0 then
		if body:sub(1, 3) == "404" or body:find("<!DOCTYPE", 1, true) then
			return nil
		end
		return body
	end
	return nil
end

local function validateKey(key)
	if not cfg.requireKey then
		return true
	end
	key = key and key:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if #key == 0 then
		return false
	end
	for _, allowed in ipairs(cfg.keys or {}) do
		if key == allowed then
			return true
		end
	end
	return false
end

local function runHub(key)
	if cfg.requireKey and not validateKey(key) then
		notify(cfg.hub, "Invalid key", 4)
		return false
	end

	if readfile and isfile then
		if isfile("HmzHub.standalone.lua") then
			loadstring(readfile("HmzHub.standalone.lua"))()
			return true
		end
		if isfile("loader.lua") then
			loadstring(readfile("loader.lua"))()
			return true
		end
	end

	local src = hmzFetch(cfg.hubUrl)
	if src then
		loadstring(src)()
		return true
	end

	notify(cfg.hub, "Hub load failed (token GitHub ?)", 5)
	return false
end

local function closeUi()
	local gui = PlayerGui:FindFirstChild("HmzLoader")
	if gui then
		gui:Destroy()
	end
end

local function tryLoad(key)
	if runHub(key) then
		closeUi()
	end
end

if cfg.autoLoad and not cfg.requireKey then
	if runHub() then
		return
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "HmzLoader"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(360, cfg.requireKey and 220 or 180)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 55, 70)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1, -32, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.Text = cfg.hub .. " — " .. (cfg.name or "Game")
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 42)
subtitle.Size = UDim2.new(1, -32, 0, 20)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(150, 150, 165)
subtitle.Text = cfg.requireKey and "Enter your key" or "Click Load to start"
subtitle.Parent = frame

local loadBtn = Instance.new("TextButton")
loadBtn.Name = "Load"
loadBtn.Position = UDim2.fromOffset(16, cfg.requireKey and 130 or 90)
loadBtn.Size = UDim2.new(1, -32, 0, 40)
loadBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
loadBtn.Font = Enum.Font.GothamBold
loadBtn.TextSize = 15
loadBtn.Text = "Load"
loadBtn.AutoButtonColor = true
loadBtn.Parent = frame

local loadCorner = Instance.new("UICorner")
loadCorner.CornerRadius = UDim.new(0, 8)
loadCorner.Parent = loadBtn

local input
if cfg.requireKey then
	input = Instance.new("TextBox")
	input.Name = "KeyInput"
	input.Position = UDim2.fromOffset(16, 78)
	input.Size = UDim2.new(1, -32, 0, 36)
	input.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	input.TextColor3 = Color3.fromRGB(235, 235, 240)
	input.PlaceholderText = "Key..."
	input.PlaceholderColor3 = Color3.fromRGB(100, 100, 115)
	input.Font = Enum.Font.Gotham
	input.TextSize = 14
	input.ClearTextOnFocus = false
	input.Parent = frame

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 8)
	inputCorner.Parent = input

	local inputPad = Instance.new("UIPadding")
	inputPad.PaddingLeft = UDim.new(0, 10)
	inputPad.PaddingRight = UDim.new(0, 10)
	inputPad.Parent = input
end

loadBtn.MouseButton1Click:Connect(function()
	tryLoad(input and input.Text or nil)
end)

if input then
	input.FocusLost:Connect(function(enter)
		if enter then
			tryLoad(input.Text)
		end
	end)
end

if cfg.discord and cfg.discord ~= "" then
	local discBtn = Instance.new("TextButton")
	discBtn.BackgroundTransparency = 1
	discBtn.Position = UDim2.fromOffset(16, cfg.requireKey and 178 or 138)
	discBtn.Size = UDim2.new(1, -32, 0, 20)
	discBtn.Font = Enum.Font.Gotham
	discBtn.TextSize = 12
	discBtn.TextXAlignment = Enum.TextXAlignment.Left
	discBtn.TextColor3 = Color3.fromRGB(130, 130, 145)
	discBtn.Text = "Discord: discord.gg/" .. cfg.discord
	discBtn.Parent = frame
	discBtn.MouseButton1Click:Connect(function()
		copyText("https://discord.gg/" .. cfg.discord)
	end)
	frame.Size = UDim2.fromOffset(360, cfg.requireKey and 210 or 170)
end
