local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Players   = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ─── UI ───────────────────────────────────────────────────────────────────────

local Window = MacLib:Window({
    Title = "Citron Hub",
    Subtitle = "Lemon Stand",
    Size = UDim2.fromOffset(700, 500),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = false,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()
local MainTab  = TabGroup:Tab({ Name = "Main" })

local LeftSection  = MainTab:Section({ Side = "Left"  })
local RightSection = MainTab:Section({ Side = "Right" })

-- ─── HELPERS ──────────────────────────────────────────────────────────────────

-- Trouve le tycoon appartenant au joueur local.
-- Vérifie les patterns courants : ObjectValue "Owner", StringValue "Owner", attribut "Owner".
local function getMyTycoon()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:match("^Tycoon%d+$") then
            local ownerVal = obj:FindFirstChild("Owner")
            if ownerVal then
                if ownerVal:IsA("ObjectValue") and ownerVal.Value == LocalPlayer then
                    return obj
                elseif (ownerVal:IsA("StringValue") or ownerVal:IsA("IntValue")) then
                    if ownerVal.Value == LocalPlayer.Name or ownerVal.Value == LocalPlayer.UserId then
                        return obj
                    end
                end
            end
            local attr = obj:GetAttribute("Owner")
            if attr == LocalPlayer.Name or attr == LocalPlayer.UserId then
                return obj
            end
        end
    end
    return nil
end

-- Collecte récursivement tous les RemoteFunctions d'un nom donné sous root.
local function collectRemotes(root, name, results)
    results = results or {}
    for _, child in ipairs(root:GetChildren()) do
        if child.Name == name and child:IsA("RemoteFunction") then
            table.insert(results, child)
        else
            collectRemotes(child, name, results)
        end
    end
    return results
end

-- ─── AUTO COLLECT ALL ─────────────────────────────────────────────────────────

local autoCollect = false

LeftSection:Toggle({
    Name = "Auto Collect All",
    Default = false,
    Callback = function(enabled)
        autoCollect = enabled
        if enabled then
            task.spawn(function()
                while autoCollect do
                    pcall(function()
                        local tycoon = getMyTycoon()
                        if not tycoon then return end

                        local purchases = tycoon:FindFirstChild("Purchases")
                        if not purchases then return end

                        local remote = tycoon.Remotes.WakeIncomeStream
                        for _, stand in ipairs(purchases:GetChildren()) do
                            pcall(function()
                                -- Le serveur attend le nom sans espaces (ex: "Lemon Stand" → "LemonStand")
                                remote:InvokeServer(stand.Name:gsub(" ", ""))
                            end)
                            task.wait(0.1)
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        end
    end,
}, "AutoCollect")

-- ─── AUTO ACCEPT PHONE OFFER ──────────────────────────────────────────────────

local autoPhone = false

LeftSection:Toggle({
    Name = "Auto Accept Phone Offer",
    Default = false,
    Callback = function(enabled)
        autoPhone = enabled
        if enabled then
            task.spawn(function()
                while autoPhone do
                    pcall(function()
                        local tycoon = getMyTycoon()
                        if not tycoon then return end
                        tycoon.Remotes.PhoneOffer:FireServer("Accept")
                    end)
                    task.wait(1)
                end
            end)
        end
    end,
}, "AutoPhone")

-- ─── AUTO COLLECT FRUIT ───────────────────────────────────────────────────────

local autoFruit = false

LeftSection:Toggle({
    Name = "Auto Collect Fruit",
    Default = false,
    Callback = function(enabled)
        autoFruit = enabled
        if enabled then
            task.spawn(function()
                local FruitEvent = game:GetService("ReplicatedStorage").Core.RemoteSignal["ClickFruitService.Clicked"]
                while autoFruit do
                    pcall(function()
                        local tycoon = getMyTycoon()
                        if not tycoon then return end

                        local trees = tycoon:FindFirstChild("Constant")
                        trees = trees and trees:FindFirstChild("Trees")
                        if not trees then return end

                        for _, tree in ipairs(trees:GetChildren()) do
                            if tree.Name == "LemonTree" then
                                for _, fruit in ipairs(tree:GetChildren()) do
                                    if fruit.Name == "Fruit" and fruit:IsA("BasePart") then
                                        pcall(function()
                                            firesignal(FruitEvent.OnClientEvent,
                                                math.random(),
                                                fruit.Position,
                                                false
                                            )
                                        end)
                                        task.wait() -- prochain frame (~0.016s)
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.2)
                end
            end)
        end
    end,
}, "AutoFruit")

-- ─── AUTO UPGRADE ────────────────────────────────────────────────────────────

local autoUpgrade = false

RightSection:Toggle({
    Name = "Auto Upgrade",
    Default = false,
    Callback = function(enabled)
        autoUpgrade = enabled
        if enabled then
            task.spawn(function()
                while autoUpgrade do
                    pcall(function()
                        local tycoon = getMyTycoon()
                        if not tycoon then return end

                        local purchases = tycoon:FindFirstChild("Purchases")
                        if not purchases then return end

                        for _, event in ipairs(collectRemotes(purchases, "Upgrade")) do
                            pcall(function()
                                event:InvokeServer(1)
                            end)
                            task.wait(0.05)
                        end
                    end)
                    task.wait(2)
                end
            end)
        end
    end,
}, "AutoUpgrade")

-- ─── AUTO BUY ─────────────────────────────────────────────────────────────────
-- Event-driven : se déclenche immédiatement quand l'argent change.
-- Fallback poll toutes les 3s au cas où.

local autoBuy    = false
local autoBuyConn = nil

local function doBuy()
    local tycoon = getMyTycoon()
    if not tycoon then return end
    local purchases = tycoon:FindFirstChild("Purchases")
    if not purchases then return end
    for _, event in ipairs(collectRemotes(purchases, "Purchase")) do
        pcall(function()
            event:InvokeServer(false)
        end)
        task.wait(0.05)
    end
end

RightSection:Toggle({
    Name = "Auto Buy",
    Default = false,
    Callback = function(enabled)
        autoBuy = enabled

        if autoBuyConn then
            autoBuyConn:Disconnect()
            autoBuyConn = nil
        end

        if enabled then
            -- Tentative immédiate au démarrage
            task.spawn(pcall, doBuy)

            -- Réaction instantanée dès que l'argent augmente
            local stats = LocalPlayer:FindFirstChild("leaderstats")
            if stats then
                for _, v in ipairs(stats:GetChildren()) do
                    if v:IsA("IntValue") or v:IsA("NumberValue") then
                        local debounce = false
                        autoBuyConn = v.Changed:Connect(function()
                            if not autoBuy or debounce then return end
                            debounce = true
                            task.spawn(pcall, doBuy)
                            task.delay(0.3, function() debounce = false end)
                        end)
                        break
                    end
                end
            end

            -- Fallback poll lent
            task.spawn(function()
                while autoBuy do
                    pcall(doBuy)
                    task.wait(3)
                end
            end)
        end
    end,
}, "AutoBuy")
