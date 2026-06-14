if game.PlaceId ~= 113236157544232 then return end

if _G.AutoFarmCleanup then
    pcall(_G.AutoFarmCleanup)
    _G.AutoFarmCleanup = nil
    task.wait(0.2)
end

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local autoFarmEnabled = false
local selectedWorld = "1"
local selectedMob = nil
local farmThread = nil

local worldNames = {
    ["1"] = "Ninja Village",
    ["2"] = "Namek City",
    ["3"] = "Wano Island",
    ["4"] = "Titan Wall",
    ["5"] = "Solo City",
    ["6"] = "Slayer Village",
}

local nameToWorld = {}
for k, v in pairs(worldNames) do
    nameToWorld[v] = k
end

local function HMZ_getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function HMZ_teleportTo(cf)
    local hrp = HMZ_getHRP()
    if hrp then
        hrp.CFrame = cf
    end
end

local function HMZ_getMobsInWorld(worldKey)
    local mobs = {}
    local worlds = workspace:FindFirstChild("Worlds")
    if not worlds then return mobs end
    local world = worlds:FindFirstChild(worldKey)
    if not world then return mobs end
    local enemies = world:FindFirstChild("Enemies")
    if not enemies then return mobs end
    for _, enemy in ipairs(enemies:GetChildren()) do
        if not table.find(mobs, enemy.Name) then
            table.insert(mobs, enemy.Name)
        end
    end
    return mobs
end

local function HMZ_getHealthReal(enemy)
    return enemy:GetAttribute("HealthReal")
end

local function HMZ_isAlive(enemy)
    if not enemy or not enemy.Parent then return false end
    local hp = HMZ_getHealthReal(enemy)
    return hp == nil or hp >= 1
end

local function HMZ_stopAutoFarm()
    autoFarmEnabled = false
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end
end

local function HMZ_startAutoFarm()
    autoFarmEnabled = true
    farmThread = task.spawn(function()
        while autoFarmEnabled do
            if not selectedMob or selectedMob == "" then
                task.wait(1)
                continue
            end

            local worlds = workspace:FindFirstChild("Worlds")
            if not worlds then task.wait(1) continue end
            local world = worlds:FindFirstChild(selectedWorld)
            if not world then task.wait(1) continue end
            local enemiesFolder = world:FindFirstChild("Enemies")
            if not enemiesFolder then task.wait(1) continue end

            local farmedAny = false

            for _, enemy in ipairs(enemiesFolder:GetChildren()) do
                if not autoFarmEnabled then break end
                if enemy.Name ~= selectedMob then continue end
                if not HMZ_isAlive(enemy) then continue end

                local rootPart = enemy:FindFirstChild("HumanoidRootPart")
                    or enemy:FindFirstChild("Torso")
                    or enemy.PrimaryPart
                if not rootPart then continue end

                farmedAny = true

                local initHP = HMZ_getHealthReal(enemy)

                HMZ_teleportTo(rootPart.CFrame)

                local died = false
                local prevHP = initHP

                local attrConn = enemy:GetAttributeChangedSignal("HealthReal"):Connect(function()
                    local hp = HMZ_getHealthReal(enemy)
                    if not hp then return end
                    if hp < 1 then
                        died = true
                    elseif prevHP ~= nil and prevHP < (initHP * 0.5) and hp >= (initHP * 0.9) then
                        died = true
                    end
                    prevHP = hp
                end)

                while autoFarmEnabled and not died and enemy.Parent ~= nil do
                    task.wait(0.3)
                end

                attrConn:Disconnect()
            end

            if not farmedAny then
                task.wait(0.5)
            end
        end
    end)
end

local Window = MacLib:Window({
    Title = "HMZ Hub",
    Subtitle = "Auto Farm",
    Size = UDim2.fromOffset(868, 520),
    DragStyle = 1,
    ShowUserInfo = false,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()

local FarmTab = TabGroup:Tab({
    Name = "Auto Farm",
    Image = "rbxassetid://10723407389",
})

local LeftSection = FarmTab:Section({ Side = "Left" })
local RightSection = FarmTab:Section({ Side = "Right" })

local MobDropdown

local worldOptions = {}
for i = 1, 6 do
    table.insert(worldOptions, worldNames[tostring(i)])
end

LeftSection:Dropdown({
    Name = "Monde",
    Search = false,
    Multi = false,
    Required = true,
    Options = worldOptions,
    Default = 1,
    Callback = function(value)
        local worldKey = nameToWorld[value]
        if not worldKey then return end

        selectedWorld = worldKey
        selectedMob = nil

        if MobDropdown then
            MobDropdown:ClearOptions()
            local mobs = HMZ_getMobsInWorld(worldKey)
            if #mobs > 0 then
                MobDropdown:InsertOptions(mobs)
            end
        end
    end,
})

local initialMobs = HMZ_getMobsInWorld("1")

MobDropdown = LeftSection:Dropdown({
    Name = "Mob à farmer",
    Search = true,
    Multi = false,
    Required = false,
    Options = initialMobs,
    Callback = function(value)
        selectedMob = value
    end,
})

RightSection:Toggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(value)
        if value then
            HMZ_startAutoFarm()
        else
            HMZ_stopAutoFarm()
        end
    end,
}, "AutoFarmToggle")

_G.AutoFarmCleanup = function()
    HMZ_stopAutoFarm()
    pcall(function() Window:Unload() end)
end
