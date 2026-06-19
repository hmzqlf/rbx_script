$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$version = (git -C $root rev-parse HEAD).Trim()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Utf8NoBom([string]$Path, [string]$Content) {
	[System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$core = Get-Content (Join-Path $root "source\HmzHub\core.lua") -Raw
$game = Get-Content (Join-Path $root "source\HmzHub\games\anime_astral.lua") -Raw
$coreEsc = $core -replace '\]==\]', ']=]=]'
$gameEsc = $game -replace '\]==\]', ']=]=]'

$header = @"
if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait(math.random())

if getgenv().HmzHub_Executed then
	return
end
getgenv().HmzHub_Executed = true

local Hub = "HMZ Hub"
local Scripts = { [168519468] = true }
local Places = { [113236157544232] = true, [9797806474] = true }

if not Scripts[game.CreatorId] and not Places[game.PlaceId] and not Places[game.GameId] then
	print("[HMZ Hub] Unsupported game")
	return
end

local function hmzFail(msg)
	getgenv().HmzHub_Executed = nil
	warn("[HMZ Hub] " .. msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = Hub,
			Text = msg,
			Duration = 6,
		})
	end)
end

local ok, err = pcall(function()

"@

$footer = @"

end)

if not ok then
	hmzFail(tostring(err))
end
"@

$body = @"
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
	error("Unsupported PlaceId=" .. tostring(game.PlaceId))
end

local function loadModule(rel)
	local src = MODULES[rel]
	if not src then
		error("Missing module: " .. rel)
	end
	local fn, cerr = loadstring(src, "@" .. rel)
	if not fn then
		error("Compile " .. rel .. ": " .. tostring(cerr))
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

$hubOut = $header + $body + $footer
Write-Utf8NoBom (Join-Path $root "HmzHub.lua") $hubOut
Write-Utf8NoBom (Join-Path $root "VERSION") $version

$load = @"
getgenv().HmzHub_Executed = nil
local url = "https://raw.githubusercontent.com/hmzqlf/rbx_script/$version/HmzHub.lua"
local src = game:HttpGet(url)
if not src or #src < 10000 then
	warn("[HMZ Hub] Download failed (" .. tostring(#src) .. " bytes). Update Load.lua")
	return
end
if src:byte(1) == 239 and src:byte(2) == 187 and src:byte(3) == 191 then
	src = src:sub(4)
end
local fn, err = loadstring(src)
if not fn then
	warn("[HMZ Hub] " .. tostring(err))
	return
end
fn()
"@

Write-Utf8NoBom (Join-Path $root "Load.lua") $load
Write-Host "Built HmzHub.lua + Load.lua ($version)"
Write-Host ""
Write-Host "loadstring(game:HttpGet('https://raw.githubusercontent.com/hmzqlf/rbx_script/main/Load.lua'))()"
