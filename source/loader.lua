local GITHUB_BASE = "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/HmzHub"

local REGISTRY = {
	anime_astral = {
		Name = "Anime Astral",
		Places = { 113236157544232, 9797806474 },
		Module = "games/anime_astral",
	},
}

local function resolveGame()
	local pid, gid = game.PlaceId, game.GameId
	for id, cfg in pairs(REGISTRY) do
		for _, place in ipairs(cfg.Places) do
			if place == pid or place == gid then
				return id, cfg
			end
		end
	end
	return nil, nil
end

local gameId, gameCfg = resolveGame()
if not gameId then
	warn("[HMZ Hub] Unsupported PlaceId=" .. tostring(game.PlaceId))
	return
end

local LOCAL_ROOTS = { "HmzHub", "rbx_script/HmzHub" }

local function fetchSource(rel)
	if readfile and isfile then
		for _, root in ipairs(LOCAL_ROOTS) do
			local path = root .. "/" .. rel .. ".lua"
			if isfile(path) then
				return readfile(path)
			end
		end
	end
	local url = GITHUB_BASE .. "/" .. rel .. ".lua"
	local body = game:HttpGet(url)
	if not body or #body == 0 or body:sub(1, 3) == "404" or body:find("<!DOCTYPE", 1, true) then
		error("[HMZ Hub] Failed to fetch: " .. url)
	end
	return body
end

local function loadModule(rel)
	local src = fetchSource(rel)
	local fn, err = loadstring(src, "@" .. rel)
	if not fn then
		error("[HMZ Hub] Compile " .. rel .. ": " .. tostring(err))
	end
	return fn()
end

local H = loadModule("core")
H.GameId = gameId
H.GameCfg = gameCfg
H.ConfigPath = "HMZHub/" .. gameId .. "/" .. game:GetService("Players").LocalPlayer.Name .. ".json"

loadModule(gameCfg.Module)(H)

H.loadConfig()
H.initWindow()
H.buildUI()
H.restoreAll()
H.notify("HMZ Hub", "Loaded " .. gameCfg.Name, 5)
