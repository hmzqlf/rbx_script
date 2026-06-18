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
	requireKey = false,
	keys = {},
	autoLoad = false,
	hubUrl = "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/loader.lua",
	githubBase = "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/HmzHub",
}

getgenv().HMZ_GITHUB_BASE = getgenv().HMZ_GITHUB_BASE or getgenv().HmzHub.githubBase

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
		return body
	end
	return nil
end

local src = hmzFetch(UI_LOADER)
if not src or src:sub(1, 3) == "404" then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = Hub,
			Text = "Loader UI failed (token GitHub ?)",
			Duration = 5,
		})
	end)
	return
end

loadstring(src)()
