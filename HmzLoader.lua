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

local function runHub()
	if readfile and isfile then
		if isfile("loader.lua") then
			loadstring(readfile("loader.lua"))()
			return true
		end
		if isfile("HmzHub.standalone.lua") then
			loadstring(readfile("HmzHub.standalone.lua"))()
			return true
		end
	end

	local ok, err = pcall(function()
		loadstring(game:HttpGet(cfg.hubUrl))()
	end)
	if not ok then
		notify(cfg.hub, "Load failed", 5)
		return false
	end
	return true
end

local function closeUi()
	local gui = PlayerGui:FindFirstChild("HmzLoader")
	if gui then
		gui:Destroy()
	end
end

if cfg.autoLoad then
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
frame.Size = UDim2.fromOffset(360, cfg.discord ~= "" and 170 or 150)
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
subtitle.Text = "Click Load to start"
subtitle.Parent = frame

local loadBtn = Instance.new("TextButton")
loadBtn.Name = "Load"
loadBtn.Position = UDim2.fromOffset(16, 78)
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

loadBtn.MouseButton1Click:Connect(function()
	if runHub() then
		closeUi()
	end
end)

if cfg.discord and cfg.discord ~= "" then
	local discBtn = Instance.new("TextButton")
	discBtn.BackgroundTransparency = 1
	discBtn.Position = UDim2.fromOffset(16, 128)
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
end
