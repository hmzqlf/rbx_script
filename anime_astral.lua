if game.PlaceId ~= 113236157544232 then return end

if _G.AutoFarmCleanup then
    pcall(_G.AutoFarmCleanup)
    _G.AutoFarmCleanup = nil
    task.wait(0.2)
end

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TrialLibrary
pcall(function()
    TrialLibrary = require(ReplicatedStorage:WaitForChild("SimpleWorld"):WaitForChild("Library"))
end)

local autoFarmEnabled = false
local selectedWorld = "1"
local selectedMob = nil
local farmThread = nil

local trialAutoEnabled = false
local trialWaveLeave = 0
local trialInProgress = false
local trialLeaveRequested = false
local trialKillRunning = false
local currentTrialKey = nil
local savedPosition = nil
local returnAfterTrial = false

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

local function HMZ_startTrialKillLoop(trialKey)
    if trialKillRunning then return end
    trialKillRunning = true
    task.spawn(function()
        while trialInProgress and trialAutoEnabled do
            local arenas = workspace:FindFirstChild("TimeTrialArenas")
            if arenas then
                local arena = arenas:FindFirstChild(trialKey)
                if arena then
                    for _, desc in ipairs(arena:GetDescendants()) do
                        if not (trialInProgress and trialAutoEnabled) then break end
                        if not desc:IsA("Model") then continue end
                        local initHP = HMZ_getHealthReal(desc)
                        if initHP == nil or initHP < 1 then continue end
                        local hrp = desc:FindFirstChild("HumanoidRootPart")
                            or desc:FindFirstChild("Torso")
                            or desc.PrimaryPart
                        if not hrp then continue end
                        HMZ_teleportTo(hrp.CFrame)
                        local prevHP = initHP
                        local died = false
                        local conn = desc:GetAttributeChangedSignal("HealthReal"):Connect(function()
                            local hp = HMZ_getHealthReal(desc)
                            if not hp then return end
                            if hp < 1 then
                                died = true
                            elseif prevHP < (initHP * 0.5) and hp >= (initHP * 0.9) then
                                died = true
                            end
                            prevHP = hp
                        end)
                        local timeout = os.clock() + 20
                        while not died and desc.Parent ~= nil and os.clock() < timeout and trialInProgress and trialAutoEnabled do
                            task.wait(0.3)
                        end
                        conn:Disconnect()
                    end
                end
            end
            task.wait(0.5)
        end
        trialKillRunning = false
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

local GamemodeTab = TabGroup:Tab({
    Name = "Gamemode",
    Image = "rbxassetid://10723407389",
})

local GamemodeLeft = GamemodeTab:Section({ Side = "Left" })
local GamemodeRight = GamemodeTab:Section({ Side = "Right" })

GamemodeLeft:Toggle({
    Name = "Auto Trial",
    Default = false,
    Callback = function(value)
        trialAutoEnabled = value
        if not value then
            trialInProgress = false
            trialLeaveRequested = false
        end
    end,
})

GamemodeLeft:Slider({
    Name = "Wave Leave (0 = off)",
    Minimum = 0,
    Maximum = 50,
    Default = 0,
    DisplayMethod = "Round",
    Callback = function(value)
        trialWaveLeave = value
    end,
})

GamemodeRight:Button({
    Name = "Save Position",
    Callback = function()
        local hrp = HMZ_getHRP()
        if hrp then
            savedPosition = hrp.CFrame
        end
    end,
})

GamemodeRight:Toggle({
    Name = "Return to saved position after trial",
    Default = false,
    Callback = function(value)
        returnAfterTrial = value
    end,
})

if TrialLibrary then
    local joinBridge = TrialLibrary.getBridge("TimeTrialJoin")
    local stateBridge = TrialLibrary.getBridge("TimeTrialState")
    local leaveBridge = TrialLibrary.getBridge("TimeTrialLeave")
    local activeBridge = TrialLibrary.getBridge("TimeTrialActiveStatus")
    local endedBridge = TrialLibrary.getBridge("TimeTrialEnded")

    if activeBridge then
        activeBridge:Connect(function(count, scheduleData)
            if not trialAutoEnabled then return end
            if type(scheduleData) ~= "table" then return end
            if scheduleData.IsOpen ~= true then return end
            local key = scheduleData.OpenTrialKey
            if type(key) ~= "string" or key == "" then return end
            currentTrialKey = key
            if joinBridge then
                joinBridge:Fire("Join", key)
            end
        end)
    end

    if stateBridge then
        stateBridge:Connect(function(state)
            if not trialAutoEnabled then return end
            if not trialInProgress and not trialLeaveRequested then
                trialInProgress = true
                if currentTrialKey then
                    HMZ_startTrialKillLoop(currentTrialKey)
                end
            end
            if trialWaveLeave > 0 and state.Room >= trialWaveLeave and trialInProgress and not trialLeaveRequested then
                trialLeaveRequested = true
                trialInProgress = false
                if leaveBridge then
                    leaveBridge:Fire()
                end
            end
        end)
    end

    if endedBridge then
        endedBridge:Connect(function(key, reason)
            trialInProgress = false
            trialKillRunning = false
            trialLeaveRequested = false
            if reason == "returned" and returnAfterTrial and savedPosition then
                task.wait(1.5)
                HMZ_teleportTo(savedPosition)
            end
        end)
    end
end

_G.AutoFarmCleanup = function()
    HMZ_stopAutoFarm()
    trialAutoEnabled = false
    trialInProgress = false
    trialLeaveRequested = false
    pcall(function() Window:Unload() end)
end
