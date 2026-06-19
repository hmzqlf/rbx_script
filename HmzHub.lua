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
local MODULES = {
	core = [==[
local HttpService = game:GetService("HttpService")

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
local UserInputService = H.Services.UserInputService
local LocalPlayer = H.LocalPlayer

function H.canSave()
	return not H.Restoring and writefile ~= nil
end

function H.savedGet(group, id, fallback)
	local bucket = H.Saved[group]
	if type(bucket) ~= "table" then return fallback end
	local value = bucket[id]
	if value == nil then return fallback end
	return value
end

function H.savedSet(group, id, value)
	H.Saved[group] = H.Saved[group] or {}
	H.Saved[group][id] = value
	if not H.canSave() then return end
	if H.SaveJob then task.cancel(H.SaveJob) end
	H.SaveJob = task.delay(0.35, function()
		pcall(function()
			if writefile then
				if makefolder then
					pcall(makefolder, "HMZHub")
					pcall(makefolder, "HMZHub/" .. H.GameId)
				end
				writefile(H.ConfigPath, HttpService:JSONEncode(H.Saved))
			end
		end)
	end)
end

function H.loadConfig()
	H.Saved = {}
	if not (readfile and isfile and isfile(H.ConfigPath)) then return end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(H.ConfigPath))
	end)
	if ok and type(data) == "table" then
		H.Saved = data
		if type(H.Saved.dropdowns) == "table" then
			local fm = H.Saved.dropdowns.FarmMob
			if type(fm) == "string" then
				H.Saved.dropdowns.FarmMob = { fm }
			elseif type(fm) == "number" then
				H.Saved.dropdowns.FarmMob = {}
			end
			local ft = H.Saved.dropdowns.FarmTarget
			if type(ft) == "number" and ft >= 1 and ft <= 3 then
				H.Saved.dropdowns.FarmTargetMode = ft
			elseif type(ft) == "table" and (not H.Saved.dropdowns.FarmMob or not next(H.Saved.dropdowns.FarmMob)) then
				local merged = {}
				for k, v in pairs(ft) do
					if type(k) == "number" and type(v) == "string" then
						merged[v] = true
					elseif v == true and type(k) == "string" then
						merged[k] = true
					end
				end
				if next(merged) then
					H.Saved.dropdowns.FarmMob = merged
				end
			end
			H.Saved.dropdowns.FarmTarget = nil
		end
		if type(H.Saved.sliders) == "table" then
			H.Saved.leaveFloorDefaults = H.Saved.leaveFloorDefaults or {}
			local legacy = {
				LeaveRaid = "Raid",
				LeaveDefense = "Defense",
				LeaveTrial = "Trial",
				LeaveGate = "Gate",
			}
			for oldId, cat in pairs(legacy) do
				local v = H.Saved.sliders[oldId]
				if type(v) == "number" and v > 0 and H.Saved.leaveFloorDefaults[cat] == nil then
					H.Saved.leaveFloorDefaults[cat] = v
				end
			end
		end
	end
end

function H.wrapSection(section)
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
		local saved = H.savedGet("toggles", id, settings.Default)
		if saved ~= nil then settings.Default = saved end
		local old = settings.Callback
		settings.Callback = function(on)
			H.savedSet("toggles", id, on)
			if old then old(on) end
		end
		local el = section:Toggle(settings, id)
		H.UI[id] = el
		H.UIKind[id] = "toggle"
		return el
	end
	function wrapped:Slider(settings, id)
		id = id or settings.Name
		local saved = H.savedGet("sliders", id, settings.Default)
		if saved ~= nil then settings.Default = saved end
		local old = settings.Callback
		settings.Callback = function(v)
			H.savedSet("sliders", id, v)
			if old then old(v) end
		end
		local el = section:Slider(settings, id)
		H.UI[id] = el
		H.UIKind[id] = "slider"
		return el
	end
	function wrapped:Dropdown(settings, id)
		id = id or settings.Name
		local saved = H.savedGet("dropdowns", id, nil)
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
				H.savedSet("dropdowns", id, arr)
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
				H.savedSet("dropdowns", id, idx or v)
			end
			if old then old(v) end
		end
		H.DropdownCallbacks[id] = old
		local el = section:Dropdown(settings, id)
		H.UI[id] = el
		H.UIKind[id] = "dropdown"
		return el
	end
	function wrapped:Input(settings, id)
		id = id or settings.Name
		local saved = H.savedGet("inputs", id, settings.Default)
		if saved ~= nil then settings.Default = saved end
		local old = settings.Callback
		settings.Callback = function(text)
			H.savedSet("inputs", id, text)
			if old then old(text) end
		end
		H.InputCallbacks[id] = old
		local el = section:Input(settings, id)
		H.UI[id] = el
		H.UIKind[id] = "input"
		return el
	end
	function wrapped:Keybind(settings, id)
		id = id or settings.Name
		local saved = H.savedGet("keybinds", id, nil)
		if saved and Enum.KeyCode[saved] then
			settings.Default = Enum.KeyCode[saved]
		end
		local old = settings.Callback
		settings.Callback = function(key)
			if key then H.savedSet("keybinds", id, key.Name) end
			if old then old(key) end
		end
		local el = section:Keybind(settings, id)
		H.UI[id] = el
		H.UIKind[id] = "keybind"
		return el
	end
	return wrapped
end

function H.getPromptPart(prompt)
	local p = prompt.Parent
	if p and p:IsA("BasePart") then return p end
	if p and p:IsA("Model") then
		return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function H.findCrowPrompts()
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

function H.collectCrow(prompt)
	local hrp = H.getHRP()
	local part = H.getPromptPart(prompt)
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

function H.hopServer()
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
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, H.LocalPlayer)
					end)
					return
				end
			end
		end
	end
	pcall(function()
		TeleportService:Teleport(game.PlaceId, H.LocalPlayer)
	end)
end

function H.autoCrowTick()
	if H.canRunFeature and not H.canRunFeature("Crow") then return end
	if H.travelWorld then H.travelWorld(6) end
	if H.Cache.HopForAutoCrow then
		local prompts = H.findCrowPrompts()
		if #prompts > 0 then
			H.Cache.CrowHadAny = true
			H.Cache.CrowEmptySince = nil
			for _, prompt in ipairs(prompts) do
				if not S.AutoCrow then return end
				H.collectCrow(prompt)
				task.wait(0.6)
			end
			return
		end
		if not H.Cache.CrowHadAny then
			H.hopServer()
			return
		end
		if not H.Cache.CrowEmptySince then
			H.Cache.CrowEmptySince = os.clock()
			return
		end
		if os.clock() - H.Cache.CrowEmptySince >= 3 then
			H.Cache.CrowHadAny = false
			H.Cache.CrowEmptySince = nil
			H.hopServer()
		end
		return
	end
	local prompts = H.findCrowPrompts()
	if prompts[1] then
		H.collectCrow(prompts[1])
	end
end

function H.swordPassiveKey(info)
	return string.format(
		"%s_%s_%s_%s",
		tostring(info.SwordKey),
		tostring(info.Rarity),
		tostring(info.Level or 0),
		tostring(info.Index or 1)
	)
end

function H.parseSwordLevelCounts(levelData)
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

function H.buildSwordInventory()
	local data = H.invoke("GetPlayerData")
	local list = {}
	if type(data) ~= "table" or type(data.ActiveSwords) ~= "table" then
		return list
	end
	local scfg = H.require(H.ConfigFolder, "SwordConfig")
	local locked = type(data.LockedSwords) == "table" and data.LockedSwords or {}
	for swordKey, rarityMap in pairs(data.ActiveSwords) do
		if type(rarityMap) == "table" then
			local swordDef = scfg and scfg.GetSword and scfg:GetSword(swordKey)
			for rarity, levelData in pairs(rarityMap) do
				local itemDef = swordDef and swordDef.Items and swordDef.Items[rarity]
				for level, count in pairs(H.parseSwordLevelCounts(levelData)) do
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

function H.getSwordPassiveId(info, passives, spc)
	if type(passives) ~= "table" then return nil end
	local pid = passives[H.swordPassiveKey(info)]
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

function H.swordHasTargetPassive(info, passives, spc, targetId)
	if not targetId or targetId == "" or targetId == "None" then return false end
	local pid = H.getSwordPassiveId(info, passives, spc)
	if not pid then return false end
	if pid == targetId then return true end
	if spc and type(spc.GetPassiveById) == "function" then
		local ok, cfg = pcall(function() return spc:GetPassiveById(targetId) end)
		if ok and cfg and pid == cfg.Id then return true end
	end
	return false
end

function H.refreshSwordPassiveQueue()
	H.Cache.SwordPassiveQueue = {}
	local rarity = H.Cache.SwordPassiveRarity
	if not rarity then return end
	local ok, err = pcall(function()
		local spc = H.require(H.ConfigFolder, "SwordPassiveConfig")
		local data = H.invoke("GetPlayerData")
		local passives = type(data) == "table" and data.SwordPassives or {}
		local targetId = H.Cache.SwordPassiveTargetId
		local queue = {}
		for _, sword in ipairs(H.buildSwordInventory()) do
			if sword.Rarity == rarity and not sword.IsLocked then
				if not H.swordHasTargetPassive(sword, passives, spc, targetId) then
					queue[#queue + 1] = sword
				end
			end
		end
		H.Cache.SwordPassiveQueue = queue
	end)
	if not ok then
		warn("[HMZ Hub] SwordPassiveQueue: " .. tostring(err))
		H.Cache.SwordPassiveQueue = {}
	end
	if not H.Cache.SwordPassiveIndex or H.Cache.SwordPassiveIndex > #Cache.SwordPassiveQueue then
		H.Cache.SwordPassiveIndex = 1
	end
end

function H.getNextPassiveSword()
	H.refreshSwordPassiveQueue()
	local queue = H.Cache.SwordPassiveQueue
	if type(queue) ~= "table" or #queue == 0 then
		return nil
	end
	local targetId = H.Cache.SwordPassiveTargetId
	if targetId and targetId ~= "None" then
		return queue[1]
	end
	local idx = H.Cache.SwordPassiveIndex or 1
	if idx > #queue then idx = 1 end
	H.Cache.SwordPassiveIndex = idx
	return queue[idx]
end

function H.advancePassiveSword()
	local targetId = H.Cache.SwordPassiveTargetId
	if targetId and targetId ~= "None" then
		H.refreshSwordPassiveQueue()
		return
	end
	local queue = H.Cache.SwordPassiveQueue
	if type(queue) ~= "table" or #queue == 0 then return end
	local idx = (Cache.SwordPassiveIndex or 1) + 1
	if idx > #queue then idx = 1 end
	H.Cache.SwordPassiveIndex = idx
end

function H.autoSwordPassiveTick()
	local spc = H.require(H.ConfigFolder, "SwordPassiveConfig")
	if not H.Cache.SwordPassiveRarity then return end
	local sword = H.getNextPassiveSword()
	if not sword then
		S.AutoSwordPassive = false
		H.setState("AutoSwordPassive", false, 1, H.autoSwordPassiveTick)
		H.notify("HMZ Hub", "All sword passives done", 5)
		return
	end
	H.fire("SwordPassiveRollRequest", {
		SystemKey = (spc and spc.SystemKey) or "World6",
		SwordKey = sword.SwordKey,
		Rarity = sword.Rarity,
		Level = sword.Level or 0,
		Index = sword.Index or 1,
	})
	H.Cache.SwordPassiveRolling = sword
end

function H.restoreDropdown(id, el, options)
	local saved = H.savedGet("dropdowns", id, nil)
	if saved == nil or not el.UpdateSelection then return end
	if type(saved) == "table" then
		el:UpdateSelection(saved)
		if H.DropdownCallbacks[id] then
			local map = {}
			for _, name in ipairs(saved) do
				map[name] = true
			end
			H.DropdownCallbacks[id](map)
		end
		return
	end
	if type(saved) == "number" then
		el:UpdateSelection(saved)
		if H.DropdownCallbacks[id] and type(options) == "table" then
			H.DropdownCallbacks[id](options[saved])
		elseif H.DropdownCallbacks[id] and el.GetOptions then
			for name in pairs(el:GetOptions()) do
				H.DropdownCallbacks[id](name)
				break
			end
		end
		return
	end
	if type(saved) == "string" then
		if H.DropdownCallbacks[id] then
			H.DropdownCallbacks[id](saved)
		end
	end
end

function H.restoreAll()
	H.Restoring = true
	task.defer(function()
		task.wait(0.2)
		for id, el in pairs(H.UI) do
			if H.UIKind[id] == "slider" then
				local saved = H.savedGet("sliders", id, nil)
				if saved ~= nil and el.UpdateValue then
					el:UpdateValue(saved)
				end
			elseif H.UIKind[id] == "input" then
				local saved = H.savedGet("inputs", id, nil)
				if saved ~= nil and el.UpdateText then
					el:UpdateText(saved)
					if H.InputCallbacks[id] then H.InputCallbacks[id](saved) end
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
			local el = H.UI[id]
			if el then H.restoreDropdown(id, el) end
		end
		for id, el in pairs(H.UI) do
			if H.UIKind[id] == "dropdown" and not table.find(dropdownOrder, id) then
				H.restoreDropdown(id, el)
			end
		end
		if type(H.Saved.leaveFloorDefaults) == "table" then
			for cat, val in pairs(H.Saved.leaveFloorDefaults) do
				H.Cache.LeaveFloorDefaults[cat] = val
			end
		end
		if type(H.Saved.leaveFloors) == "table" then
			for id, val in pairs(H.Saved.leaveFloors) do
				H.Cache.LeaveFloors[id] = val
			end
		end
		if type(H.Saved.gamemodeValues) == "table" and type(Cache.GamemodeSel) == "table" then
			for title, sel in pairs(Cache.GamemodeSel) do
				local val = H.Saved.gamemodeValues[title]
				if val ~= nil then sel.value = val end
			end
		end
		local blur = H.savedGet("settings", "UIBlur", nil)
		if blur ~= nil then
			H.Cache.UIBlur = blur
			pcall(function() H.Window:SetAcrylicBlurState(blur) end)
		end
		local notif = H.savedGet("settings", "Notifications", nil)
		if notif ~= nil then
			H.Cache.Notifications = notif
			pcall(function() H.Window:SetNotificationsState(notif) end)
		end
		local scale = H.savedGet("settings", "UIScale", nil)
		if scale ~= nil then
			pcall(function() H.Window:SetScale(scale / 100) end)
		end
		for id, el in pairs(H.UI) do
			if H.UIKind[id] == "toggle" and H.savedGet("toggles", id, false) == true and el.UpdateState then
				el:UpdateState(true)
			end
		end
		H.Restoring = false
	end)
end

H.DRAG = {
	active = false,
	input = nil,
	start = nil,
	pos = nil,
	base = nil,
	connected = false,
}

function H.findMacBase()
	local macGui = H.LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MacLib")
	if not macGui then
		local coreGui = game:GetService("CoreGui")
		macGui = coreGui:FindFirstChild("MacLib")
	end
	if not macGui then return nil end
	return macGui:FindFirstChild("Base")
end

function H.raiseGuiLayer(frame, handle)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= handle then
			child.ZIndex = math.max(child.ZIndex, handle.ZIndex + 1)
		end
	end
end

function H.bindDragArea(frame, base)
	if not frame or not base then return end
	local handle = frame:FindFirstChild("H.DragHandle")
	if not handle then
		handle = Instance.new("TextButton")
		handle.Name = "H.DragHandle"
		handle.Size = UDim2.fromScale(1, 1)
		handle.BackgroundTransparency = 1
		handle.Text = ""
		handle.AutoButtonColor = false
		handle.ZIndex = 1
		handle.Parent = frame
		H.raiseGuiLayer(frame, handle)
	end
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		H.DRAG.active = true
		H.DRAG.base = base
		H.DRAG.start = input.Position
		H.DRAG.pos = base.Position
		H.DRAG.input = input
	end)
	handle.InputChanged:Connect(function(input)
		if H.DRAG.active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			H.DRAG.input = input
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			H.DRAG.active = false
			H.DRAG.input = nil
		end
	end)
end

function H.setupWindowDrag()
	if H.DRAG.connected then return end
	H.DRAG.connected = true
	UserInputService.InputChanged:Connect(function(input)
		if not H.DRAG.active or input ~= H.DRAG.input or not H.DRAG.base then return end
		local delta = input.Position - H.DRAG.start
		H.DRAG.base.Position = UDim2.new(
			H.DRAG.pos.X.Scale,
			H.DRAG.pos.X.Offset + delta.X,
			H.DRAG.pos.Y.Scale,
			H.DRAG.pos.Y.Offset + delta.Y
		)
	end)
	task.defer(function()
		local base
		local deadline = os.clock() + 5
		while os.clock() < deadline do
			base = H.findMacBase()
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
			H.bindDragArea(zone, base)
		end
	end)
end

function H.char()
	return LocalPlayer.Character
end

function H.getHRP()
	local c = H.char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

function H.humanoid()
	local c = H.char()
	return c and c:FindFirstChildOfClass("Humanoid")
end

function H.isLoading()
	local tc = H.require(H.ClientFolder, "TeleportController")
	if tc and tc.IsLoading then
		local ok, res = pcall(function() return tc:IsLoading() end)
		if ok then return res end
	end
	return false
end

function H.waitLoad(timeout)
	local deadline = os.clock() + (timeout or 10)
	while H.isLoading() and os.clock() < deadline do
		task.wait(0.1)
	end
	task.wait(0.15)
end

function H.waitReady()
	local deadline = os.clock() + 30
	while H.LocalPlayer:GetAttribute("ServerReady") ~= true and os.clock() < deadline do
		task.wait(0.2)
	end
end

function H.start(key, interval, fn)
	if H.Threads[key] then return end
	H.Threads[key] = task.spawn(function()
		while H.S[key] do
			pcall(fn)
			task.wait(interval)
		end
		H.Threads[key] = nil
	end)
end

function H.restoreCharacter()
	local hum = H.humanoid()
	if hum then
		hum.PlatformStand = false
		hum.AutoRotate = true
		if hum.Health > 0 then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
		end
	end
	local hrp = H.getHRP()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

function H.setState(key, on, interval, fn)
	H.S[key] = on
	if on then
		H.start(key, interval, fn)
	elseif H.FarmStateKeys[key] then
		H.restoreCharacter()
	end
end
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

]==],
	["games/anime_astral"] = [==[
return function(H)
	H.SimpleWorld = H.Services.ReplicatedStorage:WaitForChild("SimpleWorld")
	H.Library = require(H.SimpleWorld:WaitForChild("Library"))
	H.NetFunctions = H.SimpleWorld.Library.Network.Functions
	H.ConfigFolder = H.SimpleWorld.Library.Config
	H.ClientFolder = H.SimpleWorld.Library.Client

	function H.require(folder, name)
		local m = folder:FindFirstChild(name)
		if not m then return nil end
		local ok, r = pcall(require, m)
		if ok then return r end
		return nil
	end
	
	function H.getBridge(name)
		local ok, b = pcall(function() return H.Library.getBridge(name) end)
		if ok then return b end
		return nil
	end
	
	function H.fire(name, ...)
		local b = H.getBridge(name)
		if b then pcall(function(...) b:Fire(...) end, ...) end
	end
	
	function H.connect(name, fn)
		local b = H.getBridge(name)
		if b then pcall(function() b:Connect(fn) end) end
	end
	
	function H.invoke(name, ...)
		local f = H.NetFunctions:FindFirstChild(name)
		if not f then return nil end
		local args = table.pack(...)
		local ok, res = pcall(function() return f:InvokeServer(table.unpack(args, 1, args.n)) end)
		if ok then return res end
		return nil
	end
	
	function H.getPromptPart(prompt)
		local p = prompt.Parent
		if p and p:IsA("BasePart") then return p end
		if p and p:IsA("Model") then
			return p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
		end
		return nil
	end
	
	function H.findCrowPrompts()
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
	
	function H.collectCrow(prompt)
		local hrp = H.getHRP()
		local part = H.getPromptPart(prompt)
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
	
	function H.hopServer()
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
							TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, H.LocalPlayer)
						end)
						return
					end
				end
			end
		end
		pcall(function()
			TeleportService:Teleport(game.PlaceId, H.LocalPlayer)
		end)
	end
	
	function H.autoCrowTick()
		if H.canRunFeature and not H.canRunFeature("Crow") then return end
		if H.travelWorld then H.travelWorld(6) end
		if H.Cache.HopForAutoCrow then
			local prompts = H.findCrowPrompts()
			if #prompts > 0 then
				H.Cache.CrowHadAny = true
				H.Cache.CrowEmptySince = nil
				for _, prompt in ipairs(prompts) do
					if not S.AutoCrow then return end
					H.collectCrow(prompt)
					task.wait(0.6)
				end
				return
			end
			if not H.Cache.CrowHadAny then
				H.hopServer()
				return
			end
			if not H.Cache.CrowEmptySince then
				H.Cache.CrowEmptySince = os.clock()
				return
			end
			if os.clock() - H.Cache.CrowEmptySince >= 3 then
				H.Cache.CrowHadAny = false
				H.Cache.CrowEmptySince = nil
				H.hopServer()
			end
			return
		end
		local prompts = H.findCrowPrompts()
		if prompts[1] then
			H.collectCrow(prompts[1])
		end
	end
	
	function H.swordPassiveKey(info)
		return string.format(
			"%s_%s_%s_%s",
			tostring(info.SwordKey),
			tostring(info.Rarity),
			tostring(info.Level or 0),
			tostring(info.Index or 1)
		)
	end
	
	function H.parseSwordLevelCounts(levelData)
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
	
	function H.buildSwordInventory()
		local data = H.invoke("GetPlayerData")
		local list = {}
		if type(data) ~= "table" or type(data.ActiveSwords) ~= "table" then
			return list
		end
		local scfg = H.require(H.ConfigFolder, "SwordConfig")
		local locked = type(data.LockedSwords) == "table" and data.LockedSwords or {}
		for swordKey, rarityMap in pairs(data.ActiveSwords) do
			if type(rarityMap) == "table" then
				local swordDef = scfg and scfg.GetSword and scfg:GetSword(swordKey)
				for rarity, levelData in pairs(rarityMap) do
					local itemDef = swordDef and swordDef.Items and swordDef.Items[rarity]
					for level, count in pairs(H.parseSwordLevelCounts(levelData)) do
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
	
	function H.getSwordPassiveId(info, passives, spc)
		if type(passives) ~= "table" then return nil end
		local pid = passives[H.swordPassiveKey(info)]
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
	
	function H.swordHasTargetPassive(info, passives, spc, targetId)
		if not targetId or targetId == "" or targetId == "None" then return false end
		local pid = H.getSwordPassiveId(info, passives, spc)
		if not pid then return false end
		if pid == targetId then return true end
		if spc and type(spc.GetPassiveById) == "function" then
			local ok, cfg = pcall(function() return spc:GetPassiveById(targetId) end)
			if ok and cfg and pid == cfg.Id then return true end
		end
		return false
	end
	
	function H.refreshSwordPassiveQueue()
		H.Cache.SwordPassiveQueue = {}
		local rarity = H.Cache.SwordPassiveRarity
		if not rarity then return end
		local ok, err = pcall(function()
			local spc = H.require(H.ConfigFolder, "SwordPassiveConfig")
			local data = H.invoke("GetPlayerData")
			local passives = type(data) == "table" and data.SwordPassives or {}
			local targetId = H.Cache.SwordPassiveTargetId
			local queue = {}
			for _, sword in ipairs(H.buildSwordInventory()) do
				if sword.Rarity == rarity and not sword.IsLocked then
					if not H.swordHasTargetPassive(sword, passives, spc, targetId) then
						queue[#queue + 1] = sword
					end
				end
			end
			H.Cache.SwordPassiveQueue = queue
		end)
		if not ok then
			warn("[HMZ Hub] SwordPassiveQueue: " .. tostring(err))
			H.Cache.SwordPassiveQueue = {}
		end
		if not H.Cache.SwordPassiveIndex or H.Cache.SwordPassiveIndex > #Cache.SwordPassiveQueue then
			H.Cache.SwordPassiveIndex = 1
		end
	end
	
	function H.getNextPassiveSword()
		H.refreshSwordPassiveQueue()
		local queue = H.Cache.SwordPassiveQueue
		if type(queue) ~= "table" or #queue == 0 then
			return nil
		end
		local targetId = H.Cache.SwordPassiveTargetId
		if targetId and targetId ~= "None" then
			return queue[1]
		end
		local idx = H.Cache.SwordPassiveIndex or 1
		if idx > #queue then idx = 1 end
		H.Cache.SwordPassiveIndex = idx
		return queue[idx]
	end
	
	function H.advancePassiveSword()
		local targetId = H.Cache.SwordPassiveTargetId
		if targetId and targetId ~= "None" then
			H.refreshSwordPassiveQueue()
			return
		end
		local queue = H.Cache.SwordPassiveQueue
		if type(queue) ~= "table" or #queue == 0 then return end
		local idx = (Cache.SwordPassiveIndex or 1) + 1
		if idx > #queue then idx = 1 end
		H.Cache.SwordPassiveIndex = idx
	end
	
	function H.autoSwordPassiveTick()
		local spc = H.require(H.ConfigFolder, "SwordPassiveConfig")
		if not H.Cache.SwordPassiveRarity then return end
		local sword = H.getNextPassiveSword()
		if not sword then
			S.AutoSwordPassive = false
			H.setState("AutoSwordPassive", false, 1, H.autoSwordPassiveTick)
			H.notify("HMZ Hub", "All sword passives done", 5)
			return
		end
		H.fire("SwordPassiveRollRequest", {
			SystemKey = (spc and spc.SystemKey) or "World6",
			SwordKey = sword.SwordKey,
			Rarity = sword.Rarity,
			Level = sword.Level or 0,
			Index = sword.Index or 1,
		})
		H.Cache.SwordPassiveRolling = sword
	end
	
	
	H.CODES = {
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
	
	function H.fetchRemoteCodes()
		local url = H.Cache.CodesUrl
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
	
	function H.redeemedSet()
		local set = {}
		local data = H.invoke("GetPlayerData")
		if type(data) == "table" and type(data.RedeemedCodes) == "table" then
			for k, v in pairs(data.RedeemedCodes) do
				if type(k) == "string" then set[k] = true end
				if type(v) == "string" then set[v] = true end
			end
		end
		return set
	end
	
	function H.redeemAll(keepGoing)
		H.Cache.RedeemedLocal = H.Cache.RedeemedLocal or {}
		local redeemed = H.redeemedSet()
		local seen, list = {}, {}
		for _, c in ipairs(H.CODES) do
			if not seen[c] then seen[c] = true; list[#list + 1] = c end
		end
		for _, c in ipairs(H.fetchRemoteCodes()) do
			if not seen[c] then seen[c] = true; list[#list + 1] = c end
		end
		local fired = 0
		for _, code in ipairs(list) do
			if keepGoing and not keepGoing() then break end
			if not redeemed[code] and not H.Cache.RedeemedLocal[code] then
				H.Cache.RedeemedLocal[code] = true
				H.fire("RedeemCode", code)
				fired = fired + 1
				task.wait(11)
			end
		end
		return fired
	end
	
	function H.namedOptions(subTable)
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
		local c = H.require(H.ConfigFolder, "WorldConfig")
		if c and c.Worlds then
			WorldLabels, WorldMap = H.namedOptions(c.Worlds)
		end
		if #WorldLabels == 0 then
			WorldLabels = { "Lobby Arena", "Ninja Village", "Namek City", "Wano Island", "Titan Wall", "Solo City", "Slayer Village" }
			for i, n in ipairs(WorldLabels) do WorldMap[n] = tostring(i - 1) end
		end
	end
	
	H.LeaveModes = {}
	H.LeaveStateKeys = {}

	H.LEAVE_SOURCES = {
		{ config = "TimeTrialConfig", getAll = "GetAllTrials", category = "Trial", stateKey = "TrialState", activeKey = "TrialActiveKey", field = "Room", leaveBridge = "TimeTrialLeave", idFields = { "TrialKey", "Key", "Id" }, unit = "Room", progressKey = "TotalRooms" },
		{ config = "RaidConfig", getAll = "GetAllRaids", category = "Raid", stateKey = "RaidState", activeKey = "RaidActiveKey", field = "Wave", leaveBridge = "RaidLeave", idFields = { "RaidKey", "Key", "ActiveKey", "Id" }, unit = "Wave", progressKey = "TotalWaves", categoryFn = function(configId)
			if configId == "World5" then return "Gate" end
			if configId == "World6" then return "Infinite Castle" end
			return "Raid"
		end },
		{ config = "DefenseConfig", getAll = "GetAllDefenses", category = "Defense", stateKey = "DefenseState", activeKey = "DefenseActiveKey", field = "Wave", leaveBridge = "DefenseLeave", idFields = { "DefenseKey", "Key", "ActiveKey", "Id" }, unit = "Wave", progressKey = "TotalWaves" },
	}
	
	function H.leaveModeId(category, configId)
		return tostring(category) .. "/" .. tostring(configId)
	end
	
	function H.leaveSliderId(modeId)
		return "LeaveFloor_" .. modeId:gsub("[^%w_]", "_")
	end
	
	function H.addLeaveMode(modes, seen, entry)
		local id = H.leaveModeId(entry.category, entry.configId)
		if seen[id] then return end
		seen[id] = true
		modes[#modes + 1] = entry
		entry.id = id
	end
	
	function H.discoverLeaveModes()
		local modes, seen = {}, {}
		for _, src in ipairs(H.LEAVE_SOURCES) do
			local c = H.require(H.ConfigFolder, src.config)
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
						H.addLeaveMode(modes, seen, {
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
	
	H.LeaveModes, H.LeaveStateKeys = H.discoverLeaveModes()
	
	function H.getStateModeId(state, idFields)
		if type(state) ~= "table" then return nil end
		for _, field in ipairs(idFields) do
			local val = state[field]
			if val ~= nil and val ~= "" then return val end
		end
		return nil
	end
	
	function H.getTrackedModeKey(mode)
		if type(mode) ~= "table" or not mode.activeKey then return nil end
		return Cache[mode.activeKey]
	end
	
	function H.stateMatchesLeaveMode(state, mode)
		if type(state) ~= "table" or type(mode) ~= "table" then return false end
		local tracked = H.getTrackedModeKey(mode)
		if tracked and tostring(tracked) == tostring(mode.configId) then return true end
		local sid = H.getStateModeId(state, mode.idFields)
		if sid and tostring(sid) == tostring(mode.configId) then return true end
		return false
	end
	
	function H.getLeaveFloorLimit(mode)
		if type(mode) ~= "table" then return nil end
		local v = H.Cache.LeaveFloors[mode.id]
		if v == nil then v = H.savedGet("leaveFloors", mode.id, nil) end
		if type(v) == "number" and v > 0 then return v end
		local def = H.Cache.LeaveFloorDefaults[mode.category]
		if def == nil then def = H.savedGet("leaveFloorDefaults", mode.category, nil) end
		if type(def) == "number" and def > 0 then return def end
		return nil
	end
	
	function H.getLeaveProgress(state, mode)
		if type(state) ~= "table" or type(mode) ~= "table" then return nil end
		if state[mode.field] ~= nil then return state[mode.field] end
		if mode.category == "Gate" and state.Floor ~= nil then return state.Floor end
		if mode.category == "Infinite Castle" and state.Wave ~= nil then return state.Wave end
		return nil
	end
	
	function H.getActiveLeaveMode()
		for _, mode in ipairs(H.LeaveModes) do
			local state = Cache[mode.stateKey]
			local progress = H.getLeaveProgress(state, mode)
			if progress and H.stateMatchesLeaveMode(state, mode) then
				return mode, state, progress
			end
		end
		return nil, nil, nil
	end
	
	function H.autoLeaveFloorTick()
		local mode, state, progress = H.getActiveLeaveMode()
		if not mode or not state or progress == nil then return end
		local limit = H.getLeaveFloorLimit(mode)
		if limit and limit > 0 and progress >= limit then
			if mode.stateKey == "TrialState" then
				H.onTrialFinished()
			end
			H.fire(mode.leaveBridge)
		end
	end
	
	function H.buildLeaveFloorUI(section)
		local lastCategory
		for _, mode in ipairs(H.LeaveModes) do
			if mode.category ~= lastCategory then
				section:Header({ Text = "Leave " .. mode.category })
				lastCategory = mode.category
			end
			local sliderId = H.leaveSliderId(mode.id)
			local saved = H.savedGet("leaveFloors", mode.id, 0)
			section:Slider({
				Name = mode.label,
				Default = type(saved) == "number" and saved or 0,
				Minimum = 0,
				Maximum = math.max(50, tonumber(mode.maxProgress) or 500),
				DisplayMethod = "Round",
				Callback = function(v)
					H.Cache.LeaveFloors[mode.id] = v
					H.savedSet("leaveFloors", mode.id, v)
				end,
			}, sliderId)
		end
		if #H.LeaveModes == 0 then
			section:Paragraph({
				Header = "Leave Floor",
				Body = "No gamemodes found in config.",
			})
		end
	end
	
	function H.mobOptions(worldId)
		local out = { "Any" }
		local c = H.require(H.ConfigFolder, "EnemyConfig")
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
	
	function H.configOptions(configName, sub)
		local c = H.require(H.ConfigFolder, configName)
		if not c then return {}, {} end
		local subTable = sub and c[sub] or c
		return H.namedOptions(subTable)
	end
	
	function H.shopProducts(configName, shopKey)
		local labels, map = {}, {}
		local c = H.require(H.ConfigFolder, configName)
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
	
	function H.multiToList(value, map)
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
	
	function H.mobMatchesFilter(mobName, mobFilter)
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
	
	function H.splitPriorityEnemies(enemies, priorityFilter)
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
			if H.mobMatchesFilter(m.Name, priorityFilter) then
				priority[#priority + 1] = m
			end
		end
		if #priority > 0 then return priority end
		return enemies
	end
	
	function H.collectEnemies(arenaOnly, mobFilter)
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
					if H.mobMatchesFilter(m.Name, mobFilter) then
						list[#list + 1] = m
					end
				end
			end
		end
		return list
	end
	
	function H.getAttackRadius()
		local cfg = H.require(H.ConfigFolder, "RangeUpgradeConfig")
		if not cfg then return 11.14 end
		local level = 1
		local rc = H.require(H.ClientFolder, "RangeController")
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
	
	function H.getGroundY(position, exclude)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude or {}
		local result = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -120, 0), params)
		if result then return result.Position.Y end
		return position.Y
	end
	
	function H.getFeetOffset()
		local char = H.char()
		local hrp = H.getHRP()
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
	
	function H.teleportToGroundNear(targetPos, facePos)
		local hrp = H.getHRP()
		local char = H.char()
		if not hrp or not char then return end
		local exclude = { char }
		local groundY = H.getGroundY(targetPos, exclude)
		local feetOffset = H.getFeetOffset()
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
	
	function H.countEnemiesInRange(origin, radius, enemies)
		local count = 0
		for _, m in ipairs(enemies) do
			local th = m:FindFirstChild("HumanoidRootPart")
			if th and (Vector3.new(origin.X, th.Position.Y, origin.Z) - th.Position).Magnitude <= radius then
				count = count + 1
			end
		end
		return count
	end
	
	function H.scoreTarget(mode, hrp, m, th)
		if mode == "Highest HP" then
			return m:GetAttribute("HealthReal") or 0
		elseif mode == "Lowest HP" then
			return -(m:GetAttribute("HealthReal") or math.huge)
		end
		return -(hrp.Position - th.Position).Magnitude
	end
	
	function H.pickTargetFromList(mode, enemies)
		local hrp = H.getHRP()
		if not hrp then return nil end
		local best, bestScore
		for _, m in ipairs(enemies) do
			local th = m:FindFirstChild("HumanoidRootPart")
			if th then
				local score = H.scoreTarget(mode, hrp, m, th)
				if not bestScore or score > bestScore then
					bestScore = score
					best = m
				end
			end
		end
		return best
	end
	
	function H.pickTarget(mode, mobFilter, arenaOnly, priorityFilter)
		local enemies = H.collectEnemies(arenaOnly, mobFilter)
		local pool = H.splitPriorityEnemies(enemies, priorityFilter)
		return H.pickTargetFromList(mode or "Nearest", pool)
	end
	
	function H.pickIntelligentTarget(mobFilter, arenaOnly, priorityFilter)
		local radius = H.getAttackRadius()
		local enemies = H.collectEnemies(arenaOnly, mobFilter)
		local pool = H.splitPriorityEnemies(enemies, priorityFilter)
		if #pool == 0 then return nil, radius end
		local best, bestCount
		for _, m in ipairs(pool) do
			local th = m:FindFirstChild("HumanoidRootPart")
			if th then
				local count = H.countEnemiesInRange(th.Position, radius, pool)
				if not bestCount or count > bestCount then
					bestCount = count
					best = m
				end
			end
		end
		return best, radius
	end
	
	function H.farmTarget(mobFilter, arenaOnly, targetMode, intelligent, priorityFilter)
		if intelligent then
			return H.pickIntelligentTarget(mobFilter, arenaOnly, priorityFilter)
		end
		return H.pickTarget(targetMode or "Nearest", mobFilter, arenaOnly, priorityFilter), H.getAttackRadius()
	end
	
	function H.attackTarget(target, attackRadius)
		if not target then
			H.fire("Click")
			return
		end
		local th = target:FindFirstChild("HumanoidRootPart")
		if not th then
			H.fire("Click")
			return
		end
		local hrp = H.getHRP()
		if not hrp then return end
		local radius = attackRadius or H.getAttackRadius()
		local standDist = math.clamp(radius * 0.25, 2, 6)
		local flatDelta = Vector3.new(hrp.Position.X - th.Position.X, 0, hrp.Position.Z - th.Position.Z)
		if flatDelta.Magnitude < 0.5 then
			flatDelta = Vector3.new(0, 0, standDist)
		else
			flatDelta = flatDelta.Unit * standDist
		end
		local standPos = th.Position + flatDelta
		H.teleportToGroundNear(standPos, th.Position)
		H.fire("Click")
	end
	
	function H.currentWorld()
		return H.invoke("GetCurrentWorld")
	end
	
	function H.travelWorld(worldId)
		if not worldId then return end
		if H.isLoading() then return end
		local cur = H.currentWorld()
		if tostring(cur) == tostring(worldId) then return end
		H.fire("RequestChangeWorld", tonumber(worldId))
		H.waitLoad(8)
	end
	
	function H.getActiveGamemode()
		if type(Cache.TrialState) == "table" and H.Cache.TrialState.Room then
			return "Trial"
		end
		if type(Cache.DefenseState) == "table" and H.Cache.DefenseState.Wave then
			return "Defense"
		end
		if type(Cache.RaidState) == "table" and H.Cache.RaidState.Wave then
			if H.Cache.RaidActiveKey == "World5" then return "Gate" end
			if H.Cache.RaidActiveKey == "World6" then return "InfiniteCastle" end
			return "Raid"
		end
		return nil
	end
	
	H.PRIORITY_ORDER = {
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
	
	function H.getResourceCount(itemId)
		H.Cache._ResourceCache = H.Cache._ResourceCache or {}
		local now = os.clock()
		if not H.Cache._ResourceCacheTime or now - H.Cache._ResourceCacheTime > 2 then
			H.Cache._ResourceCacheTime = now
			local data = H.invoke("GetPlayerData")
			H.Cache._ResourceCacheData = type(data) == "table" and data or {}
		end
		local data = H.Cache._ResourceCacheData or {}
		local v = data[itemId]
		if type(v) == "number" then return v end
		return 0
	end
	
	function H.getSelectedRaidKey()
		local sel = H.Cache.GamemodeSel and H.Cache.GamemodeSel.Raid
		return sel and sel.value
	end
	
	function H.isInfiniteCastleKey(key)
		return tostring(key or "") == "World6"
	end
	
	function H.wantsTrial()
		if H.getActiveGamemode() == "Trial" then
			return S.FarmTrial == true or S.JoinTrial == true or S.JoinOpenTrial == true
		end
		if S.JoinOpenTrial and H.hasOpenTrial and H.hasOpenTrial() then return true end
		if S.JoinTrial and H.isTrialOpen and H.isTrialOpen() then return true end
		if H.Cache.AutoLeaveForTrial and H.hasOpenTrial and H.hasOpenTrial() then return true end
		return false
	end
	
	function H.wantsGate()
		if H.getActiveGamemode() == "Gate" then
			return S.FarmGate == true or S.AutoGate == true
		end
		if S.AutoGate then
			local state = H.invoke("GetRaidGateState", "World5")
			if type(state) == "table" and state.IsOpen then return true end
		end
		return false
	end
	
	function H.wantsCrow()
		return S.AutoCrow == true
	end
	
	function H.wantsDefense()
		if H.getActiveGamemode() == "Defense" then
			return S.FarmDefense == true or S.JoinDefense == true or S.JoinOpenDefense == true
		end
		if S.JoinDefense or S.JoinOpenDefense then return true end
		return false
	end
	
	function H.wantsInfiniteCastle()
		local gm = H.getActiveGamemode()
		if gm == "InfiniteCastle" then
			return S.FarmRaid == true or S.JoinRaid == true or S.JoinOpenRaid == true
		end
		local raidKey = H.getSelectedRaidKey()
		local hasKeys = H.getResourceCount("InfinityCastleKey") >= 1
		if S.JoinRaid and H.isInfiniteCastleKey(raidKey) and hasKeys then return true end
		if S.JoinOpenRaid and hasKeys then
			if H.isInfiniteCastleKey(raidKey) then return true end
			local pool = H.Cache.OpenRaids
			if type(pool) == "table" and pool.World6 == true then return true end
		end
		return false
	end
	
	function H.wantsRaid()
		local gm = H.getActiveGamemode()
		if gm == "Raid" then
			return S.FarmRaid == true or S.JoinRaid == true or S.JoinOpenRaid == true
		end
		local raidKey = H.getSelectedRaidKey()
		if H.isInfiniteCastleKey(raidKey) then return false end
		if S.JoinRaid then
			if tostring(raidKey or "") == "World0" then
				if H.getResourceCount("TimelessRaidKey") >= 1 or H.getResourceCount("NinjaRaidKey") >= 1 then return true end
			elseif tostring(raidKey or "") == "World1" then
				if H.getResourceCount("NinjaRaidKey") >= 1 then return true end
			else
				return true
			end
		end
		if S.JoinOpenRaid then
			local pool = H.Cache.OpenRaids
			if type(pool) == "table" then
				for k, v in pairs(pool) do
					if v == true and type(k) == "string" and not H.isInfiniteCastleKey(k) then
						return true
					end
				end
			end
		end
		if S.FarmRaid and not H.isInfiniteCastleKey(raidKey) then return true end
		return false
	end
	
	function H.wantsQuest()
		return S.AutoQuest == true
	end
	
	function H.wantsSideQuest()
		return S.AutoSideQuest == true
	end
	
	function H.wantsStar()
		return S.AutoStar == true
	end
	
	function H.wantsMob()
		return S.AutoFarmMob == true
	end
	
	H.WANTS = {
		Trial = H.wantsTrial,
		Gate = H.wantsGate,
		Crow = H.wantsCrow,
		Defense = H.wantsDefense,
		InfiniteCastle = H.wantsInfiniteCastle,
		Raid = H.wantsRaid,
		Quest = H.wantsQuest,
		SideQuest = H.wantsSideQuest,
		Star = H.wantsStar,
		Mob = H.wantsMob,
	}
	
	function H.getActivePriorityFeature()
		for _, id in ipairs(H.PRIORITY_ORDER) do
			local fn = H.WANTS[id]
			if fn and fn() then
				return id
			end
		end
		return nil
	end
	
	H.canRunFeature = function(id)
		if not id then return true end
		local active = H.getActivePriorityFeature()
		if not active then return true end
		return active == id
	end
	
	function H.trialSession()
		H.Cache.TrialSession = H.Cache.TrialSession or {}
		return H.Cache.TrialSession
	end
	
	function H.isTrialOpen()
		local pool = H.Cache.OpenTrials
		if type(pool) ~= "table" then return false end
		if pool.IsOpen == true then return true end
		if pool.ScheduleOpen == true then return true end
		return false
	end
	
	function H.hasOpenTrial()
		if not H.isTrialOpen() then return false, nil end
		local session = H.trialSession()
		if session.handled or session.inTrial or session.joining or session.resuming then return false, nil end
		if session.leavingForTrial then return false, nil end
		local pool = H.Cache.OpenTrials
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
	
	function H.saveTrialResume()
		if H.Cache.TrialResume then return end
		local raidSel = H.Cache.GamemodeSel and H.Cache.GamemodeSel.Raid
		local defSel = H.Cache.GamemodeSel and H.Cache.GamemodeSel.Defense
		H.Cache.TrialResume = {
			worldId = H.currentWorld(),
			mode = H.getActiveGamemode(),
			raidKey = (raidSel and raidSel.value) or H.Cache.RaidActiveKey,
			defenseKey = (defSel and defSel.value) or H.Cache.DefenseActiveKey,
			joinRaid = S.JoinRaid == true,
			joinOpenRaid = S.JoinOpenRaid == true,
			joinDefense = S.JoinDefense == true,
			joinOpenDefense = S.JoinOpenDefense == true,
		}
	end
	
	function H.resumeAfterTrial()
		local resume = H.Cache.TrialResume
		if not resume then return end
		H.Cache.TrialResume = nil
		local session = H.trialSession()
		session.resuming = true
		task.spawn(function()
			if H.isLoading() then H.waitLoad(20) end
			task.wait(3)
			if resume.worldId ~= nil then
				H.travelWorld(resume.worldId)
				task.wait(2)
			end
			if H.isLoading() then H.waitLoad(20) end
			local mode = resume.mode
			if mode == "InfiniteCastle" or mode == "Gate" or mode == "Raid" then
				if resume.raidKey then
					H.applyLoadout("Raid")
					if resume.joinOpenRaid then
						H.fire("RaidJoin", "Join", resume.raidKey)
					elseif resume.joinRaid then
						H.fire("RaidJoin", "Create", resume.raidKey)
					end
				end
			elseif mode == "Defense" then
				if resume.defenseKey then
					H.applyLoadout("Defense")
					if resume.joinOpenDefense then
						H.fire("DefenseJoin", "Join", resume.defenseKey)
					elseif resume.joinDefense then
						H.fire("DefenseJoin", "Create", resume.defenseKey)
					end
				end
			end
			task.wait(4)
			session.resuming = false
		end)
	end
	
	function H.onTrialFinished()
		local session = H.trialSession()
		if session.finishLock then return end
		session.finishLock = true
		session.handled = true
		session.inTrial = false
		session.joining = false
		session.leavingForTrial = false
		task.delay(4, function()
			H.resumeAfterTrial()
			task.delay(6, function()
				session.finishLock = false
			end)
		end)
	end
	
	function H.leaveActiveGamemode(mode)
		mode = mode or H.getActiveGamemode()
		if not mode or mode == "Trial" then return false end
		local bridge = ({
			Raid = "RaidLeave",
			Defense = "DefenseLeave",
			Gate = "RaidLeave",
			InfiniteCastle = "RaidLeave",
		})[mode]
		if not bridge then return false end
		H.fire(bridge)
		return true
	end
	
	function H.prepareTrialLeave()
		if not H.Cache.AutoLeaveForTrial then return end
		local mode = H.getActiveGamemode()
		if not mode or mode == "Trial" then return end
		local session = H.trialSession()
		if session.leavingForTrial then return end
		session.leavingForTrial = true
		H.saveTrialResume()
		H.leaveActiveGamemode(mode)
		task.delay(3, function()
			session.leavingForTrial = false
		end)
	end
	
	function H.tryJoinOpenTrial(trialKey)
		if H.isLoading() then return end
		if H.getActiveGamemode() == "Trial" then return end
		local session = H.trialSession()
		if session.handled or session.inTrial or session.joining or session.leavingForTrial or session.resuming then return end
		if not trialKey then
			local open
			open, trialKey = H.hasOpenTrial()
			if not open or not trialKey then return end
		elseif not H.isTrialOpen() or session.handled then
			return
		end
		local now = os.clock()
		if session.lastJoinAttempt and now - session.lastJoinAttempt < 10 then return end
		session.lastJoinAttempt = now
		session.joining = true
		H.saveTrialResume()
		H.applyLoadout("Trial")
		H.fire("TimeTrialJoin", "Join", trialKey)
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
	
	function H.applyLoadout(context)
		if not S.AutoLoadout then return end
		local stat = H.Cache.LoadoutMap and H.Cache.LoadoutMap[context]
		if not stat or stat == "None" then return end
		if H.Cache.LastLoadout[context] and os.clock() - H.Cache.LastLoadout[context] < 4 then return end
		H.Cache.LastLoadout[context] = os.clock()
		H.fire("EquipBestLoadout", stat)
	end
	
	H.connect("RaidActiveStatus", function(map)
		if type(map) == "table" then H.Cache.OpenRaids = map end
	end)
	H.connect("DefenseActiveStatus", function(map)
		if type(map) == "table" then H.Cache.OpenDefenses = map end
	end)
	H.connect("TimeTrialActiveStatus", function(count, info)
		if type(info) ~= "table" then return end
		H.Cache.OpenTrials = info
		local session = H.trialSession()
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
	H.connect("RaidState", function(state)
		if type(state) == "table" then H.Cache.RaidState = state end
	end)
	H.connect("RaidMapReady", function(key)
		if type(key) == "string" then H.Cache.RaidActiveKey = key end
	end)
	H.connect("RaidEnded", function()
		H.Cache.RaidActiveKey = nil
		H.Cache.RaidState = {}
	end)
	H.connect("DefenseState", function(state)
		if type(state) == "table" then H.Cache.DefenseState = state end
	end)
	H.connect("DefenseMapReady", function(key)
		if type(key) == "string" then H.Cache.DefenseActiveKey = key end
	end)
	H.connect("DefenseEnded", function()
		H.Cache.DefenseActiveKey = nil
		H.Cache.DefenseState = {}
	end)
	H.connect("TimeTrialState", function(state)
		if type(state) == "table" then
			H.Cache.TrialState = state
			local session = H.trialSession()
			if state.Room then
				session.inTrial = true
				session.joining = false
			elseif session.inTrial then
				session.inTrial = false
				H.onTrialFinished()
			end
		else
			H.Cache.TrialState = {}
			local session = H.trialSession()
			if session.inTrial then
				session.inTrial = false
				H.onTrialFinished()
			end
		end
	end)
	H.connect("TimeTrialMapReady", function(key)
		if type(key) == "string" then
			H.Cache.TrialActiveKey = key
			local session = H.trialSession()
			session.inTrial = true
			session.joining = false
		end
	end)
	H.connect("TimeTrialEnded", function()
		H.Cache.TrialActiveKey = nil
		H.Cache.TrialState = {}
		H.onTrialFinished()
	end)
	H.connect("PotionState", function(state)
		if type(state) == "table" then H.Cache.Potions = state end
	end)
	H.connect("GachaResult", function(payload)
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
			H.notify("HMZ Hub", "Stopped on Divine Gacha", 6)
		end
	end)
	H.connect("TitanResult", function(payload)
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
			H.notify("HMZ Hub", "Stopped on Secret Titan", 6)
		end
	end)
	
	function H.webhook(content)
		if not S.Webhook or not H.Cache.WebhookUrl or H.Cache.WebhookUrl == "" then return end
		local req = (syn and syn.request) or (http and http.request) or http_request or request
		if not req then return end
		pcall(function()
			req({
				Url = H.Cache.WebhookUrl,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({ content = content }),
			})
		end)
	end
	
	H.connect("DropNotify", function(data)
		if not S.WebhookDrops then return end
		local txt = type(data) == "table" and (data.Message or data.Name or HttpService:JSONEncode(data)) or tostring(data)
		H.webhook("**Drop:** " .. txt)
	end)
	H.connect("PetAnnouncement", function(data)
		if not S.WebhookDrops then return end
		local txt = type(data) == "table" and (data.Message or data.Name or HttpService:JSONEncode(data)) or tostring(data)
		H.webhook("**Pet:** " .. txt)
	end)
	H.connect("SwordPassiveResult", function(success, errCode, state)
		if not S.AutoSwordPassive then return end
		if success ~= true then
			if errCode == "not_enough_items" or errCode == "sword_not_owned" or errCode == "world_locked" then
				S.AutoSwordPassive = false
				H.setState("AutoSwordPassive", false, 1.1, H.autoSwordPassiveTick)
			end
			return
		end
		task.defer(function()
			task.wait(0.08)
			local spc = H.require(H.ConfigFolder, "SwordPassiveConfig")
			local passives = nil
			if type(state) == "table" and type(state.SwordPassives) == "table" then
				passives = state.SwordPassives
			else
				local data = H.invoke("GetPlayerData")
				passives = type(data) == "table" and data.SwordPassives or {}
			end
			local rolled = H.Cache.SwordPassiveRolling
			H.Cache.SwordPassiveRolling = nil
			if not rolled then return end
			if H.swordHasTargetPassive(rolled, passives, spc, H.Cache.SwordPassiveTargetId) then
				H.advancePassiveSword()
			elseif not H.Cache.SwordPassiveTargetId or H.Cache.SwordPassiveTargetId == "None" then
				H.advancePassiveSword()
			end
		end)
	end)
	function H._buildUI()
	local Tabs = H.Window:TabGroup()
	
	local TabMain = Tabs:Tab({ Name = "Main" })
	local TabGamemode = Tabs:Tab({ Name = "Gamemode" })
	local TabLoadout = Tabs:Tab({ Name = "Loadout / Boost" })
	local TabShop = Tabs:Tab({ Name = "Shop" })
	local TabUpgrade = Tabs:Tab({ Name = "Map Upgrade" })
	local TabTeleport = Tabs:Tab({ Name = "Teleport" })
	local TabWebhook = Tabs:Tab({ Name = "Webhook" })
	local TabSettings = Tabs:Tab({ Name = "Settings" })
	
	local mainLeft = H.wrapSection(TabMain:Section({ Side = "Left" }))
	local mainRight = H.wrapSection(TabMain:Section({ Side = "Right" }))
	
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
		Callback = function(v) H.Cache.WorldDelay = v end,
	}, "WorldDelay")
	
	local mobWorldDD
	local mobMobDD
	mobWorldDD = mainLeft:Dropdown({
		Name = "World",
		Search = true,
		Options = WorldLabels,
		Default = 1,
		Callback = function(v)
			H.Cache.FarmWorldName = v
			H.Cache.FarmWorldId = WorldMap[v]
			local mobOpts = H.mobOptions(WorldMap[v])
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
		Options = H.mobOptions(WorldMap[WorldLabels[1]]),
		Default = { "Any" },
		Callback = function(v) H.Cache.FarmMob = v end,
	}, "FarmMob")
	
	mainLeft:Dropdown({
		Name = "Target Mode",
		Options = { "Nearest", "Highest HP", "Lowest HP" },
		Default = 1,
		Callback = function(v) H.Cache.FarmTargetMode = v end,
	}, "FarmTargetMode")
	
	mainLeft:Toggle({
		Name = "Farm Intelligent",
		Default = false,
		Callback = function(on) H.Cache.FarmIntelligent = on end,
	}, "FarmIntelligent")
	
	mainLeft:Toggle({
		Name = "Auto Farm Mob",
		Default = false,
		Callback = function(on)
			H.setState("AutoFarmMob", on, 0.3, function()
				if not H.canRunFeature("Mob") then return end
				if H.Cache.FarmWorldId then H.travelWorld(Cache.FarmWorldId) end
				H.applyLoadout("MobQuest")
				local t, radius = H.farmTarget(Cache.FarmMob, false, H.Cache.FarmTargetMode, H.Cache.FarmIntelligent)
				H.attackTarget(t, radius)
			end)
		end,
	}, "AutoFarmMob")
	
	mainLeft:Toggle({
		Name = "Auto Crow",
		Default = false,
		Callback = function(on)
			if on then
				H.Cache.CrowHadAny = false
				H.Cache.CrowEmptySince = nil
			end
			H.setState("AutoCrow", on, 1, H.autoCrowTick)
		end,
	}, "AutoCrow")
	
	mainLeft:Toggle({
		Name = "Hop For Auto Crow",
		Default = false,
		Callback = function(on)
			H.Cache.HopForAutoCrow = on
			if on then
				H.Cache.CrowHadAny = false
				H.Cache.CrowEmptySince = nil
			end
		end,
	}, "HopForAutoCrow")
	
	mainLeft:Toggle({
		Name = "Auto Quest",
		Default = false,
		Callback = function(on)
			H.setState("AutoQuest", on, 1, function()
				if not H.canRunFeature("Quest") then return end
				H.fire("QuestRequestState")
				task.wait(0.3)
				H.fire("QuestCollect")
			end)
		end,
	}, "AutoQuest")
	
	mainLeft:Toggle({
		Name = "Auto Side Quest",
		Default = false,
		Callback = function(on)
			H.setState("AutoSideQuest", on, 1.5, function()
				if not H.canRunFeature("SideQuest") then return end
				H.fire("SideQuestRequestState", "__active")
				task.wait(0.3)
				for _, qid in ipairs({ "NinjaQuest", "TitanQuest", "SlayerQuest" }) do
					H.fire("SideQuestAcceptRequest", qid)
				end
			end)
		end,
	}, "AutoSideQuest")
	
	mainLeft:Toggle({
		Name = "Auto Buy + Travel Worlds",
		Default = false,
		Callback = function(on)
			H.setState("AutoBuyWorld", on, 5, function()
				for _, label in ipairs(WorldLabels) do
					H.fire("BuyWorld", tonumber(WorldMap[label]))
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
				H.notify("HMZ Hub", "Redeeming all codes...", 4)
				local n = H.redeemAll(function() return true end)
				H.notify("HMZ Hub", "Sent " .. n .. " new codes", 5)
			end)
		end,
	})
	
	mainRight:Toggle({
		Name = "Auto Redeem Codes",
		Default = false,
		Callback = function(on)
			H.setState("AutoRedeem", on, 300, function()
				H.redeemAll(function() return S.AutoRedeem end)
			end)
		end,
	}, "AutoRedeem")
	
	mainRight:Toggle({
		Name = "Auto Rank Up",
		Default = false,
		Callback = function(on)
			S.AutoRankUp = on
			H.fire("RankUp", "SetAutoRankUp", on)
		end,
	}, "AutoRankUp")
	
	mainRight:Toggle({
		Name = "Equip Best Avatar (Auto)",
		Default = false,
		Callback = function(on)
			S.AutoAvatar = on
			H.fire("AutoAvatarBuffSet", on)
		end,
	}, "AutoAvatar")
	
	mainRight:Toggle({
		Name = "Auto Arise",
		Default = false,
		Callback = function(on)
			S.AutoArise = on
			H.fire("RaidAutoArise", on)
		end,
	}, "AutoArise")
	
	mainRight:Toggle({
		Name = "Auto Daily Chest",
		Default = false,
		Callback = function(on)
			H.setState("AutoDailyChest", on, 30, function()
				H.fire("ChestClaim", "Daily")
			end)
		end,
	}, "AutoDailyChest")
	
	mainRight:Toggle({
		Name = "Auto Group Chest",
		Default = false,
		Callback = function(on)
			H.setState("AutoGroupChest", on, 30, function()
				H.fire("ChestClaim", "Group")
			end)
		end,
	}, "AutoGroupChest")
	
	mainRight:Toggle({
		Name = "Auto Claim Rewards (Daily/Time)",
		Default = false,
		Callback = function(on)
			S.AutoRewards = on
			H.fire("AutoClaimRewardsSet", on)
			if on then
				H.invoke("ClaimAllDailyRewards")
				H.invoke("ClaimAllTimeRewards")
			end
		end,
	}, "AutoRewards")
	
	local gmLeft = H.wrapSection(TabGamemode:Section({ Side = "Left" }))
	local gmRight = H.wrapSection(TabGamemode:Section({ Side = "Right" }))
	
	function H.farmFeatureId()
		local gm = H.getActiveGamemode()
		if gm == "Trial" then return "Trial" end
		if gm == "Gate" then return "Gate" end
		if gm == "Defense" then return "Defense" end
		if gm == "InfiniteCastle" then return "InfiniteCastle" end
		if gm == "Raid" then return "Raid" end
		return "Raid"
	end
	
	function H.joinRaidFeatureId(raidKey)
		if H.isInfiniteCastleKey(raidKey) then return "InfiniteCastle" end
		return "Raid"
	end
	
	function H.gamemodeBlock(section, title, joinBridge, leaveBridge, configName, getAllMethod, targetKey, farmKey, joinKey, openKey, openCache, useCreate)
		section:Header({ Text = title })
		local labels, map = {}, {}
		local c = H.require(H.ConfigFolder, configName)
		if c and c[getAllMethod] then
			local ok, all = pcall(function() return c[getAllMethod](c) end)
			if ok and type(all) == "table" then labels, map = H.namedOptions(all) end
		end
		if #labels == 0 then labels = { "World0" } end
		local selected = { value = map[labels[1]] or labels[1] }
		H.Cache.GamemodeSel = H.Cache.GamemodeSel or {}
		H.Cache.GamemodeSel[title] = selected
		section:Dropdown({
			Name = title .. " Selection",
			Options = labels,
			Default = 1,
			Callback = function(v)
				selected.value = map[v] or v
				H.savedSet("gamemodeValues", title, selected.value)
			end,
		}, title .. "Sel")
		section:Toggle({
			Name = "Auto Join " .. title,
			Default = false,
			Callback = function(on)
				H.setState(joinKey, on, 3, function()
					if H.isLoading() then return end
					if title == "Trial" then
						if not H.canRunFeature("Trial") then return end
						if H.getActiveGamemode() == "Trial" then return end
						local session = H.trialSession()
						if session.handled or session.inTrial or session.joining or session.leavingForTrial or session.resuming then return end
						if not H.isTrialOpen() then return end
						if H.Cache.AutoLeaveForTrial then
							H.prepareTrialLeave()
						end
						H.tryJoinOpenTrial(selected.value)
						return
					end
					if title == "Raid" then
						local feature = H.joinRaidFeatureId(selected.value)
						if not H.canRunFeature(feature) then return end
						if feature == "InfiniteCastle" and H.getResourceCount("InfinityCastleKey") < 1 then return end
					elseif title == "Defense" then
						if not H.canRunFeature("Defense") then return end
					end
					H.applyLoadout(title)
					if useCreate then
						H.fire(joinBridge, "Create", selected.value)
					else
						H.fire(joinBridge, "Join", selected.value)
					end
				end)
			end,
		}, joinKey)
		if openKey then
			section:Toggle({
				Name = "Auto Join Open " .. title .. "s",
				Default = false,
				Callback = function(on)
					H.setState(openKey, on, 3, function()
						if H.isLoading() then return end
						local pool = openCache == "Trial" and H.Cache.OpenTrials or (openCache == "Defense" and H.Cache.OpenDefenses or H.Cache.OpenRaids)
						if type(pool) ~= "table" then return end
						if openCache == "Trial" then
							if not H.canRunFeature("Trial") then return end
							if not H.hasOpenTrial() then return end
							if H.Cache.AutoLeaveForTrial then
								H.prepareTrialLeave()
							end
							H.tryJoinOpenTrial()
							return
						end
						if openCache == "Defense" then
							if not H.canRunFeature("Defense") then return end
						end
						for k, v in pairs(pool) do
							if v == true and type(k) == "string" then
								if openCache == "Raid" then
									local feature = H.joinRaidFeatureId(k)
									if not H.canRunFeature(feature) then return end
									if feature == "InfiniteCastle" and H.getResourceCount("InfinityCastleKey") < 1 then return end
								end
								H.applyLoadout(title)
								H.fire(joinBridge, "Join", k)
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
				H.setState(farmKey, on, 0.3, function()
					local feature
					if title == "Trial" then
						feature = "Trial"
					elseif title == "Defense" then
						feature = "Defense"
					elseif title == "Raid" then
						feature = H.farmFeatureId()
					else
						feature = title
					end
					if not H.canRunFeature(feature) then return end
					local t, radius = H.farmTarget(nil, true, Cache[targetKey], H.Cache.FarmIntelligent)
					H.attackTarget(t, radius)
				end)
			end,
		}, farmKey)
	end
	
	H.gamemodeBlock(gmLeft, "Trial", "TimeTrialJoin", "TimeTrialLeave", "TimeTrialConfig", "GetAllTrials", "TrialTarget", "FarmTrial", "JoinTrial", "JoinOpenTrial", "Trial", false)
	
	gmLeft:Toggle({
		Name = "Auto Leave Gamemode For Trial",
		Default = false,
		Callback = function(on)
			H.Cache.AutoLeaveForTrial = on
			H.setState("AutoLeaveForTrial", on, 2, function()
				if not H.Cache.AutoLeaveForTrial then return end
				if not H.hasOpenTrial() then return end
				local mode = H.getActiveGamemode()
				if not mode or mode == "Trial" then return end
				H.prepareTrialLeave()
				if not S.JoinOpenTrial then
					H.tryJoinOpenTrial()
				end
			end)
		end,
	}, "AutoLeaveForTrial")
	H.gamemodeBlock(gmLeft, "Raid", "RaidJoin", "RaidLeave", "RaidConfig", "GetAllRaids", "RaidTarget", "FarmRaid", "JoinRaid", "JoinOpenRaid", "Raid", true)
	H.gamemodeBlock(gmLeft, "Defense", "DefenseJoin", "DefenseLeave", "DefenseConfig", "GetAllDefenses", "DefenseTarget", "FarmDefense", "JoinDefense", "JoinOpenDefense", "Defense", true)
	
	gmLeft:Header({ Text = "Gate" })
	gmLeft:Toggle({
		Name = "Auto Gate",
		Default = false,
		Callback = function(on)
			H.setState("AutoGate", on, 3, function()
				if not H.canRunFeature("Gate") then return end
				if H.isLoading() then return end
				local state = H.invoke("GetRaidGateState", "World5")
				if type(state) == "table" and state.IsOpen then
					H.applyLoadout("GateE")
					H.fire("RaidGateTeleport", "World5")
				end
			end)
		end,
	}, "AutoGate")
	gmLeft:Dropdown({
		Name = "Gate Target",
		Options = { "Nearest", "Highest HP", "Lowest HP" },
		Default = 1,
		Callback = function(v) H.Cache.GateTarget = v end,
	}, "GateTarget")
	gmLeft:Toggle({
		Name = "Auto Farm Gate",
		Default = false,
		Callback = function(on)
			H.setState("FarmGate", on, 0.3, function()
				if not H.canRunFeature("Gate") then return end
				local t, radius = H.farmTarget(nil, true, H.Cache.GateTarget, H.Cache.FarmIntelligent)
				H.attackTarget(t, radius)
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
			H.setState("AutoLeaveFloor", on, 1, H.autoLeaveFloorTick)
		end,
	}, "AutoLeaveFloor")
	H.buildLeaveFloorUI(gmRight)
	
	local ldLeft = H.wrapSection(TabLoadout:Section({ Side = "Left" }))
	local ldRight = H.wrapSection(TabLoadout:Section({ Side = "Right" }))
	
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
			Callback = function(v) H.Cache.LoadoutMap[ctx.key] = v end,
		}, "LD_" .. ctx.key)
	end
	
	ldRight:Header({ Text = "Auto Pause Boost" })
	local PotionLabels = H.require(H.ConfigFolder, "PotionConfig")
	PotionLabels = PotionLabels and PotionLabels.Items
	local potList = {}
	if type(PotionLabels) == "table" then
		for k in pairs(PotionLabels) do potList[#potList + 1] = k end
	end
	ldRight:Toggle({
		Name = "Auto Pause Boost",
		Default = false,
		Callback = function(on)
			H.setState("AutoPause", on, 2, function()
				if H.Cache.InGamemode then return end
				H.fire("PotionState", { Request = true })
				for id, info in pairs(Cache.Potions) do
					if type(info) == "table" and info.Paused ~= true then
						H.fire("PotionPauseToggle", id)
					end
				end
			end)
		end,
	}, "AutoPause")
	ldRight:Toggle({
		Name = "Auto Unpause Boost Gamemode",
		Default = false,
		Callback = function(on)
			H.setState("AutoUnpause", on, 2, function()
				local active = H.getActiveGamemode()
				H.Cache.InGamemode = active ~= nil
				if not active then return end
				H.fire("PotionState", { Request = true })
				for id, info in pairs(Cache.Potions) do
					if type(info) == "table" and info.Paused == true then
						H.fire("PotionPauseToggle", id)
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
		Callback = function(v) H.Cache.UsePotions = H.multiToList(v) end,
	}, "UsePotions")
	ldRight:Toggle({
		Name = "Auto Use Potion",
		Default = false,
		Callback = function(on)
			H.setState("AutoUsePotion", on, 5, function()
				if H.Cache.UsePotions then
					for _, id in ipairs(Cache.UsePotions) do
						H.fire("UsePotion", id, 1)
						task.wait(0.3)
					end
				end
			end)
		end,
	}, "AutoUsePotion")
	
	local shopLeft = H.wrapSection(TabShop:Section({ Side = "Left" }))
	local shopRight = H.wrapSection(TabShop:Section({ Side = "Right" }))
	
	shopLeft:Header({ Text = "Auto Star" })
	local EggLabels, EggMap = H.configOptions("EggsData")
	shopLeft:Dropdown({
		Name = "Map",
		Options = EggLabels,
		Default = 1,
		Callback = function(v) H.Cache.StarEgg = EggMap[v] or v end,
	}, "StarEgg")
	shopLeft:Toggle({
		Name = "Auto Star",
		Default = false,
		Callback = function(on)
			H.setState("AutoStar", on, 0.6, function()
				if not H.canRunFeature("Star") then return end
				H.applyLoadout("Star")
				if H.Cache.StarEgg then H.fire("OpenEgg", H.Cache.StarEgg, {}) end
			end)
		end,
	}, "AutoStar")
	
	shopLeft:Header({ Text = "Auto Sword" })
	local SwordLabels, SwordMap = H.configOptions("SwordConfig", "Swords")
	shopLeft:Dropdown({
		Name = "Sword Banner",
		Options = SwordLabels,
		Default = 1,
		Callback = function(v) H.Cache.SwordBanner = SwordMap[v] or v end,
	}, "SwordBanner")
	shopLeft:Toggle({
		Name = "Auto Sword",
		Default = false,
		Callback = function(on)
			H.setState("AutoSword", on, 0.6, function()
				if H.Cache.SwordBanner then H.fire("SwordRoll", H.Cache.SwordBanner) end
			end)
		end,
	}, "AutoSword")
	
	shopLeft:Header({ Text = "Auto Sword Passive" })
	local spc = H.require(H.ConfigFolder, "SwordPassiveConfig")
	local scfg = H.require(H.ConfigFolder, "SwordConfig")
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
			H.Cache.SwordPassiveRarity = v
			H.Cache.SwordPassiveIndex = 1
			H.refreshSwordPassiveQueue()
		end,
	}, "SwordPassiveRarity")
	shopLeft:Dropdown({
		Name = "Stop On Passive",
		Search = true,
		Options = SwordPassiveTargetLabels,
		Default = 1,
		Callback = function(v)
			H.Cache.SwordPassiveTargetName = v
			H.Cache.SwordPassiveTargetId = SwordPassiveTargetMap[v]
			H.Cache.SwordPassiveIndex = 1
			H.refreshSwordPassiveQueue()
		end,
	}, "SwordPassiveTarget")
	shopLeft:Toggle({
		Name = "Auto Sword Passive",
		Default = false,
		Callback = function(on)
			if on then
				if not H.Cache.SwordPassiveRarity then
					H.Cache.SwordPassiveRarity = SwordPassiveRarityOptions[1]
				end
				H.Cache.SwordPassiveIndex = 1
				H.refreshSwordPassiveQueue()
				if type(Cache.SwordPassiveQueue) ~= "table" or #Cache.SwordPassiveQueue == 0 then
					H.notify("HMZ Hub", "No swords for " .. tostring(Cache.SwordPassiveRarity), 5)
					S.AutoSwordPassive = false
					task.defer(function()
						local el = H.UI.AutoSwordPassive
						if el and el.UpdateState then el:UpdateState(false) end
					end)
					return
				end
				local sk = (spc and spc.SystemKey) or "World6"
				H.fire("SwordPassiveStateRequest", sk)
			end
			H.setState("AutoSwordPassive", on, 1.1, H.autoSwordPassiveTick)
		end,
	}, "AutoSwordPassive")
	
	shopLeft:Header({ Text = "Auto Defense Shop" })
	local DefShopLabels, DefShopMap = H.shopProducts("DefenseShopConfig", "World4")
	shopLeft:Dropdown({
		Name = "Defense Products",
		Multi = true,
		Search = true,
		Options = DefShopLabels,
		Callback = function(v) H.Cache.DefShopBuy = H.multiToList(v, DefShopMap) end,
	}, "DefShopBuy")
	shopLeft:Toggle({
		Name = "Auto Defense Shop",
		Default = false,
		Callback = function(on)
			H.setState("AutoDefShop", on, 1, function()
				if H.Cache.DefShopBuy then
					for _, pid in ipairs(Cache.DefShopBuy) do
						H.fire("DefenseShopBuy", "World4", pid)
						task.wait(0.3)
					end
				end
			end)
		end,
	}, "AutoDefShop")
	
	shopRight:Header({ Text = "Auto Exchange" })
	local exc = H.require(H.ConfigFolder, "ExchangeConfig")
	local ExLabels, ExMap = {}, {}
	if exc and exc.Recipes then ExLabels, ExMap = H.namedOptions(exc.Recipes) end
	shopRight:Dropdown({
		Name = "Exchange Recipes",
		Multi = true,
		Search = true,
		Options = ExLabels,
		Callback = function(v) H.Cache.ExchangeBuy = H.multiToList(v, ExMap) end,
	}, "ExchangeBuy")
	shopRight:Slider({
		Name = "Exchange Amount",
		Default = 10,
		Minimum = 1,
		Maximum = 1000,
		DisplayMethod = "Round",
		Callback = function(v) H.Cache.ExchangeAmt = v end,
	}, "ExchangeAmt")
	shopRight:Toggle({
		Name = "Auto Exchange",
		Default = false,
		Callback = function(on)
			H.setState("AutoExchange", on, 1, function()
				if H.Cache.ExchangeBuy then
					for _, rid in ipairs(Cache.ExchangeBuy) do
						H.fire("ExchangeCraftRequest", rid, H.Cache.ExchangeAmt or 10)
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
		Callback = function(v) H.Cache.ShopPotions = H.multiToList(v) end,
	}, "ShopPotions")
	shopRight:Toggle({
		Name = "Auto Potions",
		Default = false,
		Callback = function(on)
			H.setState("AutoShopPotions", on, 5, function()
				if H.Cache.ShopPotions then
					for _, id in ipairs(Cache.ShopPotions) do
						H.fire("UsePotion", id, 1)
						task.wait(0.3)
					end
				end
			end)
		end,
	}, "AutoShopPotions")
	
	shopRight:Header({ Text = "Auto Trial Shop" })
	local TrialShopLabels, TrialShopMap = H.shopProducts("TrialShopConfig", "World0")
	shopRight:Dropdown({
		Name = "Trial Products",
		Multi = true,
		Search = true,
		Options = TrialShopLabels,
		Callback = function(v) H.Cache.TrialShopBuy = H.multiToList(v, TrialShopMap) end,
	}, "TrialShopBuy")
	shopRight:Toggle({
		Name = "Auto Trial Shop",
		Default = false,
		Callback = function(on)
			H.setState("AutoTrialShop", on, 1, function()
				if H.Cache.TrialShopBuy then
					for _, pid in ipairs(Cache.TrialShopBuy) do
						H.fire("TrialShopBuy", "World0", pid)
						task.wait(0.3)
					end
				end
			end)
		end,
	}, "AutoTrialShop")
	
	shopRight:Header({ Text = "Auto Merchant" })
	local MerchLabels, MerchMap = H.shopProducts("MerchantConfig", "Merchant")
	shopRight:Dropdown({
		Name = "Merchant Items",
		Multi = true,
		Search = true,
		Options = MerchLabels,
		Callback = function(v) H.Cache.MerchantBuy = H.multiToList(v, MerchMap) end,
	}, "MerchantBuy")
	shopRight:Toggle({
		Name = "Auto Merchant",
		Default = false,
		Callback = function(on)
			H.setState("AutoMerchant", on, 1, function()
				if H.Cache.MerchantBuy then
					for _, pid in ipairs(Cache.MerchantBuy) do
						H.fire("MerchantBuy", "Merchant", pid)
						task.wait(0.3)
					end
				end
			end)
		end,
	}, "AutoMerchant")
	
	shopRight:Header({ Text = "Titan Shop" })
	local TitanLabels, TitanMap = H.configOptions("TitansConfig", "Titans")
	shopRight:Dropdown({
		Name = "Titan Banner",
		Options = TitanLabels,
		Default = 1,
		Callback = function(v) H.Cache.TitanBanner = TitanMap[v] or v end,
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
			H.setState("TitanRoll", on, 0.6, function()
				if H.Cache.TitanBanner then H.fire("TitanRoll", H.Cache.TitanBanner) end
			end)
		end,
	}, "TitanRoll")
	
	local upLeft = H.wrapSection(TabUpgrade:Section({ Side = "Left" }))
	local upRight = H.wrapSection(TabUpgrade:Section({ Side = "Right" }))
	
	upLeft:Header({ Text = "Auto Upgrade - Upgrades" })
	upLeft:Dropdown({
		Name = "Upgrades",
		Multi = true,
		Options = UpgradeOptions,
		Callback = function(v) H.Cache.Upgrades = H.multiToList(v) end,
	}, "Upgrades")
	upLeft:Toggle({
		Name = "Auto Upgrade Upgrades",
		Default = false,
		Callback = function(on)
			H.setState("AutoUpgrade", on, 0.8, function()
				if H.Cache.Upgrades then
					for _, id in ipairs(Cache.Upgrades) do
						H.fire("UpgradesRequest", "World0", id)
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
		Callback = function(v) H.Cache.CastleUpgrades = H.multiToList(v) end,
	}, "CastleUpgrades")
	upLeft:Toggle({
		Name = "Auto Upgrade Castle Upgrades",
		Default = false,
		Callback = function(on)
			H.setState("AutoCastle", on, 0.8, function()
				if H.Cache.CastleUpgrades then
					for _, id in ipairs(Cache.CastleUpgrades) do
						H.fire("UpgradesRequest", "World6", id)
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
			H.setState("AutoRange", on, 0.8, function()
				H.fire("RangeUpgradeRequest", "World0")
			end)
		end,
	}, "AutoRange")
	
	upRight:Header({ Text = "Auto Gacha" })
	local GachaLabels, GachaMap = H.configOptions("GachaConfig", "Gachas")
	upRight:Dropdown({
		Name = "Banner",
		Options = GachaLabels,
		Default = 1,
		Callback = function(v) H.Cache.GachaBanner = GachaMap[v] or v end,
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
			H.setState("AutoGacha", on, 0.6, function()
				if H.Cache.GachaBanner then H.fire("GachaRoll", H.Cache.GachaBanner) end
			end)
		end,
	}, "AutoGacha")
	
	upRight:Header({ Text = "Auto Passives" })
	upRight:Toggle({
		Name = "Auto Passive Roll",
		Default = false,
		Callback = function(on)
			H.setState("AutoPassiveRoll", on, 0.8, function()
				H.fire("PlayerPassiveRoll")
			end)
		end,
	}, "AutoPassiveRoll")
	local ppc = H.require(H.ConfigFolder, "PlayerPassiveConfig")
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
		Callback = function(v) H.Cache.EquipPassive = v end,
	}, "EquipPassive")
	upRight:Toggle({
		Name = "Auto Equip Passive",
		Default = false,
		Callback = function(on)
			H.setState("AutoEquipPassive", on, 3, function()
				if H.Cache.EquipPassive then H.fire("PlayerPassiveEquip", H.Cache.EquipPassive) end
			end)
		end,
	}, "AutoEquipPassive")
	
	upRight:Header({ Text = "Auto Progression" })
	local ProgLabels, ProgMap = H.configOptions("ProgressionConfig", "Progressions")
	upRight:Dropdown({
		Name = "Progressions",
		Multi = true,
		Options = ProgLabels,
		Callback = function(v)
			local prev = H.Cache.ProgSelected or {}
			local now = H.multiToList(v, ProgMap)
			local nowSet = {}
			for _, k in ipairs(now) do nowSet[k] = true end
			if S.AutoProgression then
				for _, k in ipairs(prev) do
					if not nowSet[k] then H.fire("ProgressionAutoSet", k, false) end
				end
				for _, k in ipairs(now) do H.fire("ProgressionAutoSet", k, true) end
			end
			H.Cache.ProgSelected = now
		end,
	}, "ProgSelected")
	upRight:Toggle({
		Name = "Auto Progression",
		Default = false,
		Callback = function(on)
			S.AutoProgression = on
			if H.Cache.ProgSelected then
				for _, k in ipairs(Cache.ProgSelected) do
					H.fire("ProgressionAutoSet", k, on)
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
			if S.AutoStatPoint and H.Cache.StatPoint and H.Cache.StatPoint ~= v then
				H.fire("AutoStatPointSet", H.Cache.StatPoint, false)
			end
			H.Cache.StatPoint = v
			if S.AutoStatPoint then H.fire("AutoStatPointSet", v, true) end
		end,
	}, "StatPoint")
	upRight:Toggle({
		Name = "Auto Stat Point",
		Default = false,
		Callback = function(on)
			S.AutoStatPoint = on
			if H.Cache.StatPoint then H.fire("AutoStatPointSet", H.Cache.StatPoint, on) end
		end,
	}, "AutoStatPoint")
	
	local tpLeft = H.wrapSection(TabTeleport:Section({ Side = "Left" }))
	local tpRight = H.wrapSection(TabTeleport:Section({ Side = "Right" }))
	
	tpLeft:Header({ Text = "Worlds" })
	tpLeft:Dropdown({
		Name = "World",
		Search = true,
		Options = WorldLabels,
		Default = 1,
		Callback = function(v) H.Cache.TpWorld = WorldMap[v] end,
	}, "TpWorld")
	tpLeft:Button({
		Name = "Teleport To World",
		Callback = function()
			if H.Cache.TpWorld then
				H.waitLoad(5)
				H.fire("RequestChangeWorld", tonumber(Cache.TpWorld))
			end
		end,
	})
	tpLeft:Button({
		Name = "Respawn In World",
		Callback = function() H.fire("RespawnInWorld") end,
	})
	
	tpRight:Header({ Text = "Teleporters" })
	local tpDest = tpRight:Dropdown({
		Name = "Destination",
		Search = true,
		Options = {},
		Callback = function(v) H.Cache.TpDest = v end,
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
			H.notify("HMZ Hub", "Found " .. #dests .. " teleporters", 3)
		end,
	})
	tpRight:Button({
		Name = "Teleport",
		Callback = function()
			if H.Cache.TpDest then H.fire("TeleporterRequest", H.Cache.TpDest) end
		end,
	})
	
	local whLeft = H.wrapSection(TabWebhook:Section({ Side = "Left" }))
	whLeft:Header({ Text = "Discord Webhook" })
	whLeft:Input({
		Name = "Webhook URL",
		Placeholder = "https://discord.com/api/webhooks/...",
		Callback = function(text) H.Cache.WebhookUrl = text end,
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
		Callback = function() H.webhook("HMZ Hub webhook connected.") end,
	})
	
	local setLeft = H.wrapSection(TabSettings:Section({ Side = "Left" }))
	setLeft:Header({ Text = "Jeu actif" })
	setLeft:Paragraph({
		Header = H.GameCfg.Name,
		Body = "PlaceId: " .. tostring(H.PLACE_ID) .. "\nGameId: " .. tostring(H.GAME_ID) .. "\nModule: " .. H.GameId,
	})
	setLeft:Header({ Text = "Settings" })
	setLeft:Slider({
		Name = "UI Scale",
		Default = H.savedGet("settings", "UIScale", 100),
		Minimum = 50,
		Maximum = 150,
		DisplayMethod = "Round",
		Callback = function(v)
			H.savedSet("settings", "UIScale", v)
			pcall(function() H.Window:SetScale(v / 100) end)
		end,
	}, "UIScale")
	setLeft:Toggle({
		Name = "Hide Username",
		Default = false,
		Callback = function(on) pcall(function() H.Window:SetUserInfoState(not on) end) end,
	}, "HideUser")
	local blackFrame
	setLeft:Toggle({
		Name = "Blackscreen Mode",
		Default = false,
		Callback = function(on)
			if on then
				if not blackFrame then
					local sg = Instance.new("ScreenGui")
					sg.Name = "H.Black"
					sg.IgnoreGuiInset = true
					sg.ResetOnSpawn = false
					sg.DisplayOrder = 9999
					local f = Instance.new("Frame")
					f.Size = UDim2.fromScale(1, 1)
					f.BackgroundColor3 = Color3.new(0, 0, 0)
					f.BorderSizePixel = 0
					f.Parent = sg
					pcall(function() sg.Parent = game:GetService("CoreGui") end)
					if not sg.Parent then sg.Parent = H.LocalPlayer:WaitForChild("PlayerGui") end
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
		Callback = function() pcall(function() H.Window:SetState(not H.Window:GetState()) end) end,
	}, "ToggleUI")
	setLeft:Button({
		Name = "Unload",
		Callback = function()
			for k in pairs(H.S) do H.S[k] = false end
			H.restoreCharacter()
			pcall(function() H.Window:Unload() end)
		end,
	})
	end

	function H.buildUI()
		H._buildUI()
	end
end

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
end)

if not ok then
	hmzFail(tostring(err))
end