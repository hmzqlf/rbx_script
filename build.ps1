$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$core = Get-Content (Join-Path $root "HmzHub\core.lua") -Raw
$game = Get-Content (Join-Path $root "HmzHub\games\anime_astral.lua") -Raw
$coreEsc = $core -replace '\]==\]', ']=]=]'
$gameEsc = $game -replace '\]==\]', ']=]=]'
$out = @"
local MODULES = {
	core = [==[
$coreEsc
]==],
	["games/anime_astral"] = [==[
$gameEsc
]==],
}

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

local function loadModule(rel)
	local src = MODULES[rel]
	if not src then
		error("[HMZ Hub] Missing module: " .. rel)
	end
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
"@
$dest = Join-Path $root "HmzHub.standalone.lua"
Set-Content -Path $dest -Value $out -NoNewline -Encoding UTF8
Write-Host "Built $dest"
