if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait(math.random())

if getgenv().HmzHub_Executed then
	return
end
getgenv().HmzHub_Executed = true

local Hub = "HMZ Hub"
local Discord_Invite = ""
local HUB_URL = "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/loader.lua"

local Scripts = {
	[168519468] = { name = "Anime Astral" },
}

local Places = {
	[113236157544232] = true,
	[9797806474] = true,
}

local current = Scripts[game.CreatorId] or (Places[game.PlaceId] or Places[game.GameId]) and { name = "Anime Astral" }
if not current then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = Hub,
			Text = "This game is not supported!",
			Duration = 5,
		})
	end)
	return
end

getgenv().HmzHub = {
	hub = Hub,
	discord = Discord_Invite,
	name = current.name,
	hubUrl = HUB_URL,
}

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = Hub,
			Text = text,
			Duration = 5,
		})
	end)
end

local ok, err = pcall(function()
	local src = game:HttpGet(HUB_URL)
	if not src or #src == 0 or src:sub(1, 3) == "404" then
		error("download failed")
	end
	local fn, cerr = loadstring(src)
	if not fn then
		error(cerr or "compile failed")
	end
	fn()
end)

if not ok then
	warn("[HMZ Hub] " .. tostring(err))
	notify("Load failed: " .. tostring(err))
end
