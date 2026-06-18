-- Doc de la lib : https://brady-xyz.gitbook.io/maclib-ui-library

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

local HMZ_PLACE_ID = game.PlaceId
local HMZ_GAME_ID = game.GameId

local HMZ_GAMES = {
	[113236157544232] = {
		Id = "anime_astral",
		Name = "Anime Astral",
		UniverseId = 9797806474,
	},
	[9797806474] = {
		Id = "anime_astral",
		Name = "Anime Astral",
		UniverseId = 9797806474,
	},
}

local HMZ_ACTIVE_GAME = HMZ_GAMES[HMZ_PLACE_ID] or HMZ_GAMES[HMZ_GAME_ID]
if not HMZ_ACTIVE_GAME then
	warn("[HMZ Hub] Jeu non supporte. PlaceId: " .. tostring(HMZ_PLACE_ID) .. " | GameId: " .. tostring(HMZ_GAME_ID))
	return
end

local function HMZ_registerGame(placeOrUniverseId, config)
	HMZ_GAMES[placeOrUniverseId] = config
	if config.UniverseId then
		HMZ_GAMES[config.UniverseId] = config
	end
end

local LocalPlayer = Players.LocalPlayer

local SimpleWorld = ReplicatedStorage:WaitForChild("SimpleWorld")
local Library = require(SimpleWorld:WaitForChild("Library"))
local NetFunctions = SimpleWorld.Library.Network.Functions
local ConfigFolder = SimpleWorld.Library.Config
local ClientFolder = SimpleWorld.Library.Client

local function HMZ_require(folder, name)
	local m = folder:FindFirstChild(name)
	if not m then return nil end
	local ok, r = pcall(require, m)
	if ok then return r end
	return nil
end

local function HMZ_getBridge(name)
	local ok, b = pcall(function() return Library.getBridge(name) end)
	if ok then return b end
	return nil
end

local function HMZ_fire(name, ...)
	local b = HMZ_getBridge(name)
	if b then pcall(function(...) b:Fire(...) end, ...) end
end

local function HMZ_connect(name, fn)
	local b = HMZ_getBridge(name)
	if b then pcall(function() b:Connect(fn) end) end
end

local function HMZ_invoke(name, ...)
	local f = NetFunctions:FindFirstChild(name)
	if not f then return nil end
	local args = table.pack(...)
	local ok, res = pcall(function() return f:InvokeServer(table.unpack(args, 1, args.n)) end)
	if ok then return res end
	return nil
end

local function HMZ_patchMacLibSource(src)
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
		warn("[HMZ Hub] MacLib GetGui patch missed, using fallback patches")
		src = src:gsub(
			'or %(cloneref and cloneref%(MacLib%.GetService%("CoreGui"%)%) or MacLib%.GetService%("CoreGui"%)%)',
			"or LocalPlayer:WaitForChild(\"PlayerGui\")"
		)
		src = src:gsub("or %(gethui and gethui%(%)%)", "or nil")
	end
	src = src:gsub(
		"GetService = function%(service%)\n\t\treturn cloneref and cloneref%(game:GetService%(service%)%) or game:GetService%(service%)\n\tend",
		"GetService = function(service)\n\t\tif service == \"CoreGui\" then\n\t\t\treturn LocalPlayer:WaitForChild(\"PlayerGui\")\n\t\tend\n\t\treturn cloneref and cloneref(game:GetService(service)) or game:GetService(service)\n\tend",
		1
	)
	return src
end

local function HMZ_loadMacLib()
	local src = game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt")
	src = src:gsub("TextSize = 20", "TextSize = __HMZ_A__")
	src = src:gsub("TextSize = 15", "TextSize = __HMZ_B__")
	src = src:gsub("TextSize = 13", "TextSize = __HMZ_C__")
	src = src:gsub("TextSize = 12", "TextSize = __HMZ_D__")
	src = src:gsub("TextSize = 11", "TextSize = __HMZ_E__")
	src = src:gsub("TextSize = __HMZ_A__", "TextSize = 17")
	src = src:gsub("TextSize = __HMZ_B__", "TextSize = 13")
	src = src:gsub("TextSize = __HMZ_C__", "TextSize = 11")
	src = src:gsub("TextSize = __HMZ_D__", "TextSize = 10")
	src = src:gsub("TextSize = __HMZ_E__", "TextSize = 10")
	src = src:gsub("Size = UDim2.new%(1, 0, 0, 38%)", "Size = UDim2.new(1, 0, 0, 33)")
	src = src:gsub("Size = UDim2.fromOffset%(41, 21%)", "Size = UDim2.fromOffset(36, 18)")
	src = src:gsub("Size = UDim2.fromOffset%(15, 15%)", "Size = UDim2.fromOffset(13, 13)")
	src = HMZ_patchMacLibSource(src)
	local ok, lib = pcall(function() return loadstring(src)() end)
	if not ok then
		error("[HMZ Hub] MacLib load failed: " .. tostring(lib))
	end
	return lib
end

local MacLib = HMZ_loadMacLib()

local Window
local S = {}
local Threads = {}
local Cache = {
	OpenRaids = {},
	OpenDefenses = {},
	OpenTrials = {},
	RaidState = {},
	DefenseState = {},
	TrialState = {},
	RaidActiveKey = nil,
	DefenseActiveKey = nil,
	TrialActiveKey = nil,
	TrialSession = {},
	TrialResume = nil,
	LeaveFloors = {},
	LeaveFloorDefaults = {},
	InGamemode = false,
	Potions = {},
	LastLoadout = {},
}

local HMZ_UI = {}
local HMZ_UIKind = {}
local HMZ_DropdownCallbacks = {}
local HMZ_InputCallbacks = {}
local HMZ_Saved = {}
local HMZ_SaveJob = nil
local HMZ_Restoring = false
local HMZ_CONFIG_PATH = "HMZHub/" .. HMZ_ACTIVE_GAME.Id .. "/" .. LocalPlayer.Name .. ".json"

local function HMZ_canSave()
	return not HMZ_Restoring and writefile ~= nil
end

local function HMZ_savedGet(group, id, fallback)
	local bucket = HMZ_Saved[group]
	if type(bucket) ~= "table" then return fallback end
	local value = bucket[id]
	if value == nil then return fallback end
	return value
end

local function HMZ_savedSet(group, id, value)
	HMZ_Saved[group] = HMZ_Saved[group] or {}
	HMZ_Saved[group][id] = value
	if not HMZ_canSave() then return end
	if HMZ_SaveJob then task.cancel(HMZ_SaveJob) end
	HMZ_SaveJob = task.delay(0.35, function()
		pcall(function()
			if writefile then
				if makefolder then
					pcall(makefolder, "HMZHub")
					pcall(makefolder, "HMZHub/" .. HMZ_ACTIVE_GAME.Id)
				end
				writefile(HMZ_CONFIG_PATH, HttpService:JSONEncode(HMZ_Saved))
			end
		end)
	end)
end

local function HMZ_loadConfig()
	HMZ_Saved = {}
	if not (readfile and isfile and isfile(HMZ_CONFIG_PATH)) then return end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(HMZ_CONFIG_PATH))
	end)
	if ok and type(data) == "table" then
		HMZ_Saved = data
		if type(HMZ_Saved.dropdowns) == "table" then
			local fm = HMZ_Saved.dropdowns.FarmMob
			if type(fm) == "string" then
				HMZ_Saved.dropdowns.FarmMob = { fm }
			elseif type(fm) == "number" then
				HMZ_Saved.dropdowns.FarmMob = {}
			end
			local ft = HMZ_Saved.dropdowns.FarmTarget
			if type(ft) == "number" and ft >= 1 and ft <= 3 then
				HMZ_Saved.dropdowns.FarmTargetMode = ft
			elseif type(ft) == "table" and (not HMZ_Saved.dropdowns.FarmMob or not next(HMZ_Saved.dropdowns.FarmMob)) then
				local merged = {}
				for k, v in pairs(ft) do
					if type(k) == "number" and type(v) == "string" then
						merged[v] = true
					elseif v == true and type(k) == "string" then
						merged[k] = true
					end
				end
				if next(merged) then
					HMZ_Saved.dropdowns.FarmMob = merged
				end
			end
			HMZ_Saved.dropdowns.FarmTarget = nil
		end
		if type(HMZ_Saved.sliders) == "table" then
			HMZ_Saved.leaveFloorDefaults = HMZ_Saved.leaveFloorDefaults or {}
			local legacy = {
				LeaveRaid = "Raid",
				LeaveDefense = "Defense",
				LeaveTrial = "Trial",
				LeaveGate = "Gate",
			}
			for oldId, cat in pairs(legacy) do
				local v = HMZ_Saved.sliders[oldId]
				if type(v) == "number" and v > 0 and HMZ_Saved.leaveFloorDefaults[cat] == nil then
					HMZ_Saved.leaveFloorDefaults[cat] = v
				end
			end
		end
	end
end

local function HMZ_wrapSection(section)
	local wrapped = {}
	local function passthrough(name)
		wrapped[name] = function(_, ...)
			return section[name](section, ...)
		end
	end
	for _, name in ipairs({ "Header", "Paragraph", "Button" }) do
		passthrough(name)
	end
	function wrapped:Toggle(settings, id)
		id = id or settings.Name
		local saved = HMZ_savedGet("toggles", id, settings.Default)
		if saved ~= nil then settings.Default = saved end
		local old = settings.Callback
		settings.Callback = function(on)
			HMZ_savedSet("toggles", id, on)
			if old then old(on) end
		end
		local el = section:Toggle(settings, id)
		HMZ_UI[id] = el
		HMZ_UIKind[id] = "toggle"
		return el
	end
	function wrapped:Slider(settings, id)
		id = id or settings.Name
		local saved = HMZ_savedGet("sliders", id, settings.Default)
		if saved ~= nil then settings.Default = saved end
		local old = settings.Callback
		settings.Callback = function(v)
			HMZ_savedSet("sliders", id, v)
			if old then old(v) end
		end
		local el = section:Slider(settings, id)
		HMZ_UI[id] = el
		HMZ_UIKind[id] = "slider"
		return el
	end
	function wrapped:Dropdown(settings, id)
		id = id or settings.Name
		local saved = HMZ_savedGet("dropdowns", id, nil)
		if saved ~= nil then
			if settings.Multi then
				settings.Default = saved
			elseif type(saved) == "number" then
				settings.Default = saved
			elseif type(saved) == "string" and type(settings.Options) == "table" then
				for i, opt in ipairs(settings.Options) do
					if opt == saved then
						settings.Default = i
						break
					end
				end
			end
		end
		local old = settings.Callback
		settings.Callback = function(v)
			if settings.Multi then
				local arr = {}
				if type(v) == "table" then
					for name, on in pairs(v) do
						if on then arr[#arr + 1] = name end
					end
				end
				HMZ_savedSet("dropdowns", id, arr)
			else
				local idx = nil
				if type(settings.Options) == "table" then
					for i, opt in ipairs(settings.Options) do
						if opt == v then
							idx = i
							break
						end
					end
				end
				HMZ_savedSet("dropdowns", id, idx or v)
			end
			if old then old(v) end
		end
		HMZ_DropdownCallbacks[id] = old
		local el = section:Dropdown(settings, id)
		HMZ_UI[id] = el
		HMZ_UIKind[id] = "dropdown"
		return el
	end
	function wrapped:Input(settings, id)
		id = id or settings.Name
		local saved = HMZ_savedGet("inputs", id, settings.Default)
		if saved ~= nil then settings.Default = saved end
		local old = settings.Callback
		settings.Callback = function(text)
			HMZ_savedSet("inputs", id, text)
			if old then old(text) end
		end
		HMZ_InputCallbacks[id] = old
		local el = section:Input(settings, id)
		HMZ_UI[id] = el
		HMZ_UIKind[id] = "input"
		return el
	end
	function wrapped:Keybind(settings, id)
		id = id or settings.Name
		local saved = HMZ_savedGet("keybinds", id, nil)
		if saved and Enum.KeyCode[saved] then
			settings.Default = Enum.KeyCode[saved]
		end
		local old = settings.Callback
		settings.Callback = function(key)
			if key then HMZ_savedSet("keybinds", id, key.Name) end
			if old then old(key) end
		end
		local el = section:Keybind(settings, id)
		HMZ_UI[id] = el
		HMZ_UIKind[id] = "keybind"
		return el
	end
	return wrapped
end

local HMZ_canRunFeature

local function HMZ_getPromptPart(prompt)
	local p = prompt.Parent
	if p and p:IsA("BasePart") then return p end
	if p and p:IsA("Model") then
		return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function HMZ_findCrowPrompts()
	local prompts = {}
	local folder = Workspace:FindFirstChild("World6Corvos")
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("ProximityPrompt") and (d.Name == "CorvoClaimPrompt" or d.ObjectText == "Crow") then
				if d.Enabled then
					prompts[#prompts + 1] = d
				end
			end
		end
	end
	if #prompts == 0 then
		local worlds = Workspace:FindFirstChild("Worlds")
		local w6 = worlds and (worlds:FindFirstChild("6") or worlds:FindFirstChild("World6"))
		if w6 then
			for _, d in ipairs(w6:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.ObjectText == "Crow" and d.Enabled then
					prompts[#prompts + 1] = d
				end
			end
		end
	end
	return prompts
end

local function HMZ_collectCrow(prompt)
	local hrp = HMZ_getHRP()
	local part = HMZ_getPromptPart(prompt)
	if hrp and part then
		local target = part.CFrame * CFrame.new(0, 4, 0)
		hrp.CFrame = target
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.25)
	end
	if fireproximityprompt then
		pcall(fireproximityprompt, prompt, 0)
		task.wait(0.05)
		pcall(fireproximityprompt, prompt, 1)
	end
end

local function HMZ_hopServer()
	local ok, servers = pcall(function()
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
		return HttpService:JSONDecode(game:HttpGet(url))
	end)
	if ok and type(servers) == "table" and type(servers.data) == "table" then
		for _, server in ipairs(servers.data) do
			if type(server) == "table" and server.id and server.id ~= game.JobId then
				local playing = server.playing or 0
				local maxPlayers = server.maxPlayers or 0
				if playing < maxPlayers then
					pcall(function()
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
					end)
					return
				end
			end
		end
	end
	pcall(function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)
end

local function HMZ_autoCrowTick()
	if HMZ_canRunFeature and not HMZ_canRunFeature("Crow") then return end
	if HMZ_travelWorld then HMZ_travelWorld(6) end
	if Cache.HopForAutoCrow then
		local prompts = HMZ_findCrowPrompts()
		if #prompts > 0 then
			Cache.CrowHadAny = true
			Cache.CrowEmptySince = nil
			for _, prompt in ipairs(prompts) do
				if not S.AutoCrow then return end
				HMZ_collectCrow(prompt)
				task.wait(0.6)
			end
			return
		end
		if not Cache.CrowHadAny then
			HMZ_hopServer()
			return
		end
		if not Cache.CrowEmptySince then
			Cache.CrowEmptySince = os.clock()
			return
		end
		if os.clock() - Cache.CrowEmptySince >= 3 then
			Cache.CrowHadAny = false
			Cache.CrowEmptySince = nil
			HMZ_hopServer()
		end
		return
	end
	local prompts = HMZ_findCrowPrompts()
	if prompts[1] then
		HMZ_collectCrow(prompts[1])
	end
end

local function HMZ_swordPassiveKey(info)
	return string.format(
		"%s_%s_%s_%s",
		tostring(info.SwordKey),
		tostring(info.Rarity),
		tostring(info.Level or 0),
		tostring(info.Index or 1)
	)
end

local function HMZ_parseSwordLevelCounts(levelData)
	local out = {}
	if type(levelData) == "number" then
		out[0] = levelData
	elseif type(levelData) == "table" then
		for level, count in pairs(levelData) do
			if type(count) == "number" and count > 0 then
				out[tonumber(level) or 0] = count
			end
		end
	end
	return out
end

local function HMZ_buildSwordInventory()
	local data = HMZ_invoke("GetPlayerData")
	local list = {}
	if type(data) ~= "table" or type(data.ActiveSwords) ~= "table" then
		return list
	end
	local scfg = HMZ_require(ConfigFolder, "SwordConfig")
	local locked = type(data.LockedSwords) == "table" and data.LockedSwords or {}
	for swordKey, rarityMap in pairs(data.ActiveSwords) do
		if type(rarityMap) == "table" then
			local swordDef = scfg and scfg.GetSword and scfg:GetSword(swordKey)
			for rarity, levelData in pairs(rarityMap) do
				local itemDef = swordDef and swordDef.Items and swordDef.Items[rarity]
				for level, count in pairs(HMZ_parseSwordLevelCounts(levelData)) do
					for index = 1, count do
						local lockKey = swordKey .. "_" .. rarity .. "_" .. tostring(level)
						list[#list + 1] = {
							SwordKey = swordKey,
							Rarity = rarity,
							Level = level,
							Index = index,
							Name = itemDef and itemDef.Name or swordKey,
							Model = itemDef and itemDef.Model or rarity,
							IsLocked = locked[lockKey] == true,
						}
					end
				end
			end
		end
	end
	return list
end

local function HMZ_getSwordPassiveId(info, passives, spc)
	if type(passives) ~= "table" then return nil end
	local pid = passives[HMZ_swordPassiveKey(info)]
	if pid == nil and (info.Index or 1) == 1 then
		pid = passives[string.format("%s_%s_%s", info.SwordKey, info.Rarity, info.Level or 0)]
	end
	if type(pid) == "table" then
		return pid.Id or pid.Name
	end
	if type(pid) == "string" then
		return pid
	end
	return nil
end

local function HMZ_swordHasTargetPassive(info, passives, spc, targetId)
	if not targetId or targetId == "" or targetId == "None" then return false end
	local pid = HMZ_getSwordPassiveId(info, passives, spc)
	if not pid then return false end
	if pid == targetId then return true end
	if spc and type(spc.GetPassiveById) == "function" then
		local ok, cfg = pcall(function() return spc:GetPassiveById(targetId) end)
		if ok and cfg and pid == cfg.Id then return true end
	end
	return false
end

local function HMZ_refreshSwordPassiveQueue()
	Cache.SwordPassiveQueue = {}
	local rarity = Cache.SwordPassiveRarity
	if not rarity then return end
	local ok, err = pcall(function()
		local spc = HMZ_require(ConfigFolder, "SwordPassiveConfig")
		local data = HMZ_invoke("GetPlayerData")
		local passives = type(data) == "table" and data.SwordPassives or {}
		local targetId = Cache.SwordPassiveTargetId
		local queue = {}
		for _, sword in ipairs(HMZ_buildSwordInventory()) do
			if sword.Rarity == rarity and not sword.IsLocked then
				if not HMZ_swordHasTargetPassive(sword, passives, spc, targetId) then
					queue[#queue + 1] = sword
				end
			end
		end
		Cache.SwordPassiveQueue = queue
	end)
	if not ok then
		warn("[HMZ Hub] SwordPassiveQueue: " .. tostring(err))
		Cache.SwordPassiveQueue = {}
	end
	if not Cache.SwordPassiveIndex or Cache.SwordPassiveIndex > #Cache.SwordPassiveQueue then
		Cache.SwordPassiveIndex = 1
	end
end

local function HMZ_getNextPassiveSword()
	HMZ_refreshSwordPassiveQueue()
	local queue = Cache.SwordPassiveQueue
	if type(queue) ~= "table" or #queue == 0 then
		return nil
	end
	local targetId = Cache.SwordPassiveTargetId
	if targetId and targetId ~= "None" then
		return queue[1]
	end
	local idx = Cache.SwordPassiveIndex or 1
	if idx > #queue then idx = 1 end
	Cache.SwordPassiveIndex = idx
	return queue[idx]
end

local function HMZ_advancePassiveSword()
	local targetId = Cache.SwordPassiveTargetId
	if targetId and targetId ~= "None" then
		HMZ_refreshSwordPassiveQueue()
		return
	end
	local queue = Cache.SwordPassiveQueue
	if type(queue) ~= "table" or #queue == 0 then return end
	local idx = (Cache.SwordPassiveIndex or 1) + 1
	if idx > #queue then idx = 1 end
	Cache.SwordPassiveIndex = idx
end

local function HMZ_autoSwordPassiveTick()
	local spc = HMZ_require(ConfigFolder, "SwordPassiveConfig")
	if not Cache.SwordPassiveRarity then return end
	local sword = HMZ_getNextPassiveSword()
	if not sword then
		S.AutoSwordPassive = false
		HMZ_setState("AutoSwordPassive", false, 1, HMZ_autoSwordPassiveTick)
		HMZ_notify("HMZ Hub", "All sword passives done", 5)
		return
	end
	HMZ_fire("SwordPassiveRollRequest", {
		SystemKey = (spc and spc.SystemKey) or "World6",
		SwordKey = sword.SwordKey,
		Rarity = sword.Rarity,
		Level = sword.Level or 0,
		Index = sword.Index or 1,
	})
	Cache.SwordPassiveRolling = sword
end

local function HMZ_restoreDropdown(id, el, options)
	local saved = HMZ_savedGet("dropdowns", id, nil)
	if saved == nil or not el.UpdateSelection then return end
	if type(saved) == "table" then
		el:UpdateSelection(saved)
		if HMZ_DropdownCallbacks[id] then
			local map = {}
			for _, name in ipairs(saved) do
				map[name] = true
			end
			HMZ_DropdownCallbacks[id](map)
		end
		return
	end
	if type(saved) == "number" then
		el:UpdateSelection(saved)
		if HMZ_DropdownCallbacks[id] and type(options) == "table" then
			HMZ_DropdownCallbacks[id](options[saved])
		elseif HMZ_DropdownCallbacks[id] and el.GetOptions then
			for name in pairs(el:GetOptions()) do
				HMZ_DropdownCallbacks[id](name)
				break
			end
		end
		return
	end
	if type(saved) == "string" then
		if HMZ_DropdownCallbacks[id] then
			HMZ_DropdownCallbacks[id](saved)
		end
	end
end

local function HMZ_restoreAll()
	HMZ_Restoring = true
	task.defer(function()
		task.wait(0.2)
		for id, el in pairs(HMZ_UI) do
			if HMZ_UIKind[id] == "slider" then
				local saved = HMZ_savedGet("sliders", id, nil)
				if saved ~= nil and el.UpdateValue then
					el:UpdateValue(saved)
				end
			elseif HMZ_UIKind[id] == "input" then
				local saved = HMZ_savedGet("inputs", id, nil)
				if saved ~= nil and el.UpdateText then
					el:UpdateText(saved)
					if HMZ_InputCallbacks[id] then HMZ_InputCallbacks[id](saved) end
				end
			end
		end
		local dropdownOrder = {
			"FarmWorld", "FarmMob", "FarmTargetMode", "TrialSel", "RaidSel", "DefenseSel",
			"GateTarget", "TrialTarget", "RaidTarget", "DefenseTarget",
			"StarEgg", "SwordBanner", "SwordPassiveRarity", "SwordPassiveTarget", "DefShopBuy", "ExchangeBuy", "ShopPotions",
			"TrialShopBuy", "MerchantBuy", "TitanBanner", "Upgrades", "CastleUpgrades",
			"GachaBanner", "EquipPassive", "ProgSelected", "StatPoint", "TpWorld", "TpDest",
			"UsePotions",
		}
		for _, id in ipairs(dropdownOrder) do
			local el = HMZ_UI[id]
			if el then HMZ_restoreDropdown(id, el) end
		end
		for id, el in pairs(HMZ_UI) do
			if HMZ_UIKind[id] == "dropdown" and not table.find(dropdownOrder, id) then
				HMZ_restoreDropdown(id, el)
			end
		end
		if type(HMZ_Saved.leaveFloorDefaults) == "table" then
			for cat, val in pairs(HMZ_Saved.leaveFloorDefaults) do
				Cache.LeaveFloorDefaults[cat] = val
			end
		end
		if type(HMZ_Saved.leaveFloors) == "table" then
			for id, val in pairs(HMZ_Saved.leaveFloors) do
				Cache.LeaveFloors[id] = val
			end
		end
		if type(HMZ_Saved.gamemodeValues) == "table" and type(Cache.GamemodeSel) == "table" then
			for title, sel in pairs(Cache.GamemodeSel) do
				local val = HMZ_Saved.gamemodeValues[title]
				if val ~= nil then sel.value = val end
			end
		end
		local blur = HMZ_savedGet("settings", "UIBlur", nil)
		if blur ~= nil then
			Cache.UIBlur = blur
			pcall(function() Window:SetAcrylicBlurState(blur) end)
		end
		local notif = HMZ_savedGet("settings", "Notifications", nil)
		if notif ~= nil then
			Cache.Notifications = notif
			pcall(function() Window:SetNotificationsState(notif) end)
		end
		local scale = HMZ_savedGet("settings", "UIScale", nil)
		if scale ~= nil then
			pcall(function() Window:SetScale(scale / 100) end)
		end
		for id, el in pairs(HMZ_UI) do
			if HMZ_UIKind[id] == "toggle" and HMZ_savedGet("toggles", id, false) == true and el.UpdateState then
				el:UpdateState(true)
			end
		end
		HMZ_Restoring = false
	end)
end

HMZ_loadConfig()

local function HMZ_notify(title, desc, life)
	if not Window then return end
	if Cache.Notifications == false then return end
	pcall(function()
		Window:Notify({ Title = title, Description = desc, Lifetime = life or 4 })
	end)
end

local HMZ_DRAG = {
	active = false,
	input = nil,
	start = nil,
	pos = nil,
	base = nil,
	connected = false,
}

local function HMZ_findMacBase()
	local macGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MacLib")
	if not macGui then
		local coreGui = game:GetService("CoreGui")
		macGui = coreGui:FindFirstChild("MacLib")
	end
	if not macGui then return nil end
	return macGui:FindFirstChild("Base")
end

local function HMZ_raiseGuiLayer(frame, handle)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= handle then
			child.ZIndex = math.max(child.ZIndex, handle.ZIndex + 1)
		end
	end
end

local function HMZ_bindDragArea(frame, base)
	if not frame or not base then return end
	local handle = frame:FindFirstChild("HMZ_DragHandle")
	if not handle then
		handle = Instance.new("TextButton")
		handle.Name = "HMZ_DragHandle"
		handle.Size = UDim2.fromScale(1, 1)
		handle.BackgroundTransparency = 1
		handle.Text = ""
		handle.AutoButtonColor = false
		handle.ZIndex = 1
		handle.Parent = frame
		HMZ_raiseGuiLayer(frame, handle)
	end
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		HMZ_DRAG.active = true
		HMZ_DRAG.base = base
		HMZ_DRAG.start = input.Position
		HMZ_DRAG.pos = base.Position
		HMZ_DRAG.input = input
	end)
	handle.InputChanged:Connect(function(input)
		if HMZ_DRAG.active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			HMZ_DRAG.input = input
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			HMZ_DRAG.active = false
			HMZ_DRAG.input = nil
		end
	end)
end

local function HMZ_setupWindowDrag()
	if HMZ_DRAG.connected then return end
	HMZ_DRAG.connected = true
	UserInputService.InputChanged:Connect(function(input)
		if not HMZ_DRAG.active or input ~= HMZ_DRAG.input or not HMZ_DRAG.base then return end
		local delta = input.Position - HMZ_DRAG.start
		HMZ_DRAG.base.Position = UDim2.new(
			HMZ_DRAG.pos.X.Scale,
			HMZ_DRAG.pos.X.Offset + delta.X,
			HMZ_DRAG.pos.Y.Scale,
			HMZ_DRAG.pos.Y.Offset + delta.Y
		)
	end)
	task.defer(function()
		local base
		local deadline = os.clock() + 5
		while os.clock() < deadline do
			base = HMZ_findMacBase()
			if base then break end
			task.wait(0.1)
		end
		if not base then return end
		local sidebar = base:FindFirstChild("Sidebar")
		local content = base:FindFirstChild("Content")
		if not sidebar or not content then return end
		local zones = {
			sidebar:FindFirstChild("WindowControls"),
			sidebar:FindFirstChild("Information"),
			content:FindFirstChild("Topbar"),
		}
		for _, zone in ipairs(zones) do
			HMZ_bindDragArea(zone, base)
		end
	end)
end

local function HMZ_char()
	return LocalPlayer.Character
end

local function HMZ_getHRP()
	local c = HMZ_char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function HMZ_humanoid()
	local c = HMZ_char()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function HMZ_isLoading()
	local tc = HMZ_require(ClientFolder, "TeleportController")
	if tc and tc.IsLoading then
		local ok, res = pcall(function() return tc:IsLoading() end)
		if ok then return res end
	end
	return false
end

local function HMZ_waitLoad(timeout)
	local deadline = os.clock() + (timeout or 10)
	while HMZ_isLoading() and os.clock() < deadline do
		task.wait(0.1)
	end
	task.wait(0.15)
end

local function HMZ_waitReady()
	local deadline = os.clock() + 30
	while LocalPlayer:GetAttribute("ServerReady") ~= true and os.clock() < deadline do
		task.wait(0.2)
	end
end

local function HMZ_start(key, interval, fn)
	if Threads[key] then return end
	Threads[key] = task.spawn(function()
		while S[key] do
			pcall(fn)
			task.wait(interval)
		end
		Threads[key] = nil
	end)
end

local FARM_STATE_KEYS = {
	AutoFarmMob = true,
	FarmTrial = true,
	FarmRaid = true,
	FarmDefense = true,
	FarmGate = true,
}

local function HMZ_restoreCharacter()
	local hum = HMZ_humanoid()
	if hum then
		hum.PlatformStand = false
		hum.AutoRotate = true
		if hum.Health > 0 then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
		end
	end
	local hrp = HMZ_getHRP()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local function HMZ_setState(key, on, interval, fn)
	S[key] = on
	if on then
		HMZ_start(key, interval, fn)
	elseif FARM_STATE_KEYS[key] then
		HMZ_restoreCharacter()
	end
end

local HMZ_CODES = {
	"UPDATE2.5", "UPDATE2", "UPDATE1.5", "UPDATE1", "RELEASE",
	"10MVISITS", "9.5MVISITS", "8MVISITS", "7.5MVISITS", "7MVISITS", "6.5MVISITS",
	"3.5MVISITS", "3MVISITS", "1.5MVISITS", "1MVISITS",
	"500KVISITS", "200KVISITS", "100KVISITS",
	"30KPLAYERS", "28KPLAYERS", "27.5KPLAYERS", "25KPLAYERS", "24KPLAYERS",
	"20KPLAYERS", "19KPLAYERS", "18KPLAYERS", "17KPLAYERS", "15KPLAYERS",
	"13KPLAYERS", "10KPLAYERS", "7KPLAYERS", "6.5KPLAYERS", "6KPLAYERS",
	"5KPLAYERS", "4KPLAYERS", "3.5KPLAYERS", "2.5KPLAYERS", "1KPLAYERS",
	"8KLIKES", "5KLIKES", "2.5KLIKES", "1KLIKES", "4KFAVS",
	"20KMEMBERS",
	"SORRYFORSHUTDOWN6", "SORRYFORSHUTDOWN5", "SORRYFORSHUTDOWN3", "SORRYFORSHUTDOWN2", "SORRYFORSHUTDOWN",
	"SORRYFORDELAY3", "SORRYFORDELAY2", "SORRYFORDELAY",
	"REWARDSFIXED", "NPCNERF", "EXCHANGE", "BATTLEPASS", "MOUNTS", "TRACKER", "3KEVENT", "GO30K?",
}

local function HMZ_fetchRemoteCodes()
	local url = Cache.CodesUrl
	local out = {}
	if not url or url == "" then return out end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if not ok or type(body) ~= "string" then return out end
	local okj, arr = pcall(function() return HttpService:JSONDecode(body) end)
	if okj and type(arr) == "table" then
		for _, c in pairs(arr) do if type(c) == "string" then out[#out + 1] = c end end
		return out
	end
	for token in body:gmatch("[^\r\n,]+") do
		local c = token:gsub("^%s*(.-)%s*$", "%1")
		if c ~= "" then out[#out + 1] = c end
	end
	return out
end

local function HMZ_redeemedSet()
	local set = {}
	local data = HMZ_invoke("GetPlayerData")
	if type(data) == "table" and type(data.RedeemedCodes) == "table" then
		for k, v in pairs(data.RedeemedCodes) do
			if type(k) == "string" then set[k] = true end
			if type(v) == "string" then set[v] = true end
		end
	end
	return set
end

local function HMZ_redeemAll(keepGoing)
	Cache.RedeemedLocal = Cache.RedeemedLocal or {}
	local redeemed = HMZ_redeemedSet()
	local seen, list = {}, {}
	for _, c in ipairs(HMZ_CODES) do
		if not seen[c] then seen[c] = true; list[#list + 1] = c end
	end
	for _, c in ipairs(HMZ_fetchRemoteCodes()) do
		if not seen[c] then seen[c] = true; list[#list + 1] = c end
	end
	local fired = 0
	for _, code in ipairs(list) do
		if keepGoing and not keepGoing() then break end
		if not redeemed[code] and not Cache.RedeemedLocal[code] then
			Cache.RedeemedLocal[code] = true
			HMZ_fire("RedeemCode", code)
			fired = fired + 1
			task.wait(11)
		end
	end
	return fired
end

local function HMZ_namedOptions(subTable)
	local labels, map = {}, {}
	if type(subTable) ~= "table" then return labels, map end
	local arr = {}
	for k, v in pairs(subTable) do
		local name = (type(v) == "table" and v.Name) or tostring(k)
		local order = (type(v) == "table" and (v.Order or v.LayoutOrder)) or 0
		arr[#arr + 1] = { id = k, label = name, order = order }
	end
	table.sort(arr, function(a, b)
		if a.order == b.order then return tostring(a.id) < tostring(b.id) end
		return a.order < b.order
	end)
	for _, e in ipairs(arr) do
		labels[#labels + 1] = e.label
		map[e.label] = e.id
	end
	return labels, map
end

local WorldLabels, WorldMap = {}, {}
do
	local c = HMZ_require(ConfigFolder, "WorldConfig")
	if c and c.Worlds then
		WorldLabels, WorldMap = HMZ_namedOptions(c.Worlds)
	end
	if #WorldLabels == 0 then
		WorldLabels = { "Lobby Arena", "Ninja Village", "Namek City", "Wano Island", "Titan Wall", "Solo City", "Slayer Village" }
		for i, n in ipairs(WorldLabels) do WorldMap[n] = tostring(i - 1) end
	end
end

local HMZ_LeaveModes = {}
local HMZ_LeaveStateKeys = {}

local HMZ_LEAVE_SOURCES = {
	{ config = "TimeTrialConfig", getAll = "GetAllTrials", category = "Trial", stateKey = "TrialState", activeKey = "TrialActiveKey", field = "Room", leaveBridge = "TimeTrialLeave", idFields = { "TrialKey", "Key", "Id" }, unit = "Room", progressKey = "TotalRooms" },
	{ config = "RaidConfig", getAll = "GetAllRaids", category = "Raid", stateKey = "RaidState", activeKey = "RaidActiveKey", field = "Wave", leaveBridge = "RaidLeave", idFields = { "RaidKey", "Key", "ActiveKey", "Id" }, unit = "Wave", progressKey = "TotalWaves", categoryFn = function(configId)
		if configId == "World5" then return "Gate" end
		if configId == "World6" then return "Infinite Castle" end
		return "Raid"
	end },
	{ config = "DefenseConfig", getAll = "GetAllDefenses", category = "Defense", stateKey = "DefenseState", activeKey = "DefenseActiveKey", field = "Wave", leaveBridge = "DefenseLeave", idFields = { "DefenseKey", "Key", "ActiveKey", "Id" }, unit = "Wave", progressKey = "TotalWaves" },
}

local function HMZ_leaveModeId(category, configId)
	return tostring(category) .. "/" .. tostring(configId)
end

local function HMZ_leaveSliderId(modeId)
	return "LeaveFloor_" .. modeId:gsub("[^%w_]", "_")
end

local function HMZ_addLeaveMode(modes, seen, entry)
	local id = HMZ_leaveModeId(entry.category, entry.configId)
	if seen[id] then return end
	seen[id] = true
	modes[#modes + 1] = entry
	entry.id = id
end

local function HMZ_discoverLeaveModes()
	local modes, seen = {}, {}
	for _, src in ipairs(HMZ_LEAVE_SOURCES) do
		local c = HMZ_require(ConfigFolder, src.config)
		if c and c[src.getAll] then
			local ok, all = pcall(function() return c[src.getAll](c) end)
			if ok and type(all) == "table" then
				for key, entry in pairs(all) do
					local configId = tostring(key)
					local label = tostring(key)
					local maxProgress = 500
					if type(entry) == "table" then
						label = entry.Name or entry.DisplayName or entry.Title or label
						maxProgress = entry[src.progressKey or ""] or maxProgress
					end
					local category = src.category
					if src.categoryFn then
						category = src.categoryFn(configId, label)
					end
					HMZ_addLeaveMode(modes, seen, {
						label = label,
						category = category,
						configId = configId,
						stateKey = src.stateKey,
						activeKey = src.activeKey,
						field = src.field,
						leaveBridge = src.leaveBridge,
						idFields = src.idFields,
						unit = src.unit,
						maxProgress = maxProgress,
					})
				end
			end
		end
	end
	table.sort(modes, function(a, b)
		if a.category == b.category then return tostring(a.label) < tostring(b.label) end
		return tostring(a.category) < tostring(b.category)
	end)
	local stateKeys = {}
	for _, mode in ipairs(modes) do
		stateKeys[mode.stateKey] = true
	end
	local orderedKeys = {}
	for key in pairs(stateKeys) do
		orderedKeys[#orderedKeys + 1] = key
	end
	table.sort(orderedKeys)
	return modes, orderedKeys
end

HMZ_LeaveModes, HMZ_LeaveStateKeys = HMZ_discoverLeaveModes()

local function HMZ_getStateModeId(state, idFields)
	if type(state) ~= "table" then return nil end
	for _, field in ipairs(idFields) do
		local val = state[field]
		if val ~= nil and val ~= "" then return val end
	end
	return nil
end

local function HMZ_getTrackedModeKey(mode)
	if type(mode) ~= "table" or not mode.activeKey then return nil end
	return Cache[mode.activeKey]
end

local function HMZ_stateMatchesLeaveMode(state, mode)
	if type(state) ~= "table" or type(mode) ~= "table" then return false end
	local tracked = HMZ_getTrackedModeKey(mode)
	if tracked and tostring(tracked) == tostring(mode.configId) then return true end
	local sid = HMZ_getStateModeId(state, mode.idFields)
	if sid and tostring(sid) == tostring(mode.configId) then return true end
	return false
end

local function HMZ_getLeaveFloorLimit(mode)
	if type(mode) ~= "table" then return nil end
	local v = Cache.LeaveFloors[mode.id]
	if v == nil then v = HMZ_savedGet("leaveFloors", mode.id, nil) end
	if type(v) == "number" and v > 0 then return v end
	local def = Cache.LeaveFloorDefaults[mode.category]
	if def == nil then def = HMZ_savedGet("leaveFloorDefaults", mode.category, nil) end
	if type(def) == "number" and def > 0 then return def end
	return nil
end

local function HMZ_getLeaveProgress(state, mode)
	if type(state) ~= "table" or type(mode) ~= "table" then return nil end
	if state[mode.field] ~= nil then return state[mode.field] end
	if mode.category == "Gate" and state.Floor ~= nil then return state.Floor end
	if mode.category == "Infinite Castle" and state.Wave ~= nil then return state.Wave end
	return nil
end

local function HMZ_getActiveLeaveMode()
	for _, mode in ipairs(HMZ_LeaveModes) do
		local state = Cache[mode.stateKey]
		local progress = HMZ_getLeaveProgress(state, mode)
		if progress and HMZ_stateMatchesLeaveMode(state, mode) then
			return mode, state, progress
		end
	end
	return nil, nil, nil
end

local function HMZ_autoLeaveFloorTick()
	local mode, state, progress = HMZ_getActiveLeaveMode()
	if not mode or not state or progress == nil then return end
	local limit = HMZ_getLeaveFloorLimit(mode)
	if limit and limit > 0 and progress >= limit then
		if mode.stateKey == "TrialState" then
			HMZ_onTrialFinished()
		end
		HMZ_fire(mode.leaveBridge)
	end
end

local function HMZ_buildLeaveFloorUI(section)
	local lastCategory
	for _, mode in ipairs(HMZ_LeaveModes) do
		if mode.category ~= lastCategory then
			section:Header({ Text = "Leave " .. mode.category })
			lastCategory = mode.category
		end
		local sliderId = HMZ_leaveSliderId(mode.id)
		local saved = HMZ_savedGet("leaveFloors", mode.id, 0)
		section:Slider({
			Name = mode.label,
			Default = type(saved) == "number" and saved or 0,
			Minimum = 0,
			Maximum = math.max(50, tonumber(mode.maxProgress) or 500),
			DisplayMethod = "Round",
			Callback = function(v)
				Cache.LeaveFloors[mode.id] = v
				HMZ_savedSet("leaveFloors", mode.id, v)
			end,
		}, sliderId)
	end
	if #HMZ_LeaveModes == 0 then
		section:Paragraph({
			Header = "Leave Floor",
			Body = "No gamemodes found in config.",
		})
	end
end

local function HMZ_mobOptions(worldId)
	local out = { "Any" }
	local c = HMZ_require(ConfigFolder, "EnemyConfig")
	if c and c.GetEnemiesByWorld and worldId then
		local ok, list = pcall(function() return c:GetEnemiesByWorld(tonumber(worldId)) end)
		if ok and type(list) == "table" then
			for _, e in pairs(list) do
				if type(e) == "table" and e.Name then out[#out + 1] = e.Name end
			end
		end
	end
	if #out == 1 then
		local worlds = Workspace:FindFirstChild("Worlds")
		local w = worlds and worlds:FindFirstChild(tostring(worldId))
		local en = w and w:FindFirstChild("Enemies")
		if en then
			local seen = {}
			for _, m in ipairs(en:GetChildren()) do
				if m:IsA("Model") and not seen[m.Name] then
					seen[m.Name] = true
					out[#out + 1] = m.Name
				end
			end
		end
	end
	return out
end

local function HMZ_configOptions(configName, sub)
	local c = HMZ_require(ConfigFolder, configName)
	if not c then return {}, {} end
	local subTable = sub and c[sub] or c
	return HMZ_namedOptions(subTable)
end

local function HMZ_shopProducts(configName, shopKey)
	local labels, map = {}, {}
	local c = HMZ_require(ConfigFolder, configName)
	if not c then return labels, map end
	local prods
	if c.GetProducts then
		local ok, r = pcall(function() return c:GetProducts(shopKey) end)
		if ok then prods = r end
	end
	if not prods and c.Shops and c.Shops[shopKey] then
		prods = c.Shops[shopKey].Products or c.Shops[shopKey]
	end
	if not prods then prods = c.Products end
	if type(prods) == "table" then
		for k, v in pairs(prods) do
			local pid = (type(v) == "table" and (v.ProductId or v.Id)) or k
			local name = (type(v) == "table" and (v.Name or v.ProductId)) or tostring(k)
			labels[#labels + 1] = name
			map[name] = pid
		end
	end
	return labels, map
end

local function HMZ_multiToList(value, map)
	local out = {}
	if type(value) == "table" then
		for name, on in pairs(value) do
			if on then out[#out + 1] = (map and map[name]) or name end
		end
	elseif type(value) == "string" then
		out[#out + 1] = (map and map[value]) or value
	end
	return out
end

local function HMZ_mobMatchesFilter(mobName, mobFilter)
	if not mobFilter or mobFilter == "" or mobFilter == "Any" then return true end
	if type(mobFilter) == "string" then
		return mobFilter == "Any" or mobName == mobFilter
	end
	if type(mobFilter) == "table" then
		local picked = false
		for key, val in pairs(mobFilter) do
			if val == true then
				picked = true
				if key == "Any" or key == mobName then return true end
			elseif type(val) == "string" then
				picked = true
				if val == "Any" or val == mobName then return true end
			end
		end
		if not picked then
			for _, name in ipairs(mobFilter) do
				if name == "Any" or name == mobName then return true end
			end
			return true
		end
		return false
	end
	return true
end

local function HMZ_splitPriorityEnemies(enemies, priorityFilter)
	if not priorityFilter then return enemies end
	local hasPriority = false
	if type(priorityFilter) == "table" then
		for key, val in pairs(priorityFilter) do
			if val == true or type(val) == "string" then
				hasPriority = true
				break
			end
		end
		if not hasPriority and #priorityFilter > 0 then
			hasPriority = true
		end
	end
	if not hasPriority or type(priorityFilter) == "string" and (priorityFilter == "" or priorityFilter == "Any") then
		return enemies
	end
	local priority = {}
	for _, m in ipairs(enemies) do
		if HMZ_mobMatchesFilter(m.Name, priorityFilter) then
			priority[#priority + 1] = m
		end
	end
	if #priority > 0 then return priority end
	return enemies
end

local function HMZ_collectEnemies(arenaOnly, mobFilter)
	local list = {}
	local roots = {}
	if not arenaOnly then
		local worlds = Workspace:FindFirstChild("Worlds")
		if worlds then
			for _, w in ipairs(worlds:GetChildren()) do
				local e = w:FindFirstChild("Enemies")
				if e then roots[#roots + 1] = e end
			end
		end
	end
	for _, arenaName in ipairs({ "RaidArenas", "DefenseArenas", "TimeTrialArenas" }) do
		local a = Workspace:FindFirstChild(arenaName)
		if a then
			for _, d in ipairs(a:GetDescendants()) do
				if d.Name == "Enemies" and d:IsA("Folder") then roots[#roots + 1] = d end
			end
		end
	end
	for _, root in ipairs(roots) do
		for _, m in ipairs(root:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("EnemyDead") ~= true and m:FindFirstChild("HumanoidRootPart") then
				if HMZ_mobMatchesFilter(m.Name, mobFilter) then
					list[#list + 1] = m
				end
			end
		end
	end
	return list
end

local function HMZ_getAttackRadius()
	local cfg = HMZ_require(ConfigFolder, "RangeUpgradeConfig")
	if not cfg then return 11.14 end
	local level = 1
	local rc = HMZ_require(ClientFolder, "RangeController")
	if rc and rc.GetRangeLevel then
		local ok, lv = pcall(function() return rc:GetRangeLevel() end)
		if ok and type(lv) == "number" then level = lv end
	end
	if cfg.GetRadiusForLevel then
		local ok, radius = pcall(function() return cfg:GetRadiusForLevel("World0", level) end)
		if ok and type(radius) == "number" then return radius end
	end
	return 11.14
end

local function HMZ_getGroundY(position, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	local result = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -120, 0), params)
	if result then return result.Position.Y end
	return position.Y
end

local function HMZ_getFeetOffset()
	local char = HMZ_char()
	local hrp = HMZ_getHRP()
	if not char or not hrp then return 3 end
	local lowest = math.huge
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local bottom = d.Position.Y - d.Size.Y / 2
			if bottom < lowest then lowest = bottom end
		end
	end
	if lowest == math.huge then return 3 end
	return math.max(hrp.Position.Y - lowest, 0.5)
end

local function HMZ_teleportToGroundNear(targetPos, facePos)
	local hrp = HMZ_getHRP()
	local char = HMZ_char()
	if not hrp or not char then return end
	local exclude = { char }
	local groundY = HMZ_getGroundY(targetPos, exclude)
	local feetOffset = HMZ_getFeetOffset()
	local pos = Vector3.new(targetPos.X, groundY + feetOffset, targetPos.Z)
	local look = facePos or targetPos
	local flatLook = Vector3.new(look.X, pos.Y, look.Z)
	if (flatLook - pos).Magnitude < 0.1 then
		flatLook = pos + Vector3.new(0, 0, -1)
	end
	hrp.CFrame = CFrame.lookAt(pos, flatLook)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

local function HMZ_countEnemiesInRange(origin, radius, enemies)
	local count = 0
	for _, m in ipairs(enemies) do
		local th = m:FindFirstChild("HumanoidRootPart")
		if th and (Vector3.new(origin.X, th.Position.Y, origin.Z) - th.Position).Magnitude <= radius then
			count += 1
		end
	end
	return count
end

local function HMZ_scoreTarget(mode, hrp, m, th)
	if mode == "Highest HP" then
		return m:GetAttribute("HealthReal") or 0
	elseif mode == "Lowest HP" then
		return -(m:GetAttribute("HealthReal") or math.huge)
	end
	return -(hrp.Position - th.Position).Magnitude
end

local function HMZ_pickTargetFromList(mode, enemies)
	local hrp = HMZ_getHRP()
	if not hrp then return nil end
	local best, bestScore
	for _, m in ipairs(enemies) do
		local th = m:FindFirstChild("HumanoidRootPart")
		if th then
			local score = HMZ_scoreTarget(mode, hrp, m, th)
			if not bestScore or score > bestScore then
				bestScore = score
				best = m
			end
		end
	end
	return best
end

local function HMZ_pickTarget(mode, mobFilter, arenaOnly, priorityFilter)
	local enemies = HMZ_collectEnemies(arenaOnly, mobFilter)
	local pool = HMZ_splitPriorityEnemies(enemies, priorityFilter)
	return HMZ_pickTargetFromList(mode or "Nearest", pool)
end

local function HMZ_pickIntelligentTarget(mobFilter, arenaOnly, priorityFilter)
	local radius = HMZ_getAttackRadius()
	local enemies = HMZ_collectEnemies(arenaOnly, mobFilter)
	local pool = HMZ_splitPriorityEnemies(enemies, priorityFilter)
	if #pool == 0 then return nil, radius end
	local best, bestCount
	for _, m in ipairs(pool) do
		local th = m:FindFirstChild("HumanoidRootPart")
		if th then
			local count = HMZ_countEnemiesInRange(th.Position, radius, pool)
			if not bestCount or count > bestCount then
				bestCount = count
				best = m
			end
		end
	end
	return best, radius
end

local function HMZ_farmTarget(mobFilter, arenaOnly, targetMode, intelligent, priorityFilter)
	if intelligent then
		return HMZ_pickIntelligentTarget(mobFilter, arenaOnly, priorityFilter)
	end
	return HMZ_pickTarget(targetMode or "Nearest", mobFilter, arenaOnly, priorityFilter), HMZ_getAttackRadius()
end

local function HMZ_attackTarget(target, attackRadius)
	if not target then
		HMZ_fire("Click")
		return
	end
	local th = target:FindFirstChild("HumanoidRootPart")
	if not th then
		HMZ_fire("Click")
		return
	end
	local hrp = HMZ_getHRP()
	if not hrp then return end
	local radius = attackRadius or HMZ_getAttackRadius()
	local standDist = math.clamp(radius * 0.25, 2, 6)
	local flatDelta = Vector3.new(hrp.Position.X - th.Position.X, 0, hrp.Position.Z - th.Position.Z)
	if flatDelta.Magnitude < 0.5 then
		flatDelta = Vector3.new(0, 0, standDist)
	else
		flatDelta = flatDelta.Unit * standDist
	end
	local standPos = th.Position + flatDelta
	HMZ_teleportToGroundNear(standPos, th.Position)
	HMZ_fire("Click")
end

local function HMZ_currentWorld()
	return HMZ_invoke("GetCurrentWorld")
end

local function HMZ_travelWorld(worldId)
	if not worldId then return end
	if HMZ_isLoading() then return end
	local cur = HMZ_currentWorld()
	if tostring(cur) == tostring(worldId) then return end
	HMZ_fire("RequestChangeWorld", tonumber(worldId))
	HMZ_waitLoad(8)
end

local function HMZ_getActiveGamemode()
	if type(Cache.TrialState) == "table" and Cache.TrialState.Room then
		return "Trial"
	end
	if type(Cache.DefenseState) == "table" and Cache.DefenseState.Wave then
		return "Defense"
	end
	if type(Cache.RaidState) == "table" and Cache.RaidState.Wave then
		if Cache.RaidActiveKey == "World5" then return "Gate" end
		if Cache.RaidActiveKey == "World6" then return "InfiniteCastle" end
		return "Raid"
	end
	return nil
end

local HMZ_PRIORITY_ORDER = {
	"Trial",
	"Gate",
	"Crow",
	"Defense",
	"InfiniteCastle",
	"Raid",
	"Quest",
	"SideQuest",
	"Star",
	"Mob",
}

local function HMZ_getResourceCount(itemId)
	Cache._ResourceCache = Cache._ResourceCache or {}
	local now = os.clock()
	if not Cache._ResourceCacheTime or now - Cache._ResourceCacheTime > 2 then
		Cache._ResourceCacheTime = now
		local data = HMZ_invoke("GetPlayerData")
		Cache._ResourceCacheData = type(data) == "table" and data or {}
	end
	local data = Cache._ResourceCacheData or {}
	local v = data[itemId]
	if type(v) == "number" then return v end
	return 0
end

local function HMZ_getSelectedRaidKey()
	local sel = Cache.GamemodeSel and Cache.GamemodeSel.Raid
	return sel and sel.value
end

local function HMZ_isInfiniteCastleKey(key)
	return tostring(key or "") == "World6"
end

local function HMZ_wantsTrial()
	if HMZ_getActiveGamemode() == "Trial" then
		return S.FarmTrial == true or S.JoinTrial == true or S.JoinOpenTrial == true
	end
	if S.JoinOpenTrial and HMZ_hasOpenTrial and HMZ_hasOpenTrial() then return true end
	if S.JoinTrial and HMZ_isTrialOpen and HMZ_isTrialOpen() then return true end
	if Cache.AutoLeaveForTrial and HMZ_hasOpenTrial and HMZ_hasOpenTrial() then return true end
	return false
end

local function HMZ_wantsGate()
	if HMZ_getActiveGamemode() == "Gate" then
		return S.FarmGate == true or S.AutoGate == true
	end
	if S.AutoGate then
		local state = HMZ_invoke("GetRaidGateState", "World5")
		if type(state) == "table" and state.IsOpen then return true end
	end
	return false
end

local function HMZ_wantsCrow()
	return S.AutoCrow == true
end

local function HMZ_wantsDefense()
	if HMZ_getActiveGamemode() == "Defense" then
		return S.FarmDefense == true or S.JoinDefense == true or S.JoinOpenDefense == true
	end
	if S.JoinDefense or S.JoinOpenDefense then return true end
	return false
end

local function HMZ_wantsInfiniteCastle()
	local gm = HMZ_getActiveGamemode()
	if gm == "InfiniteCastle" then
		return S.FarmRaid == true or S.JoinRaid == true or S.JoinOpenRaid == true
	end
	local raidKey = HMZ_getSelectedRaidKey()
	local hasKeys = HMZ_getResourceCount("InfinityCastleKey") >= 1
	if S.JoinRaid and HMZ_isInfiniteCastleKey(raidKey) and hasKeys then return true end
	if S.JoinOpenRaid and hasKeys then
		if HMZ_isInfiniteCastleKey(raidKey) then return true end
		local pool = Cache.OpenRaids
		if type(pool) == "table" and pool.World6 == true then return true end
	end
	return false
end

local function HMZ_wantsRaid()
	local gm = HMZ_getActiveGamemode()
	if gm == "Raid" then
		return S.FarmRaid == true or S.JoinRaid == true or S.JoinOpenRaid == true
	end
	local raidKey = HMZ_getSelectedRaidKey()
	if HMZ_isInfiniteCastleKey(raidKey) then return false end
	if S.JoinRaid then
		if tostring(raidKey or "") == "World0" then
			if HMZ_getResourceCount("TimelessRaidKey") >= 1 or HMZ_getResourceCount("NinjaRaidKey") >= 1 then return true end
		elseif tostring(raidKey or "") == "World1" then
			if HMZ_getResourceCount("NinjaRaidKey") >= 1 then return true end
		else
			return true
		end
	end
	if S.JoinOpenRaid then
		local pool = Cache.OpenRaids
		if type(pool) == "table" then
			for k, v in pairs(pool) do
				if v == true and type(k) == "string" and not HMZ_isInfiniteCastleKey(k) then
					return true
				end
			end
		end
	end
	if S.FarmRaid and not HMZ_isInfiniteCastleKey(raidKey) then return true end
	return false
end

local function HMZ_wantsQuest()
	return S.AutoQuest == true
end

local function HMZ_wantsSideQuest()
	return S.AutoSideQuest == true
end

local function HMZ_wantsStar()
	return S.AutoStar == true
end

local function HMZ_wantsMob()
	return S.AutoFarmMob == true
end

local HMZ_WANTS = {
	Trial = HMZ_wantsTrial,
	Gate = HMZ_wantsGate,
	Crow = HMZ_wantsCrow,
	Defense = HMZ_wantsDefense,
	InfiniteCastle = HMZ_wantsInfiniteCastle,
	Raid = HMZ_wantsRaid,
	Quest = HMZ_wantsQuest,
	SideQuest = HMZ_wantsSideQuest,
	Star = HMZ_wantsStar,
	Mob = HMZ_wantsMob,
}

local function HMZ_getActivePriorityFeature()
	for _, id in ipairs(HMZ_PRIORITY_ORDER) do
		local fn = HMZ_WANTS[id]
		if fn and fn() then
			return id
		end
	end
	return nil
end

HMZ_canRunFeature = function(id)
	if not id then return true end
	local active = HMZ_getActivePriorityFeature()
	if not active then return true end
	return active == id
end

local function HMZ_trialSession()
	Cache.TrialSession = Cache.TrialSession or {}
	return Cache.TrialSession
end

local function HMZ_isTrialOpen()
	local pool = Cache.OpenTrials
	if type(pool) ~= "table" then return false end
	if pool.IsOpen == true then return true end
	if pool.ScheduleOpen == true then return true end
	return false
end

local function HMZ_hasOpenTrial()
	if not HMZ_isTrialOpen() then return false, nil end
	local session = HMZ_trialSession()
	if session.handled or session.inTrial or session.joining or session.resuming then return false, nil end
	if session.leavingForTrial then return false, nil end
	local pool = Cache.OpenTrials
	if type(pool.OpenTrialKey) == "string" and pool.OpenTrialKey ~= "" then
		return true, pool.OpenTrialKey
	end
	for k, v in pairs(pool) do
		if v == true and type(k) == "string" and k ~= "IsOpen" and k ~= "ScheduleOpen" then
			return true, k
		end
	end
	return false, nil
end

local function HMZ_saveTrialResume()
	if Cache.TrialResume then return end
	local raidSel = Cache.GamemodeSel and Cache.GamemodeSel.Raid
	local defSel = Cache.GamemodeSel and Cache.GamemodeSel.Defense
	Cache.TrialResume = {
		worldId = HMZ_currentWorld(),
		mode = HMZ_getActiveGamemode(),
		raidKey = (raidSel and raidSel.value) or Cache.RaidActiveKey,
		defenseKey = (defSel and defSel.value) or Cache.DefenseActiveKey,
		joinRaid = S.JoinRaid == true,
		joinOpenRaid = S.JoinOpenRaid == true,
		joinDefense = S.JoinDefense == true,
		joinOpenDefense = S.JoinOpenDefense == true,
	}
end

local function HMZ_resumeAfterTrial()
	local resume = Cache.TrialResume
	if not resume then return end
	Cache.TrialResume = nil
	local session = HMZ_trialSession()
	session.resuming = true
	task.spawn(function()
		if HMZ_isLoading() then HMZ_waitLoad(20) end
		task.wait(3)
		if resume.worldId ~= nil then
			HMZ_travelWorld(resume.worldId)
			task.wait(2)
		end
		if HMZ_isLoading() then HMZ_waitLoad(20) end
		local mode = resume.mode
		if mode == "InfiniteCastle" or mode == "Gate" or mode == "Raid" then
			if resume.raidKey then
				HMZ_applyLoadout("Raid")
				if resume.joinOpenRaid then
					HMZ_fire("RaidJoin", "Join", resume.raidKey)
				elseif resume.joinRaid then
					HMZ_fire("RaidJoin", "Create", resume.raidKey)
				end
			end
		elseif mode == "Defense" then
			if resume.defenseKey then
				HMZ_applyLoadout("Defense")
				if resume.joinOpenDefense then
					HMZ_fire("DefenseJoin", "Join", resume.defenseKey)
				elseif resume.joinDefense then
					HMZ_fire("DefenseJoin", "Create", resume.defenseKey)
				end
			end
		end
		task.wait(4)
		session.resuming = false
	end)
end

local function HMZ_onTrialFinished()
	local session = HMZ_trialSession()
	if session.finishLock then return end
	session.finishLock = true
	session.handled = true
	session.inTrial = false
	session.joining = false
	session.leavingForTrial = false
	task.delay(4, function()
		HMZ_resumeAfterTrial()
		task.delay(6, function()
			session.finishLock = false
		end)
	end)
end

local function HMZ_leaveActiveGamemode(mode)
	mode = mode or HMZ_getActiveGamemode()
	if not mode or mode == "Trial" then return false end
	local bridge = ({
		Raid = "RaidLeave",
		Defense = "DefenseLeave",
		Gate = "RaidLeave",
		InfiniteCastle = "RaidLeave",
	})[mode]
	if not bridge then return false end
	HMZ_fire(bridge)
	return true
end

local function HMZ_prepareTrialLeave()
	if not Cache.AutoLeaveForTrial then return end
	local mode = HMZ_getActiveGamemode()
	if not mode or mode == "Trial" then return end
	local session = HMZ_trialSession()
	if session.leavingForTrial then return end
	session.leavingForTrial = true
	HMZ_saveTrialResume()
	HMZ_leaveActiveGamemode(mode)
	task.delay(3, function()
		session.leavingForTrial = false
	end)
end

local function HMZ_tryJoinOpenTrial(trialKey)
	if HMZ_isLoading() then return end
	if HMZ_getActiveGamemode() == "Trial" then return end
	local session = HMZ_trialSession()
	if session.handled or session.inTrial or session.joining or session.leavingForTrial or session.resuming then return end
	if not trialKey then
		local open
		open, trialKey = HMZ_hasOpenTrial()
		if not open or not trialKey then return end
	elseif not HMZ_isTrialOpen() or session.handled then
		return
	end
	local now = os.clock()
	if session.lastJoinAttempt and now - session.lastJoinAttempt < 10 then return end
	session.lastJoinAttempt = now
	session.joining = true
	HMZ_saveTrialResume()
	HMZ_applyLoadout("Trial")
	HMZ_fire("TimeTrialJoin", "Join", trialKey)
	task.delay(12, function()
		if not session.inTrial then
			session.joining = false
			session.handled = true
		end
	end)
end

local StatOptions = { "Power", "Yen", "Damage", "XP", "Drop", "Luck" }
local UpgradeOptions = { "Damage", "Power", "Yen", "Xp", "Drop", "Luck" }
local StatPointOptions = { "Power", "Yen", "Damage", "Luck", "Xp", "Drop" }

local function HMZ_applyLoadout(context)
	if not S.AutoLoadout then return end
	local stat = Cache.LoadoutMap and Cache.LoadoutMap[context]
	if not stat or stat == "None" then return end
	if Cache.LastLoadout[context] and os.clock() - Cache.LastLoadout[context] < 4 then return end
	Cache.LastLoadout[context] = os.clock()
	HMZ_fire("EquipBestLoadout", stat)
end

HMZ_connect("RaidActiveStatus", function(map)
	if type(map) == "table" then Cache.OpenRaids = map end
end)
HMZ_connect("DefenseActiveStatus", function(map)
	if type(map) == "table" then Cache.OpenDefenses = map end
end)
HMZ_connect("TimeTrialActiveStatus", function(count, info)
	if type(info) ~= "table" then return end
	Cache.OpenTrials = info
	local session = HMZ_trialSession()
	if info.IsOpen == true or info.ScheduleOpen == true then
		local key = info.OpenTrialKey
		if type(key) == "string" and key ~= "" and session.openKey ~= key then
			session.openKey = key
			session.handled = false
			session.finishLock = false
		end
	else
		session.openKey = nil
		session.handled = true
		session.inTrial = false
		session.joining = false
		session.leavingForTrial = false
	end
end)
HMZ_connect("RaidState", function(state)
	if type(state) == "table" then Cache.RaidState = state end
end)
HMZ_connect("RaidMapReady", function(key)
	if type(key) == "string" then Cache.RaidActiveKey = key end
end)
HMZ_connect("RaidEnded", function()
	Cache.RaidActiveKey = nil
	Cache.RaidState = {}
end)
HMZ_connect("DefenseState", function(state)
	if type(state) == "table" then Cache.DefenseState = state end
end)
HMZ_connect("DefenseMapReady", function(key)
	if type(key) == "string" then Cache.DefenseActiveKey = key end
end)
HMZ_connect("DefenseEnded", function()
	Cache.DefenseActiveKey = nil
	Cache.DefenseState = {}
end)
HMZ_connect("TimeTrialState", function(state)
	if type(state) == "table" then
		Cache.TrialState = state
		local session = HMZ_trialSession()
		if state.Room then
			session.inTrial = true
			session.joining = false
		elseif session.inTrial then
			session.inTrial = false
			HMZ_onTrialFinished()
		end
	else
		Cache.TrialState = {}
		local session = HMZ_trialSession()
		if session.inTrial then
			session.inTrial = false
			HMZ_onTrialFinished()
		end
	end
end)
HMZ_connect("TimeTrialMapReady", function(key)
	if type(key) == "string" then
		Cache.TrialActiveKey = key
		local session = HMZ_trialSession()
		session.inTrial = true
		session.joining = false
	end
end)
HMZ_connect("TimeTrialEnded", function()
	Cache.TrialActiveKey = nil
	Cache.TrialState = {}
	HMZ_onTrialFinished()
end)
HMZ_connect("PotionState", function(state)
	if type(state) == "table" then Cache.Potions = state end
end)
HMZ_connect("GachaResult", function(payload)
	if not S.AutoGachaStopDivine then return end
	if type(payload) ~= "table" then return end
	local function has(p)
		if p.RolledRarity == "Divine" then return true end
		if type(p.RolledItem) == "table" and p.RolledItem.Rarity == "Divine" then return true end
		if type(p.Rolls) == "table" then
			for _, r in pairs(p.Rolls) do
				if type(r) == "table" and (r.RolledRarity == "Divine" or (type(r.RolledItem) == "table" and r.RolledItem.Rarity == "Divine")) then
					return true
				end
			end
		end
		return false
	end
	if has(payload) then
		S.AutoGacha = false
		HMZ_notify("HMZ Hub", "Stopped on Divine Gacha", 6)
	end
end)
HMZ_connect("TitanResult", function(payload)
	if not S.TitanStopSecret then return end
	if type(payload) ~= "table" then return end
	local hit = payload.RolledRarity == "Secret"
	if not hit and type(payload.RolledItem) == "table" and payload.RolledItem.Rarity == "Secret" then hit = true end
	if not hit and type(payload.Rolls) == "table" then
		for _, r in pairs(payload.Rolls) do
			if type(r) == "table" and (r.RolledRarity == "Secret" or (type(r.RolledItem) == "table" and r.RolledItem.Rarity == "Secret")) then hit = true end
		end
	end
	if hit then
		S.TitanRoll = false
		HMZ_notify("HMZ Hub", "Stopped on Secret Titan", 6)
	end
end)

local function HMZ_webhook(content)
	if not S.Webhook or not Cache.WebhookUrl or Cache.WebhookUrl == "" then return end
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if not req then return end
	pcall(function()
		req({
			Url = Cache.WebhookUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({ content = content }),
		})
	end)
end

HMZ_connect("DropNotify", function(data)
	if not S.WebhookDrops then return end
	local txt = type(data) == "table" and (data.Message or data.Name or HttpService:JSONEncode(data)) or tostring(data)
	HMZ_webhook("**Drop:** " .. txt)
end)
HMZ_connect("PetAnnouncement", function(data)
	if not S.WebhookDrops then return end
	local txt = type(data) == "table" and (data.Message or data.Name or HttpService:JSONEncode(data)) or tostring(data)
	HMZ_webhook("**Pet:** " .. txt)
end)
HMZ_connect("SwordPassiveResult", function(success, errCode, state)
	if not S.AutoSwordPassive then return end
	if success ~= true then
		if errCode == "not_enough_items" or errCode == "sword_not_owned" or errCode == "world_locked" then
			S.AutoSwordPassive = false
			HMZ_setState("AutoSwordPassive", false, 1.1, HMZ_autoSwordPassiveTick)
		end
		return
	end
	task.defer(function()
		task.wait(0.08)
		local spc = HMZ_require(ConfigFolder, "SwordPassiveConfig")
		local passives = nil
		if type(state) == "table" and type(state.SwordPassives) == "table" then
			passives = state.SwordPassives
		else
			local data = HMZ_invoke("GetPlayerData")
			passives = type(data) == "table" and data.SwordPassives or {}
		end
		local rolled = Cache.SwordPassiveRolling
		Cache.SwordPassiveRolling = nil
		if not rolled then return end
		if HMZ_swordHasTargetPassive(rolled, passives, spc, Cache.SwordPassiveTargetId) then
			HMZ_advancePassiveSword()
		elseif not Cache.SwordPassiveTargetId or Cache.SwordPassiveTargetId == "None" then
			HMZ_advancePassiveSword()
		end
	end)
end)

HMZ_waitReady()

Window = MacLib:Window({
	Title = "HMZ Hub",
	Subtitle = HMZ_ACTIVE_GAME.Name,
	Size = UDim2.fromOffset(880, 600),
	DragStyle = 1,
	ShowUserInfo = true,
	AcrylicBlur = true,
})

Cache.UIBlur = HMZ_savedGet("settings", "UIBlur", true)
Cache.Notifications = HMZ_savedGet("settings", "Notifications", true)

Window:GlobalSetting({
	Name = "UI Blur",
	Default = Cache.UIBlur,
	Callback = function(on)
		Cache.UIBlur = on
		HMZ_savedSet("settings", "UIBlur", on)
		pcall(function() Window:SetAcrylicBlurState(on) end)
	end,
})

Window:GlobalSetting({
	Name = "Notifications",
	Default = Cache.Notifications,
	Callback = function(on)
		Cache.Notifications = on
		HMZ_savedSet("settings", "Notifications", on)
		pcall(function() Window:SetNotificationsState(on) end)
	end,
})

HMZ_setupWindowDrag()

local function HMZ_buildUI()
local Tabs = Window:TabGroup()

local TabMain = Tabs:Tab({ Name = "Main" })
local TabGamemode = Tabs:Tab({ Name = "Gamemode" })
local TabLoadout = Tabs:Tab({ Name = "Loadout / Boost" })
local TabShop = Tabs:Tab({ Name = "Shop" })
local TabUpgrade = Tabs:Tab({ Name = "Map Upgrade" })
local TabTeleport = Tabs:Tab({ Name = "Teleport" })
local TabWebhook = Tabs:Tab({ Name = "Webhook" })
local TabSettings = Tabs:Tab({ Name = "Settings" })

local mainLeft = HMZ_wrapSection(TabMain:Section({ Side = "Left" }))
local mainRight = HMZ_wrapSection(TabMain:Section({ Side = "Right" }))

mainLeft:Header({ Text = "Auto Farm Mob" })
mainLeft:Paragraph({
	Header = "Priority",
	Body = "Trial > Gate > Crow > Defense > Infinite Castle > Raid > Quest > Side Quest > Star > Mob",
})

mainLeft:Slider({
	Name = "World Teleport Delay",
	Default = 3,
	Minimum = 0,
	Maximum = 15,
	DisplayMethod = "Round",
	Callback = function(v) Cache.WorldDelay = v end,
}, "WorldDelay")

local mobWorldDD
local mobMobDD
mobWorldDD = mainLeft:Dropdown({
	Name = "World",
	Search = true,
	Options = WorldLabels,
	Default = 1,
	Callback = function(v)
		Cache.FarmWorldName = v
		Cache.FarmWorldId = WorldMap[v]
		local mobOpts = HMZ_mobOptions(WorldMap[v])
		if mobMobDD then
			pcall(function() mobMobDD:ClearOptions() end)
			pcall(function() mobMobDD:InsertOptions(mobOpts) end)
		end
	end,
}, "FarmWorld")

mobMobDD = mainLeft:Dropdown({
	Name = "Mob",
	Search = true,
	Multi = true,
	Required = false,
	Options = HMZ_mobOptions(WorldMap[WorldLabels[1]]),
	Default = { "Any" },
	Callback = function(v) Cache.FarmMob = v end,
}, "FarmMob")

mainLeft:Dropdown({
	Name = "Target Mode",
	Options = { "Nearest", "Highest HP", "Lowest HP" },
	Default = 1,
	Callback = function(v) Cache.FarmTargetMode = v end,
}, "FarmTargetMode")

mainLeft:Toggle({
	Name = "Farm Intelligent",
	Default = false,
	Callback = function(on) Cache.FarmIntelligent = on end,
}, "FarmIntelligent")

mainLeft:Toggle({
	Name = "Auto Farm Mob",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoFarmMob", on, 0.3, function()
			if not HMZ_canRunFeature("Mob") then return end
			if Cache.FarmWorldId then HMZ_travelWorld(Cache.FarmWorldId) end
			HMZ_applyLoadout("MobQuest")
			local t, radius = HMZ_farmTarget(Cache.FarmMob, false, Cache.FarmTargetMode, Cache.FarmIntelligent)
			HMZ_attackTarget(t, radius)
		end)
	end,
}, "AutoFarmMob")

mainLeft:Toggle({
	Name = "Auto Crow",
	Default = false,
	Callback = function(on)
		if on then
			Cache.CrowHadAny = false
			Cache.CrowEmptySince = nil
		end
		HMZ_setState("AutoCrow", on, 1, HMZ_autoCrowTick)
	end,
}, "AutoCrow")

mainLeft:Toggle({
	Name = "Hop For Auto Crow",
	Default = false,
	Callback = function(on)
		Cache.HopForAutoCrow = on
		if on then
			Cache.CrowHadAny = false
			Cache.CrowEmptySince = nil
		end
	end,
}, "HopForAutoCrow")

mainLeft:Toggle({
	Name = "Auto Quest",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoQuest", on, 1, function()
			if not HMZ_canRunFeature("Quest") then return end
			HMZ_fire("QuestRequestState")
			task.wait(0.3)
			HMZ_fire("QuestCollect")
		end)
	end,
}, "AutoQuest")

mainLeft:Toggle({
	Name = "Auto Side Quest",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoSideQuest", on, 1.5, function()
			if not HMZ_canRunFeature("SideQuest") then return end
			HMZ_fire("SideQuestRequestState", "__active")
			task.wait(0.3)
			for _, qid in ipairs({ "NinjaQuest", "TitanQuest", "SlayerQuest" }) do
				HMZ_fire("SideQuestAcceptRequest", qid)
			end
		end)
	end,
}, "AutoSideQuest")

mainLeft:Toggle({
	Name = "Auto Buy + Travel Worlds",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoBuyWorld", on, 5, function()
			for _, label in ipairs(WorldLabels) do
				HMZ_fire("BuyWorld", tonumber(WorldMap[label]))
				task.wait(0.4)
			end
		end)
	end,
}, "AutoBuyWorld")

mainRight:Header({ Text = "General" })

mainRight:Button({
	Name = "Redeem All Codes Now",
	Callback = function()
		task.spawn(function()
			HMZ_notify("HMZ Hub", "Redeeming all codes...", 4)
			local n = HMZ_redeemAll(function() return true end)
			HMZ_notify("HMZ Hub", "Sent " .. n .. " new codes", 5)
		end)
	end,
})

mainRight:Toggle({
	Name = "Auto Redeem Codes",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoRedeem", on, 300, function()
			HMZ_redeemAll(function() return S.AutoRedeem end)
		end)
	end,
}, "AutoRedeem")

mainRight:Toggle({
	Name = "Auto Rank Up",
	Default = false,
	Callback = function(on)
		S.AutoRankUp = on
		HMZ_fire("RankUp", "SetAutoRankUp", on)
	end,
}, "AutoRankUp")

mainRight:Toggle({
	Name = "Equip Best Avatar (Auto)",
	Default = false,
	Callback = function(on)
		S.AutoAvatar = on
		HMZ_fire("AutoAvatarBuffSet", on)
	end,
}, "AutoAvatar")

mainRight:Toggle({
	Name = "Auto Arise",
	Default = false,
	Callback = function(on)
		S.AutoArise = on
		HMZ_fire("RaidAutoArise", on)
	end,
}, "AutoArise")

mainRight:Toggle({
	Name = "Auto Daily Chest",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoDailyChest", on, 30, function()
			HMZ_fire("ChestClaim", "Daily")
		end)
	end,
}, "AutoDailyChest")

mainRight:Toggle({
	Name = "Auto Group Chest",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoGroupChest", on, 30, function()
			HMZ_fire("ChestClaim", "Group")
		end)
	end,
}, "AutoGroupChest")

mainRight:Toggle({
	Name = "Auto Claim Rewards (Daily/Time)",
	Default = false,
	Callback = function(on)
		S.AutoRewards = on
		HMZ_fire("AutoClaimRewardsSet", on)
		if on then
			HMZ_invoke("ClaimAllDailyRewards")
			HMZ_invoke("ClaimAllTimeRewards")
		end
	end,
}, "AutoRewards")

local gmLeft = HMZ_wrapSection(TabGamemode:Section({ Side = "Left" }))
local gmRight = HMZ_wrapSection(TabGamemode:Section({ Side = "Right" }))

local function HMZ_farmFeatureId()
	local gm = HMZ_getActiveGamemode()
	if gm == "Trial" then return "Trial" end
	if gm == "Gate" then return "Gate" end
	if gm == "Defense" then return "Defense" end
	if gm == "InfiniteCastle" then return "InfiniteCastle" end
	if gm == "Raid" then return "Raid" end
	return "Raid"
end

local function HMZ_joinRaidFeatureId(raidKey)
	if HMZ_isInfiniteCastleKey(raidKey) then return "InfiniteCastle" end
	return "Raid"
end

local function HMZ_gamemodeBlock(section, title, joinBridge, leaveBridge, configName, getAllMethod, targetKey, farmKey, joinKey, openKey, openCache, useCreate)
	section:Header({ Text = title })
	local labels, map = {}, {}
	local c = HMZ_require(ConfigFolder, configName)
	if c and c[getAllMethod] then
		local ok, all = pcall(function() return c[getAllMethod](c) end)
		if ok and type(all) == "table" then labels, map = HMZ_namedOptions(all) end
	end
	if #labels == 0 then labels = { "World0" } end
	local selected = { value = map[labels[1]] or labels[1] }
	Cache.GamemodeSel = Cache.GamemodeSel or {}
	Cache.GamemodeSel[title] = selected
	section:Dropdown({
		Name = title .. " Selection",
		Options = labels,
		Default = 1,
		Callback = function(v)
			selected.value = map[v] or v
			HMZ_savedSet("gamemodeValues", title, selected.value)
		end,
	}, title .. "Sel")
	section:Toggle({
		Name = "Auto Join " .. title,
		Default = false,
		Callback = function(on)
			HMZ_setState(joinKey, on, 3, function()
				if HMZ_isLoading() then return end
				if title == "Trial" then
					if not HMZ_canRunFeature("Trial") then return end
					if HMZ_getActiveGamemode() == "Trial" then return end
					local session = HMZ_trialSession()
					if session.handled or session.inTrial or session.joining or session.leavingForTrial or session.resuming then return end
					if not HMZ_isTrialOpen() then return end
					if Cache.AutoLeaveForTrial then
						HMZ_prepareTrialLeave()
					end
					HMZ_tryJoinOpenTrial(selected.value)
					return
				end
				if title == "Raid" then
					local feature = HMZ_joinRaidFeatureId(selected.value)
					if not HMZ_canRunFeature(feature) then return end
					if feature == "InfiniteCastle" and HMZ_getResourceCount("InfinityCastleKey") < 1 then return end
				elseif title == "Defense" then
					if not HMZ_canRunFeature("Defense") then return end
				end
				HMZ_applyLoadout(title)
				if useCreate then
					HMZ_fire(joinBridge, "Create", selected.value)
				else
					HMZ_fire(joinBridge, "Join", selected.value)
				end
			end)
		end,
	}, joinKey)
	if openKey then
		section:Toggle({
			Name = "Auto Join Open " .. title .. "s",
			Default = false,
			Callback = function(on)
				HMZ_setState(openKey, on, 3, function()
					if HMZ_isLoading() then return end
					local pool = openCache == "Trial" and Cache.OpenTrials or (openCache == "Defense" and Cache.OpenDefenses or Cache.OpenRaids)
					if type(pool) ~= "table" then return end
					if openCache == "Trial" then
						if not HMZ_canRunFeature("Trial") then return end
						if not HMZ_hasOpenTrial() then return end
						if Cache.AutoLeaveForTrial then
							HMZ_prepareTrialLeave()
						end
						HMZ_tryJoinOpenTrial()
						return
					end
					if openCache == "Defense" then
						if not HMZ_canRunFeature("Defense") then return end
					end
					for k, v in pairs(pool) do
						if v == true and type(k) == "string" then
							if openCache == "Raid" then
								local feature = HMZ_joinRaidFeatureId(k)
								if not HMZ_canRunFeature(feature) then return end
								if feature == "InfiniteCastle" and HMZ_getResourceCount("InfinityCastleKey") < 1 then return end
							end
							HMZ_applyLoadout(title)
							HMZ_fire(joinBridge, "Join", k)
							task.wait(1)
							return
						end
					end
				end)
			end,
		}, openKey)
	end
	section:Dropdown({
		Name = title .. " Target",
		Options = { "Nearest", "Highest HP", "Lowest HP" },
		Default = 1,
		Callback = function(v) Cache[targetKey] = v end,
	}, targetKey)
	section:Toggle({
		Name = "Auto Farm " .. title,
		Default = false,
		Callback = function(on)
			HMZ_setState(farmKey, on, 0.3, function()
				local feature
				if title == "Trial" then
					feature = "Trial"
				elseif title == "Defense" then
					feature = "Defense"
				elseif title == "Raid" then
					feature = HMZ_farmFeatureId()
				else
					feature = title
				end
				if not HMZ_canRunFeature(feature) then return end
				local t, radius = HMZ_farmTarget(nil, true, Cache[targetKey], Cache.FarmIntelligent)
				HMZ_attackTarget(t, radius)
			end)
		end,
	}, farmKey)
end

HMZ_gamemodeBlock(gmLeft, "Trial", "TimeTrialJoin", "TimeTrialLeave", "TimeTrialConfig", "GetAllTrials", "TrialTarget", "FarmTrial", "JoinTrial", "JoinOpenTrial", "Trial", false)

gmLeft:Toggle({
	Name = "Auto Leave Gamemode For Trial",
	Default = false,
	Callback = function(on)
		Cache.AutoLeaveForTrial = on
		HMZ_setState("AutoLeaveForTrial", on, 2, function()
			if not Cache.AutoLeaveForTrial then return end
			if not HMZ_hasOpenTrial() then return end
			local mode = HMZ_getActiveGamemode()
			if not mode or mode == "Trial" then return end
			HMZ_prepareTrialLeave()
			if not S.JoinOpenTrial then
				HMZ_tryJoinOpenTrial()
			end
		end)
	end,
}, "AutoLeaveForTrial")
HMZ_gamemodeBlock(gmLeft, "Raid", "RaidJoin", "RaidLeave", "RaidConfig", "GetAllRaids", "RaidTarget", "FarmRaid", "JoinRaid", "JoinOpenRaid", "Raid", true)
HMZ_gamemodeBlock(gmLeft, "Defense", "DefenseJoin", "DefenseLeave", "DefenseConfig", "GetAllDefenses", "DefenseTarget", "FarmDefense", "JoinDefense", "JoinOpenDefense", "Defense", true)

gmLeft:Header({ Text = "Gate" })
gmLeft:Toggle({
	Name = "Auto Gate",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoGate", on, 3, function()
			if not HMZ_canRunFeature("Gate") then return end
			if HMZ_isLoading() then return end
			local state = HMZ_invoke("GetRaidGateState", "World5")
			if type(state) == "table" and state.IsOpen then
				HMZ_applyLoadout("GateE")
				HMZ_fire("RaidGateTeleport", "World5")
			end
		end)
	end,
}, "AutoGate")
gmLeft:Dropdown({
	Name = "Gate Target",
	Options = { "Nearest", "Highest HP", "Lowest HP" },
	Default = 1,
	Callback = function(v) Cache.GateTarget = v end,
}, "GateTarget")
gmLeft:Toggle({
	Name = "Auto Farm Gate",
	Default = false,
	Callback = function(on)
		HMZ_setState("FarmGate", on, 0.3, function()
			if not HMZ_canRunFeature("Gate") then return end
			local t, radius = HMZ_farmTarget(nil, true, Cache.GateTarget, Cache.FarmIntelligent)
			HMZ_attackTarget(t, radius)
		end)
	end,
}, "FarmGate")

gmRight:Header({ Text = "Auto Leave Floor" })
gmRight:Paragraph({
	Header = "Per mode",
	Body = "0 = disabled. Each slider is for one specific gamemode.",
})
gmRight:Toggle({
	Name = "Auto Leave Floor",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoLeaveFloor", on, 1, HMZ_autoLeaveFloorTick)
	end,
}, "AutoLeaveFloor")
HMZ_buildLeaveFloorUI(gmRight)

local ldLeft = HMZ_wrapSection(TabLoadout:Section({ Side = "Left" }))
local ldRight = HMZ_wrapSection(TabLoadout:Section({ Side = "Right" }))

ldLeft:Header({ Text = "Auto Equip Loadout" })
Cache.LoadoutMap = {}
local loadoutContexts = {
	{ key = "MobQuest", label = "Mob / Quest Loadout" },
	{ key = "Star", label = "Star Loadout" },
	{ key = "Raid", label = "Raid Loadout" },
	{ key = "GateS", label = "Gate S Loadout" },
	{ key = "GateA", label = "Gate A Loadout" },
	{ key = "GateB", label = "Gate B Loadout" },
	{ key = "GateC", label = "Gate C Loadout" },
	{ key = "GateD", label = "Gate D Loadout" },
	{ key = "GateE", label = "Gate E Loadout" },
	{ key = "Defense", label = "Defense Loadout" },
	{ key = "Trial", label = "Trial Loadout" },
}
ldLeft:Toggle({
	Name = "Auto Equip Loadout",
	Default = false,
	Callback = function(on) S.AutoLoadout = on end,
}, "AutoLoadout")
for _, ctx in ipairs(loadoutContexts) do
	ldLeft:Dropdown({
		Name = ctx.label,
		Options = { "None", "Power", "Yen", "Damage", "XP", "Drop", "Luck" },
		Default = 1,
		Callback = function(v) Cache.LoadoutMap[ctx.key] = v end,
	}, "LD_" .. ctx.key)
end

ldRight:Header({ Text = "Auto Pause Boost" })
local PotionLabels = HMZ_require(ConfigFolder, "PotionConfig")
PotionLabels = PotionLabels and PotionLabels.Items
local potList = {}
if type(PotionLabels) == "table" then
	for k in pairs(PotionLabels) do potList[#potList + 1] = k end
end
ldRight:Toggle({
	Name = "Auto Pause Boost",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoPause", on, 2, function()
			if Cache.InGamemode then return end
			HMZ_fire("PotionState", { Request = true })
			for id, info in pairs(Cache.Potions) do
				if type(info) == "table" and info.Paused ~= true then
					HMZ_fire("PotionPauseToggle", id)
				end
			end
		end)
	end,
}, "AutoPause")
ldRight:Toggle({
	Name = "Auto Unpause Boost Gamemode",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoUnpause", on, 2, function()
			local active = HMZ_getActiveGamemode()
			Cache.InGamemode = active ~= nil
			if not active then return end
			HMZ_fire("PotionState", { Request = true })
			for id, info in pairs(Cache.Potions) do
				if type(info) == "table" and info.Paused == true then
					HMZ_fire("PotionPauseToggle", id)
				end
			end
		end)
	end,
}, "AutoUnpause")
ldRight:Dropdown({
	Name = "Auto Use Potions",
	Multi = true,
	Search = true,
	Options = potList,
	Callback = function(v) Cache.UsePotions = HMZ_multiToList(v) end,
}, "UsePotions")
ldRight:Toggle({
	Name = "Auto Use Potion",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoUsePotion", on, 5, function()
			if Cache.UsePotions then
				for _, id in ipairs(Cache.UsePotions) do
					HMZ_fire("UsePotion", id, 1)
					task.wait(0.3)
				end
			end
		end)
	end,
}, "AutoUsePotion")

local shopLeft = HMZ_wrapSection(TabShop:Section({ Side = "Left" }))
local shopRight = HMZ_wrapSection(TabShop:Section({ Side = "Right" }))

shopLeft:Header({ Text = "Auto Star" })
local EggLabels, EggMap = HMZ_configOptions("EggsData")
shopLeft:Dropdown({
	Name = "Map",
	Options = EggLabels,
	Default = 1,
	Callback = function(v) Cache.StarEgg = EggMap[v] or v end,
}, "StarEgg")
shopLeft:Toggle({
	Name = "Auto Star",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoStar", on, 0.6, function()
			if not HMZ_canRunFeature("Star") then return end
			HMZ_applyLoadout("Star")
			if Cache.StarEgg then HMZ_fire("OpenEgg", Cache.StarEgg, {}) end
		end)
	end,
}, "AutoStar")

shopLeft:Header({ Text = "Auto Sword" })
local SwordLabels, SwordMap = HMZ_configOptions("SwordConfig", "Swords")
shopLeft:Dropdown({
	Name = "Sword Banner",
	Options = SwordLabels,
	Default = 1,
	Callback = function(v) Cache.SwordBanner = SwordMap[v] or v end,
}, "SwordBanner")
shopLeft:Toggle({
	Name = "Auto Sword",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoSword", on, 0.6, function()
			if Cache.SwordBanner then HMZ_fire("SwordRoll", Cache.SwordBanner) end
		end)
	end,
}, "AutoSword")

shopLeft:Header({ Text = "Auto Sword Passive" })
local spc = HMZ_require(ConfigFolder, "SwordPassiveConfig")
local scfg = HMZ_require(ConfigFolder, "SwordConfig")
local SwordPassiveTargetLabels, SwordPassiveTargetMap = { "None" }, { None = "None" }
if spc and spc.Rarity_Order then
	for _, rarity in ipairs(spc.Rarity_Order) do
		local list = type(spc.GetPassivesByRarity) == "function" and spc:GetPassivesByRarity(rarity) or nil
		if type(list) == "table" then
			for _, passive in ipairs(list) do
				if type(passive) == "table" and passive.Name and not SwordPassiveTargetMap[passive.Name] then
					SwordPassiveTargetLabels[#SwordPassiveTargetLabels + 1] = passive.Name
					SwordPassiveTargetMap[passive.Name] = passive.Id
				end
			end
		end
	end
end
local SwordPassiveRarityOptions = {}
if scfg and scfg.Rarity_Order then
	SwordPassiveRarityOptions = scfg.Rarity_Order
elseif spc and spc.Rarity_Order then
	for _, r in ipairs(spc.Rarity_Order) do
		if r ~= "Divine" then
			SwordPassiveRarityOptions[#SwordPassiveRarityOptions + 1] = r
		end
	end
end
if #SwordPassiveRarityOptions == 0 then
	SwordPassiveRarityOptions = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret" }
end
shopLeft:Dropdown({
	Name = "Sword Rarity",
	Options = SwordPassiveRarityOptions,
	Default = 1,
	Callback = function(v)
		Cache.SwordPassiveRarity = v
		Cache.SwordPassiveIndex = 1
		HMZ_refreshSwordPassiveQueue()
	end,
}, "SwordPassiveRarity")
shopLeft:Dropdown({
	Name = "Stop On Passive",
	Search = true,
	Options = SwordPassiveTargetLabels,
	Default = 1,
	Callback = function(v)
		Cache.SwordPassiveTargetName = v
		Cache.SwordPassiveTargetId = SwordPassiveTargetMap[v]
		Cache.SwordPassiveIndex = 1
		HMZ_refreshSwordPassiveQueue()
	end,
}, "SwordPassiveTarget")
shopLeft:Toggle({
	Name = "Auto Sword Passive",
	Default = false,
	Callback = function(on)
		if on then
			if not Cache.SwordPassiveRarity then
				Cache.SwordPassiveRarity = SwordPassiveRarityOptions[1]
			end
			Cache.SwordPassiveIndex = 1
			HMZ_refreshSwordPassiveQueue()
			if type(Cache.SwordPassiveQueue) ~= "table" or #Cache.SwordPassiveQueue == 0 then
				HMZ_notify("HMZ Hub", "No swords for " .. tostring(Cache.SwordPassiveRarity), 5)
				S.AutoSwordPassive = false
				task.defer(function()
					local el = HMZ_UI.AutoSwordPassive
					if el and el.UpdateState then el:UpdateState(false) end
				end)
				return
			end
			local sk = (spc and spc.SystemKey) or "World6"
			HMZ_fire("SwordPassiveStateRequest", sk)
		end
		HMZ_setState("AutoSwordPassive", on, 1.1, HMZ_autoSwordPassiveTick)
	end,
}, "AutoSwordPassive")

shopLeft:Header({ Text = "Auto Defense Shop" })
local DefShopLabels, DefShopMap = HMZ_shopProducts("DefenseShopConfig", "World4")
shopLeft:Dropdown({
	Name = "Defense Products",
	Multi = true,
	Search = true,
	Options = DefShopLabels,
	Callback = function(v) Cache.DefShopBuy = HMZ_multiToList(v, DefShopMap) end,
}, "DefShopBuy")
shopLeft:Toggle({
	Name = "Auto Defense Shop",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoDefShop", on, 1, function()
			if Cache.DefShopBuy then
				for _, pid in ipairs(Cache.DefShopBuy) do
					HMZ_fire("DefenseShopBuy", "World4", pid)
					task.wait(0.3)
				end
			end
		end)
	end,
}, "AutoDefShop")

shopRight:Header({ Text = "Auto Exchange" })
local exc = HMZ_require(ConfigFolder, "ExchangeConfig")
local ExLabels, ExMap = {}, {}
if exc and exc.Recipes then ExLabels, ExMap = HMZ_namedOptions(exc.Recipes) end
shopRight:Dropdown({
	Name = "Exchange Recipes",
	Multi = true,
	Search = true,
	Options = ExLabels,
	Callback = function(v) Cache.ExchangeBuy = HMZ_multiToList(v, ExMap) end,
}, "ExchangeBuy")
shopRight:Slider({
	Name = "Exchange Amount",
	Default = 10,
	Minimum = 1,
	Maximum = 1000,
	DisplayMethod = "Round",
	Callback = function(v) Cache.ExchangeAmt = v end,
}, "ExchangeAmt")
shopRight:Toggle({
	Name = "Auto Exchange",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoExchange", on, 1, function()
			if Cache.ExchangeBuy then
				for _, rid in ipairs(Cache.ExchangeBuy) do
					HMZ_fire("ExchangeCraftRequest", rid, Cache.ExchangeAmt or 10)
					task.wait(0.3)
				end
			end
		end)
	end,
}, "AutoExchange")

shopRight:Header({ Text = "Auto Potions" })
shopRight:Dropdown({
	Name = "Potions",
	Multi = true,
	Search = true,
	Options = potList,
	Callback = function(v) Cache.ShopPotions = HMZ_multiToList(v) end,
}, "ShopPotions")
shopRight:Toggle({
	Name = "Auto Potions",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoShopPotions", on, 5, function()
			if Cache.ShopPotions then
				for _, id in ipairs(Cache.ShopPotions) do
					HMZ_fire("UsePotion", id, 1)
					task.wait(0.3)
				end
			end
		end)
	end,
}, "AutoShopPotions")

shopRight:Header({ Text = "Auto Trial Shop" })
local TrialShopLabels, TrialShopMap = HMZ_shopProducts("TrialShopConfig", "World0")
shopRight:Dropdown({
	Name = "Trial Products",
	Multi = true,
	Search = true,
	Options = TrialShopLabels,
	Callback = function(v) Cache.TrialShopBuy = HMZ_multiToList(v, TrialShopMap) end,
}, "TrialShopBuy")
shopRight:Toggle({
	Name = "Auto Trial Shop",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoTrialShop", on, 1, function()
			if Cache.TrialShopBuy then
				for _, pid in ipairs(Cache.TrialShopBuy) do
					HMZ_fire("TrialShopBuy", "World0", pid)
					task.wait(0.3)
				end
			end
		end)
	end,
}, "AutoTrialShop")

shopRight:Header({ Text = "Auto Merchant" })
local MerchLabels, MerchMap = HMZ_shopProducts("MerchantConfig", "Merchant")
shopRight:Dropdown({
	Name = "Merchant Items",
	Multi = true,
	Search = true,
	Options = MerchLabels,
	Callback = function(v) Cache.MerchantBuy = HMZ_multiToList(v, MerchMap) end,
}, "MerchantBuy")
shopRight:Toggle({
	Name = "Auto Merchant",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoMerchant", on, 1, function()
			if Cache.MerchantBuy then
				for _, pid in ipairs(Cache.MerchantBuy) do
					HMZ_fire("MerchantBuy", "Merchant", pid)
					task.wait(0.3)
				end
			end
		end)
	end,
}, "AutoMerchant")

shopRight:Header({ Text = "Titan Shop" })
local TitanLabels, TitanMap = HMZ_configOptions("TitansConfig", "Titans")
shopRight:Dropdown({
	Name = "Titan Banner",
	Options = TitanLabels,
	Default = 1,
	Callback = function(v) Cache.TitanBanner = TitanMap[v] or v end,
}, "TitanBanner")
shopRight:Toggle({
	Name = "Stop on Secret Titan",
	Default = true,
	Callback = function(on) S.TitanStopSecret = on end,
}, "TitanStopSecret")
shopRight:Toggle({
	Name = "Auto Titan Roll",
	Default = false,
	Callback = function(on)
		HMZ_setState("TitanRoll", on, 0.6, function()
			if Cache.TitanBanner then HMZ_fire("TitanRoll", Cache.TitanBanner) end
		end)
	end,
}, "TitanRoll")

local upLeft = HMZ_wrapSection(TabUpgrade:Section({ Side = "Left" }))
local upRight = HMZ_wrapSection(TabUpgrade:Section({ Side = "Right" }))

upLeft:Header({ Text = "Auto Upgrade - Upgrades" })
upLeft:Dropdown({
	Name = "Upgrades",
	Multi = true,
	Options = UpgradeOptions,
	Callback = function(v) Cache.Upgrades = HMZ_multiToList(v) end,
}, "Upgrades")
upLeft:Toggle({
	Name = "Auto Upgrade Upgrades",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoUpgrade", on, 0.8, function()
			if Cache.Upgrades then
				for _, id in ipairs(Cache.Upgrades) do
					HMZ_fire("UpgradesRequest", "World0", id)
					task.wait(0.2)
				end
			end
		end)
	end,
}, "AutoUpgrade")

upLeft:Header({ Text = "Auto Upgrade - Castle Upgrades" })
upLeft:Dropdown({
	Name = "Castle Upgrades",
	Multi = true,
	Options = UpgradeOptions,
	Callback = function(v) Cache.CastleUpgrades = HMZ_multiToList(v) end,
}, "CastleUpgrades")
upLeft:Toggle({
	Name = "Auto Upgrade Castle Upgrades",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoCastle", on, 0.8, function()
			if Cache.CastleUpgrades then
				for _, id in ipairs(Cache.CastleUpgrades) do
					HMZ_fire("UpgradesRequest", "World6", id)
					task.wait(0.2)
				end
			end
		end)
	end,
}, "AutoCastle")

upLeft:Header({ Text = "Auto Range Upgrade" })
upLeft:Toggle({
	Name = "Auto Range Upgrade",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoRange", on, 0.8, function()
			HMZ_fire("RangeUpgradeRequest", "World0")
		end)
	end,
}, "AutoRange")

upRight:Header({ Text = "Auto Gacha" })
local GachaLabels, GachaMap = HMZ_configOptions("GachaConfig", "Gachas")
upRight:Dropdown({
	Name = "Banner",
	Options = GachaLabels,
	Default = 1,
	Callback = function(v) Cache.GachaBanner = GachaMap[v] or v end,
}, "GachaBanner")
upRight:Toggle({
	Name = "Stop on Divine Gacha",
	Default = true,
	Callback = function(on) S.AutoGachaStopDivine = on end,
}, "AutoGachaStopDivine")
upRight:Toggle({
	Name = "Auto Gacha",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoGacha", on, 0.6, function()
			if Cache.GachaBanner then HMZ_fire("GachaRoll", Cache.GachaBanner) end
		end)
	end,
}, "AutoGacha")

upRight:Header({ Text = "Auto Passives" })
upRight:Toggle({
	Name = "Auto Passive Roll",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoPassiveRoll", on, 0.8, function()
			HMZ_fire("PlayerPassiveRoll")
		end)
	end,
}, "AutoPassiveRoll")
local ppc = HMZ_require(ConfigFolder, "PlayerPassiveConfig")
local PassiveLabels = {}
if ppc and ppc.GetAllPassives then
	local ok, all = pcall(function() return ppc:GetAllPassives() end)
	if ok and type(all) == "table" then
		for _, p in pairs(all) do
			if type(p) == "table" and (p.Id or p.Name) then PassiveLabels[#PassiveLabels + 1] = p.Id or p.Name end
		end
	end
end
upRight:Dropdown({
	Name = "Equip Passive",
	Search = true,
	Options = PassiveLabels,
	Default = 1,
	Callback = function(v) Cache.EquipPassive = v end,
}, "EquipPassive")
upRight:Toggle({
	Name = "Auto Equip Passive",
	Default = false,
	Callback = function(on)
		HMZ_setState("AutoEquipPassive", on, 3, function()
			if Cache.EquipPassive then HMZ_fire("PlayerPassiveEquip", Cache.EquipPassive) end
		end)
	end,
}, "AutoEquipPassive")

upRight:Header({ Text = "Auto Progression" })
local ProgLabels, ProgMap = HMZ_configOptions("ProgressionConfig", "Progressions")
upRight:Dropdown({
	Name = "Progressions",
	Multi = true,
	Options = ProgLabels,
	Callback = function(v)
		local prev = Cache.ProgSelected or {}
		local now = HMZ_multiToList(v, ProgMap)
		local nowSet = {}
		for _, k in ipairs(now) do nowSet[k] = true end
		if S.AutoProgression then
			for _, k in ipairs(prev) do
				if not nowSet[k] then HMZ_fire("ProgressionAutoSet", k, false) end
			end
			for _, k in ipairs(now) do HMZ_fire("ProgressionAutoSet", k, true) end
		end
		Cache.ProgSelected = now
	end,
}, "ProgSelected")
upRight:Toggle({
	Name = "Auto Progression",
	Default = false,
	Callback = function(on)
		S.AutoProgression = on
		if Cache.ProgSelected then
			for _, k in ipairs(Cache.ProgSelected) do
				HMZ_fire("ProgressionAutoSet", k, on)
			end
		end
	end,
}, "AutoProgression")

upRight:Header({ Text = "Auto Stat Point" })
upRight:Dropdown({
	Name = "Stat",
	Options = StatPointOptions,
	Default = 1,
	Callback = function(v)
		if S.AutoStatPoint and Cache.StatPoint and Cache.StatPoint ~= v then
			HMZ_fire("AutoStatPointSet", Cache.StatPoint, false)
		end
		Cache.StatPoint = v
		if S.AutoStatPoint then HMZ_fire("AutoStatPointSet", v, true) end
	end,
}, "StatPoint")
upRight:Toggle({
	Name = "Auto Stat Point",
	Default = false,
	Callback = function(on)
		S.AutoStatPoint = on
		if Cache.StatPoint then HMZ_fire("AutoStatPointSet", Cache.StatPoint, on) end
	end,
}, "AutoStatPoint")

local tpLeft = HMZ_wrapSection(TabTeleport:Section({ Side = "Left" }))
local tpRight = HMZ_wrapSection(TabTeleport:Section({ Side = "Right" }))

tpLeft:Header({ Text = "Worlds" })
tpLeft:Dropdown({
	Name = "World",
	Search = true,
	Options = WorldLabels,
	Default = 1,
	Callback = function(v) Cache.TpWorld = WorldMap[v] end,
}, "TpWorld")
tpLeft:Button({
	Name = "Teleport To World",
	Callback = function()
		if Cache.TpWorld then
			HMZ_waitLoad(5)
			HMZ_fire("RequestChangeWorld", tonumber(Cache.TpWorld))
		end
	end,
})
tpLeft:Button({
	Name = "Respawn In World",
	Callback = function() HMZ_fire("RespawnInWorld") end,
})

tpRight:Header({ Text = "Teleporters" })
local tpDest = tpRight:Dropdown({
	Name = "Destination",
	Search = true,
	Options = {},
	Callback = function(v) Cache.TpDest = v end,
}, "TpDest")
tpRight:Button({
	Name = "Refresh Destinations",
	Callback = function()
		local dests, seen = {}, {}
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Teleporter" then
				local to = d:GetAttribute("TeleportTo")
				if to and not seen[to] then
					seen[to] = true
					dests[#dests + 1] = to
				end
			end
		end
		pcall(function() tpDest:ClearOptions() end)
		pcall(function() tpDest:InsertOptions(dests) end)
		HMZ_notify("HMZ Hub", "Found " .. #dests .. " teleporters", 3)
	end,
})
tpRight:Button({
	Name = "Teleport",
	Callback = function()
		if Cache.TpDest then HMZ_fire("TeleporterRequest", Cache.TpDest) end
	end,
})

local whLeft = HMZ_wrapSection(TabWebhook:Section({ Side = "Left" }))
whLeft:Header({ Text = "Discord Webhook" })
whLeft:Input({
	Name = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	Callback = function(text) Cache.WebhookUrl = text end,
}, "WebhookUrl")
whLeft:Toggle({
	Name = "Enable Webhook",
	Default = false,
	Callback = function(on) S.Webhook = on end,
}, "Webhook")
whLeft:Toggle({
	Name = "Notify Drops / Pets",
	Default = false,
	Callback = function(on) S.WebhookDrops = on end,
}, "WebhookDrops")
whLeft:Button({
	Name = "Test Webhook",
	Callback = function() HMZ_webhook("HMZ Hub webhook connected.") end,
})

local setLeft = HMZ_wrapSection(TabSettings:Section({ Side = "Left" }))
setLeft:Header({ Text = "Jeu actif" })
setLeft:Paragraph({
	Header = HMZ_ACTIVE_GAME.Name,
	Body = "PlaceId: " .. tostring(HMZ_PLACE_ID) .. "\nGameId: " .. tostring(HMZ_GAME_ID) .. "\nModule: " .. HMZ_ACTIVE_GAME.Id,
})
setLeft:Header({ Text = "Settings" })
setLeft:Slider({
	Name = "UI Scale",
	Default = HMZ_savedGet("settings", "UIScale", 100),
	Minimum = 50,
	Maximum = 150,
	DisplayMethod = "Round",
	Callback = function(v)
		HMZ_savedSet("settings", "UIScale", v)
		pcall(function() Window:SetScale(v / 100) end)
	end,
}, "UIScale")
setLeft:Toggle({
	Name = "Hide Username",
	Default = false,
	Callback = function(on) pcall(function() Window:SetUserInfoState(not on) end) end,
}, "HideUser")
local blackFrame
setLeft:Toggle({
	Name = "Blackscreen Mode",
	Default = false,
	Callback = function(on)
		if on then
			if not blackFrame then
				local sg = Instance.new("ScreenGui")
				sg.Name = "HMZ_Black"
				sg.IgnoreGuiInset = true
				sg.ResetOnSpawn = false
				sg.DisplayOrder = 9999
				local f = Instance.new("Frame")
				f.Size = UDim2.fromScale(1, 1)
				f.BackgroundColor3 = Color3.new(0, 0, 0)
				f.BorderSizePixel = 0
				f.Parent = sg
				pcall(function() sg.Parent = game:GetService("CoreGui") end)
				if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
				blackFrame = sg
			end
			blackFrame.Enabled = true
		elseif blackFrame then
			blackFrame.Enabled = false
		end
	end,
}, "Blackscreen")
setLeft:Keybind({
	Name = "Toggle UI",
	Default = Enum.KeyCode.RightShift,
	Callback = function() pcall(function() Window:SetState(not Window:GetState()) end) end,
}, "ToggleUI")
setLeft:Button({
	Name = "Unload",
	Callback = function()
		for k in pairs(S) do S[k] = false end
		HMZ_restoreCharacter()
		pcall(function() Window:Unload() end)
	end,
})
end

HMZ_buildUI()

HMZ_restoreAll()

HMZ_notify("HMZ Hub", "Loaded for " .. HMZ_ACTIVE_GAME.Name .. " (" .. tostring(HMZ_PLACE_ID) .. ")", 5)
