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
local HttpService = H.Services.HttpService

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

local H.canRunFeature

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

function H.notify(title, desc, life)
	if not Window then return end
	if H.Cache.Notifications == false then return end
	pcall(function()
		H.Window:Notify({ Title = title, Description = desc, Lifetime = life or 4 })
	end)
end

local H.DRAG = {
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

H.FarmStateKeys = H.FarmStateKeys or = {
	AutoFarmMob = true,
	FarmTrial = true,
	FarmRaid = true,
	FarmDefense = true,
	FarmGate = true,
}

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
