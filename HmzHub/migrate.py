import re
from pathlib import Path

ROOT = Path(__file__).parent
lines = (ROOT / "_legacy_full.lua").read_text(encoding="utf-8").splitlines()

LOADER = r'''local REGISTRY = {
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

local ROOT = (getgenv and getgenv().HMZ_HUB_ROOT) or "own script/HmzHub"

local function readModule(rel)
	for _, base in ipairs({ ROOT, "HmzHub", "own script/HmzHub" }) do
		local path = base .. "/" .. rel .. ".lua"
		if readfile and isfile and isfile(path) then
			return readfile(path)
		end
	end
	error("[HMZ Hub] Missing module: " .. rel)
end

local function loadModule(rel)
	local src = readModule(rel)
	local fn, err = loadstring(src, rel)
	if not fn then error("[HMZ Hub] Load " .. rel .. ": " .. tostring(err)) end
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
'''

CORE_HEADER = r'''local HttpService = game:GetService("HttpService")

local H = {
	S = {},
	Threads = {},
	Cache = {
		OpenRaids = {},
		OpenDefenses = {},
		OpenTrials = {},
		RaidState = {},
		DefenseState = {},
		TrialState = {},
		LeaveFloors = {},
		LeaveFloorDefaults = {},
		LastLoadout = {},
		TrialSession = {},
	},
	UI = {},
	UIKind = {},
	DropdownCallbacks = {},
	InputCallbacks = {},
	Saved = {},
	Services = {
		Players = game:GetService("Players"),
		RunService = game:GetService("RunService"),
		Workspace = game:GetService("Workspace"),
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		HttpService = HttpService,
		UserInputService = game:GetService("UserInputService"),
		TeleportService = game:GetService("TeleportService"),
	},
	FarmStateKeys = {
		AutoFarmMob = true,
		FarmTrial = true,
		FarmRaid = true,
		FarmDefense = true,
		FarmGate = true,
	},
}

H.LocalPlayer = H.Services.Players.LocalPlayer
local Workspace = H.Services.Workspace
local TeleportService = H.Services.TeleportService
local HttpService = H.Services.HttpService

'''

CORE_FOOTER = r'''
function H.patchMacLibSource(src)
	local newGetGui = [=[local function GetGui()
	local newGui = Instance.new("ScreenGui")
	newGui.ScreenInsets = Enum.ScreenInsets.None
	newGui.ResetOnSpawn = false
	newGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	newGui.DisplayOrder = 2147483647
	local parent = LocalPlayer:WaitForChild("PlayerGui")
	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, newGui)
	elseif typeof(protectgui) == "function" then
		pcall(protectgui, newGui)
	end
	newGui.Parent = parent
	return newGui
end]=]
	local startPos = src:find("local function GetGui%(%)", 1, true)
	local endPos = startPos and src:find("\nlocal function Tween", startPos, true)
	if startPos and endPos then
		src = src:sub(1, startPos - 1) .. newGetGui .. src:sub(endPos)
	else
		src = src:gsub(
			'or %(cloneref and cloneref%(MacLib%.GetService%("CoreGui"%)%) or MacLib%.GetService%("CoreGui"%)%)',
			"or LocalPlayer:WaitForChild(\"PlayerGui\")"
		)
	end
	src = src:gsub(
		"GetService = function%(service%)\n\t\treturn cloneref and cloneref%(game:GetService%(service%)%) or game:GetService%(service%)\n\tend",
		"GetService = function(service)\n\t\tif service == \"CoreGui\" then\n\t\t\treturn LocalPlayer:WaitForChild(\"PlayerGui\")\n\t\tend\n\t\treturn cloneref and cloneref(game:GetService(service)) or game:GetService(service)\n\tend",
		1
	)
	return src
end

function H.loadMacLib()
	local src = game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt")
	src = src:gsub("TextSize = 20", "TextSize = 17")
	src = src:gsub("TextSize = 15", "TextSize = 13")
	src = src:gsub("TextSize = 13", "TextSize = 11")
	src = H.patchMacLibSource(src)
	local ok, lib = pcall(function() return loadstring(src)() end)
	if not ok then error("[HMZ Hub] MacLib: " .. tostring(lib)) end
	return lib
end

function H.initWindow()
	H.MacLib = H.loadMacLib()
	if H.waitReady then H.waitReady() end
	H.Window = H.MacLib:Window({
		Title = "HMZ Hub",
		Subtitle = H.GameCfg.Name,
		Size = UDim2.fromOffset(880, 600),
		DragStyle = 1,
		ShowUserInfo = true,
		AcrylicBlur = true,
	})
	H.Cache.UIBlur = H.savedGet("settings", "UIBlur", true)
	H.Cache.Notifications = H.savedGet("settings", "Notifications", true)
	H.Window:GlobalSetting({
		Name = "UI Blur",
		Default = H.Cache.UIBlur,
		Callback = function(on)
			H.Cache.UIBlur = on
			H.savedSet("settings", "UIBlur", on)
			pcall(function() H.Window:SetAcrylicBlurState(on) end)
		end,
	})
	H.Window:GlobalSetting({
		Name = "Notifications",
		Default = H.Cache.Notifications,
		Callback = function(on)
			H.Cache.Notifications = on
			H.savedSet("settings", "Notifications", on)
			pcall(function() H.Window:SetNotificationsState(on) end)
		end,
	})
	if H.setupWindowDrag then H.setupWindowDrag() end
end

function H.notify(title, desc, life)
	pcall(function()
		if H.Window and H.MacLib and H.MacLib.Notify then
			H.MacLib:Notify(title, desc, life or 4)
		end
	end)
end

return H
'''

SKIP_EXACT = {
	"HMZ_loadConfig()",
	"HMZ_buildUI()",
	"HMZ_restoreAll()",
	"HMZ_waitReady()",
	"HMZ_setupWindowDrag()",
}

SKIP_CONTAINS = [
	'HMZ_notify("HMZ Hub", "Loaded',
	"local MacLib = HMZ_loadMacLib()",
]

def transform(line):
	for s in SKIP_CONTAINS:
		if s in line:
			return None
	if line.strip() in SKIP_EXACT:
		return None
	line = line.replace("local function HMZ_buildUI()", "function H._buildUI()")
	line = line.replace("HMZ_CONFIG_PATH", "H.ConfigPath")
	line = line.replace("HMZ_ACTIVE_GAME.Name", "H.GameCfg.Name")
	line = line.replace("HMZ_ACTIVE_GAME.Id", "H.GameId")
	line = re.sub(r"\blocal function HMZ_(\w+)", r"function H.\1", line)
	line = re.sub(r"\bHMZ_(\w+)", r"H.\1", line)
	line = line.replace("local FARM_STATE_KEYS", "H.FarmStateKeys = H.FarmStateKeys or")
	line = line.replace("FARM_STATE_KEYS[", "H.FarmStateKeys[")
	line = line.replace("elseif FARM_STATE_KEYS", "elseif H.FarmStateKeys")
	repl = [
		("HMZ_UIKind", "H.UIKind"),
		("HMZ_UI[", "H.UI["),
		("HMZ_DropdownCallbacks", "H.DropdownCallbacks"),
		("HMZ_InputCallbacks", "H.InputCallbacks"),
		("HMZ_Saved", "H.Saved"),
		("HMZ_SaveJob", "H.SaveJob"),
		("HMZ_Restoring", "H.Restoring"),
		("\tS[", "\tH.S["),
		(" S[", " H.S["),
		("while S[", "while H.S["),
		("pairs(S)", "pairs(H.S)"),
		("\tCache.", "\tH.Cache."),
		(" Cache.", " H.Cache."),
		("Threads[", "H.Threads["),
	]
	for a, b in repl:
		line = line.replace(a, b)
	line = re.sub(r"(?<![.\w])ConfigFolder(?![.\w])", "H.ConfigFolder", line)
	line = re.sub(r"(?<![.\w])ClientFolder(?![.\w])", "H.ClientFolder", line)
	line = re.sub(r"(?<![.\w])NetFunctions(?![.\w])", "H.NetFunctions", line)
	line = re.sub(r"(?<![.\w])Library\.(?![.\w])", "H.Library.", line)
	line = re.sub(r"(?<![.\w])Library(?![.\w])", "H.Library", line)
	line = re.sub(r"(?<![.\w])Workspace(?![.\w])", "Workspace", line)
	line = re.sub(r"(?<![.\w])HttpService(?![.\w])", "HttpService", line)
	line = re.sub(r"(?<![.\w])LocalPlayer(?![.\w])", "H.LocalPlayer", line)
	line = line.replace("H.H.LocalPlayer", "H.LocalPlayer")
	line = line.replace("Players.H.LocalPlayer", "H.LocalPlayer")
	line = line.replace("MacLib:", "H.MacLib:")
	line = line.replace("Window:", "H.Window:")
	line = line.replace("Window =", "H.Window =")
	return line

def in_ranges(idx, ranges):
	return any(a <= idx <= b for a, b in ranges)

CORE_RANGES = [(173, 754), (757, 943)]
GAME_RANGES = [(48, 79), (373, 647), (944, 2058), (2096, 3218)]

core_body = []
for i, line in enumerate(lines):
	if in_ranges(i + 1, CORE_RANGES):
		t = transform(line)
		if t is not None:
			core_body.append(t)

game_body = []
for i, line in enumerate(lines):
	if in_ranges(i + 1, GAME_RANGES):
		t = transform(line)
		if t is not None:
			game_body.append(t)

game_out = "return function(H)\n"
game_out += "\tH.SimpleWorld = H.Services.ReplicatedStorage:WaitForChild(\"SimpleWorld\")\n"
game_out += "\tH.Library = require(H.SimpleWorld:WaitForChild(\"Library\"))\n"
game_out += "\tH.NetFunctions = H.SimpleWorld.Library.Network.Functions\n"
game_out += "\tH.ConfigFolder = H.SimpleWorld.Library.Config\n"
game_out += "\tH.ClientFolder = H.SimpleWorld.Library.Client\n\n"
for line in game_body:
	game_out += "\t" + line + "\n"
game_out += "\n\tfunction H.buildUI()\n\t\tH._buildUI()\n\tend\nend\n"

(ROOT / "games").mkdir(parents=True, exist_ok=True)
(ROOT / "core.lua").write_text(CORE_HEADER + "\n".join(core_body) + CORE_FOOTER, encoding="utf-8")
(ROOT / "games" / "anime_astral.lua").write_text(game_out, encoding="utf-8")
(ROOT.parent / "HmzHub.lua").write_text(LOADER, encoding="utf-8")
print("core lines", len(core_body), "game lines", len(game_body))
