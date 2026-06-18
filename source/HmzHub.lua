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

local UI_LOADER = "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/HmzLoader"

local Scripts = {
	[168519468] = { name = "Anime Astral" },
}

local current = Scripts[game.CreatorId]
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
	autoLoad = false,
	hubUrl = "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/loader.lua",
}

loadstring(game:HttpGet(UI_LOADER))()
