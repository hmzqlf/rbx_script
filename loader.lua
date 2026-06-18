local GITHUB_BASE = (getgenv and getgenv().HMZ_GITHUB_BASE) or "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/HmzHub"

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

local function validateBody(body, url)
	if not body or #body == 0 then
		error("[HMZ Hub] Empty response: " .. url)
	end
	if body:sub(1, 3) == "404" or body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true) then
		error("[HMZ Hub] GitHub inaccessible: " .. url .. " (repo privé → token ou readfile local)")
	end
	return body
end

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

local LOCAL_ROOTS = {
	"HmzHub",
	"rbx_script/HmzHub",
	"../HmzHub",
}

local function fetchSource(rel)
	if readfile and isfile then
		for _, root in ipairs(LOCAL_ROOTS) do
			local path = root .. "/" .. rel .. ".lua"
			if isfile(path) then
				return readfile(path)
			end
		end
	end
	if GITHUB_BASE and GITHUB_BASE ~= "" then
		local url = GITHUB_BASE .. "/" .. rel .. ".lua"
		return validateBody(hmzFetch(url), url)
	end
	error("[HMZ Hub] Missing module: " .. rel)
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
