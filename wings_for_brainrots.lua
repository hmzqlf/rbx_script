-- Wings for Brainrots Hub
local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer  = Players.LocalPlayer
local LogZoneReach = ReplicatedStorage.Funnels.LogZoneReach
local CarryDisplay = ReplicatedStorage.Events.UpdateCarryDisplay

-- ──────────────────────────────────────────────
-- Window
-- ──────────────────────────────────────────────
local Window = MacLib:Window({
    Title        = "Wings for Brainrots",
    Subtitle     = "v1.0",
    Size         = UDim2.fromOffset(868, 550),
    DragStyle    = 1,
    ShowUserInfo = true,
    Keybind      = Enum.KeyCode.RightControl,
    AcrylicBlur  = true,
})

local TabGroup = Window:TabGroup()

-- ──────────────────────────────────────────────
-- TAB : Movement
-- ──────────────────────────────────────────────
local MovementTab  = TabGroup:Tab({ Name = "Movement" })
local MovementLeft = MovementTab:Section({ Side = "Left" })

local flyEnabled = false
local flySpeed   = 60
local bodyVelocity, bodyGyro, flyConnection

local function startFly()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp      = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity  = Vector3.zero
    bodyVelocity.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Parent    = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bodyGyro.P         = 1e4
    bodyGyro.CFrame    = hrp.CFrame
    bodyGyro.Parent    = hrp

    flyConnection = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir += cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir -= cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir += Vector3.new(0,1,0)    end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0)    end
        bodyVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
        bodyGyro.CFrame       = cam.CFrame
    end)
end

local function stopFly()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if bodyVelocity  then bodyVelocity:Destroy();    bodyVelocity  = nil end
    if bodyGyro      then bodyGyro:Destroy();         bodyGyro      = nil end
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.PlatformStand = false end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    if flyEnabled then task.wait(1); startFly() end
end)

MovementLeft:Toggle({
    Name     = "Fly",
    Default  = false,
    Callback = function(value)
        flyEnabled = value
        if value then startFly() else stopFly() end
    end,
}, "FlyToggle")

MovementLeft:Slider({
    Name          = "Fly Speed",
    Default       = flySpeed,
    Minimum       = 10,
    Maximum       = 300,
    DisplayMethod = "Value",
    Callback      = function(value) flySpeed = value end,
}, "FlySpeedSlider")

-- ──────────────────────────────────────────────
-- TAB : Collect
-- ──────────────────────────────────────────────
local CollectTab   = TabGroup:Tab({ Name = "Collect" })
local CollectLeft  = CollectTab:Section({ Side = "Left" })
local CollectRight = CollectTab:Section({ Side = "Right" })

local collectEnabled    = false
local collectRarity     = "Cosmic"
local collectDelay      = 0.3
local requiredMutations = {}
local basePosition      = Vector3.new(-47, 3, -41)
local collectThread     = nil
local currentCarry      = {}   -- carry accumulé, même format que le serveur

-- Zone de spawn par rareté : le joueur doit être proche pour déclencher les spawns
-- Les raretés sans position définie ne feront pas de TP vers la zone de spawn
local spawnZones = {
    Common    = nil,
    Uncommon  = nil,
    Rare      = nil,
    Epic      = nil,
    Legendary = nil,
    Mythical  = nil,
    Secret    = nil,
    Celestial = nil,
    Cosmic    = Vector3.new(21, 3, 6093),
    God       = nil,
    Exclusive = nil,
}

-- ── Helpers ──────────────────────────────────

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Cherche la position d'un item : PrimaryPart en priorité, sinon premier descendant BasePart
local function getItemPosition(item)
    if item:IsA("BasePart") then
        return item.Position
    end
    if item:IsA("Model") then
        if item.PrimaryPart then
            return item.PrimaryPart.Position
        end
        -- Pas de PrimaryPart → premier BasePart descendant
        for _, desc in ipairs(item:GetDescendants()) do
            if desc:IsA("BasePart") then return desc.Position end
        end
    end
    -- Fallback : WorldPivot si c'est un Model sans parts visibles
    local ok, pivot = pcall(function() return item:GetPivot() end)
    if ok then return pivot.Position end
    return nil
end

-- Lit toutes les mutations d'un item depuis ses attributs
local function getItemMutations(item)
    local result = {}
    local single = item:GetAttribute("Mutation")
    if single and single ~= "" and single ~= "None" then result[single] = true end
    for i = 1, 5 do
        local m = item:GetAttribute("Mutation" .. i)
        if m and m ~= "" and m ~= "None" then result[m] = true end
    end
    return result
end

local function itemPassesFilter(item)
    if not next(requiredMutations) then return true end
    local itemMuts = getItemMutations(item)
    for mut in pairs(requiredMutations) do
        if itemMuts[mut] then return true end
    end
    return false
end

-- Téléporte le HRP et attend le sync serveur
local function teleportTo(pos)
    local hrp = getHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
    task.wait(0.35)  -- sync serveur (suffisant pour la plupart des anti-cheat)
end

-- ── Boucle de collecte ───────────────────────

local function collectLoop()
    while collectEnabled do
        local itemSpawners = workspace:FindFirstChild("ItemSpawners")
        if not itemSpawners then task.wait(2); continue end

        local spawnerFolder = itemSpawners:FindFirstChild(collectRarity)
        if not spawnerFolder then task.wait(2); continue end

        local spawnZone = spawnZones[collectRarity]

        -- TP dans la zone de spawn et attendre que les items apparaissent réellement
        if spawnZone then
            teleportTo(spawnZone)
            -- Attendre jusqu'à 8s que des items spawn (distance-based)
            local waited = 0
            while #spawnerFolder:GetChildren() == 0 and waited < 8 do
                task.wait(0.5)
                waited += 0.5
            end
        end

        local items = spawnerFolder:GetChildren()

        if #items == 0 then
            task.wait(2)
            continue
        end

        for _, item in ipairs(items) do
            if not collectEnabled then break end
            if not item or not item.Parent then continue end
            if not itemPassesFilter(item) then continue end

            local pos = getItemPosition(item)
            if not pos then continue end

            -- 1. TP sur l'item
            teleportTo(pos)

            -- 2. Notifier le serveur (zone reach)
            LogZoneReach:FireServer(collectRarity)

            -- 3. Construire les données de l'item et mettre à jour le carry
            local itemData = {
                Name     = item.Name,
                Level    = item:GetAttribute("Level") or 1,
                Rarity   = collectRarity,
                Mutation = item:GetAttribute("Mutation") or "Normal",
            }
            table.insert(currentCarry, itemData)
            firesignal(CarryDisplay.OnClientEvent, currentCarry)

            task.wait(collectDelay)

            -- 4. Retour à la zone de spawn pour déclencher le prochain spawn
            if spawnZone then
                teleportTo(spawnZone)
                task.wait(0.3)
            end
        end

        -- Retour à la base + dépôt
        teleportTo(basePosition)
        task.wait(0.5)

        -- Vider le carry après dépôt à la base
        currentCarry = {}
        firesignal(CarryDisplay.OnClientEvent, {})

        task.wait(0.5)
    end
end

-- ── UI Gauche ─────────────────────────────────

CollectLeft:Toggle({
    Name     = "Auto Collect",
    Default  = false,
    Callback = function(value)
        collectEnabled = value
        if value then
            collectThread = task.spawn(collectLoop)
        else
            if collectThread then task.cancel(collectThread); collectThread = nil end
        end
    end,
}, "AutoCollectToggle")

CollectLeft:Dropdown({
    Name     = "Rareté",
    Search   = false,
    Multi    = false,
    Required = true,
    Options  = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Celestial", "Cosmic", "God", "Exclusive" },
    Default  = 1,
    Callback = function(value)
        collectRarity = value
    end,
}, "RarityDropdown")

CollectLeft:Slider({
    Name          = "Délai entre items (s)",
    Default       = collectDelay,
    Minimum       = 0.05,
    Maximum       = 2,
    Precision     = 2,
    DisplayMethod = "Value",
    Callback      = function(value) collectDelay = value end,
}, "CollectDelaySlider")

CollectLeft:Button({
    Name     = "Définir position de base ici",
    Callback = function()
        local hrp = getHRP()
        if hrp then basePosition = hrp.Position end
    end,
}, "SetBaseButton")

CollectLeft:Button({
    Name     = "Retourner à la base",
    Callback = function()
        if basePosition then teleportTo(basePosition) end
    end,
}, "GoBaseButton")

-- ── UI Droite ─────────────────────────────────

local mutationDropdown

CollectRight:Button({
    Name     = "Scanner les mutations",
    Callback = function()
        if not mutationDropdown then return end
        local found = {}
        local folder = workspace:FindFirstChild("ItemSpawners")
                   and workspace.ItemSpawners:FindFirstChild(collectRarity)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                for mut in pairs(getItemMutations(item)) do
                    if not found[mut] then
                        found[mut] = true
                    end
                end
            end
        end
        local list = {}
        for mut in pairs(found) do table.insert(list, mut) end
        table.sort(list)
        mutationDropdown:ClearOptions()
        if #list > 0 then mutationDropdown:InsertOptions(list) end
        requiredMutations = {}
    end,
}, "ScanMutationsButton")

mutationDropdown = CollectRight:Dropdown({
    Name     = "Filtrer par mutation",
    Search   = true,
    Multi    = true,
    Required = false,
    Options  = {},
    Callback = function(selection)
        requiredMutations = {}
        for mut, state in pairs(selection) do
            if state then requiredMutations[mut] = true end
        end
    end,
}, "MutationFilterDropdown")
