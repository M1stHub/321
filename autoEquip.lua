repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

task.spawn(function()
    local plr = game.Players.LocalPlayer
    local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
    local tries = 0
    while not plr.Team and tries < 10 do
        local ok, err = pcall(function()
            Remotes.CommF_:InvokeServer("SetTeam", "Marines")
        end)
        tries = tries + 1
        task.wait(1)
    end
    if plr.Team and plr.Team.Name == "Marines" then
        warn("[AutoBuild] Successfully joined Marines team!")
    else
        warn("[AutoBuild] Failed to join Marines team after " .. tries .. " tries.")
    end
end)

local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local function kickPlayer()
    warn("[AutoBuild] Kicking player to clear PS bug...")
    game.Players:FindFirstChild(LocalPlayer.Name):Kick("[AutoBuild] Clearing PS bug")
end

getgenv().AutoLoadout = getgenv().AutoLoadout or {
    race = { "Fishman" },
    fightingStyles = { "Sharkman Karate", "Sanguine Art" },
    sword = { "Dragonheart", "True Triple Katana" },
    gun = { "Skull Guitar", "Venom Bow" },
    fruit = { "Lightning-Lightning", "Sound-Sound" },
    wear = { "Leviathan Shield", "Swan Glasses" },
    autoEquip = true,
    autoTravel = true
}

local FightingStyleLocations = {
    ["Sanguine Art"] = CFrame.new(-16515, 23, -192),
    ["Fishman Karate"] = CFrame.new(-4984, 315, -3208),
    ["Superhuman"] = CFrame.new(-4984, 315, -3208),
    ["Death Step"] = CFrame.new(-4984, 315, -3208),
    ["Sharkman Karate"] = CFrame.new(-4984, 315, -3208),
    ["Electric Claw"] = CFrame.new(-10373, 332, -10130),
    ["Dragon Talon"] = CFrame.new(5664, 1211, 865),
    ["Godhuman"] = CFrame.new(-13772, 335, -9878)
}

local FightingStyleBuyRemotes = {
    ["Sanguine Art"] = "BuySanguineArt",
    ["Fishman Karate"] = "BuyFishmanKarate",
    ["Superhuman"] = "BuySuperhuman",
    ["Death Step"] = "BuyDeathStep",
    ["Sharkman Karate"] = "BuySharkmanKarate",
    ["Electric Claw"] = "BuyElectricClaw",
    ["Dragon Talon"] = "BuyDragonTalon",
    ["Godhuman"] = "BuyGodhuman"
}

local NoClipConnection
local BodyVelocity
local BodyGyro

local function StopTween()
    if NoClipConnection then
        NoClipConnection:Disconnect()
        NoClipConnection = nil
    end
    if BodyVelocity then
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        BodyGyro:Destroy()
        BodyGyro = nil
    end

    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                part.CanTouch = true
            end
        end
    end
end

local function TweenTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return end

    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
    if not rootPart then return end

    StopTween()
    task.wait(0.1)

    local targetPos = targetCFrame.Position

    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = rootPart

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    BodyGyro.P = 9e4
    BodyGyro.Parent = rootPart

    NoClipConnection = RunService.Stepped:Connect(function()
        if not char or not char.Parent then
            StopTween()
            return
        end

        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanTouch = false
            end
        end

        local distance = (rootPart.Position - targetPos).Magnitude

        if distance > 3 then
            local direction = (targetPos - rootPart.Position).Unit
            BodyVelocity.Velocity = direction * 300
            BodyGyro.CFrame = CFrame.new(rootPart.Position, targetPos)
        elseif distance > 1 then
            local direction = (targetPos - rootPart.Position).Unit
            BodyVelocity.Velocity = direction * (distance * 30)
            BodyGyro.CFrame = CFrame.new(rootPart.Position, targetPos)
        else
            BodyVelocity.Velocity = Vector3.zero
            StopTween()
        end
    end)
end

local function WaitForTween()
    while NoClipConnection and BodyVelocity do
        task.wait(0.1)
    end
    task.wait(0.5)
end

local function getEquippedItems()
    local args = { "getInventory" }
    local inventory = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
    if type(inventory) ~= "table" then
        warn("[AutoBuild] Inventory data is not a table! Got: " .. tostring(inventory))
        inventory = {}
    end

    local equippedSword = "None"
    local equippedGun = "None"
    local equippedFruit = "None"
    local equippedWear = "None"
    local equippedFightingStyle = "None"
    local wearUIDs = {}
    local ownedSwords = {}
    local ownedGuns = {}
    local ownedFruits = {}

    local playerData = LocalPlayer:FindFirstChild("Data")
    if playerData then
        local devilFruit = playerData:FindFirstChild("DevilFruit")
        if devilFruit and devilFruit.Value ~= "" then
            equippedFruit = devilFruit.Value
        end
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                for styleName, _ in pairs(FightingStyleBuyRemotes) do
                    if tool.Name == styleName then
                        equippedFightingStyle = styleName
                        break
                    end
                end
            end
        end
    end

    for _, item in pairs(inventory) do
        if type(item) == "table" then
            if item.Type == "Sword" and item.Name then
                ownedSwords[item.Name] = true
                if item.Equipped == true then
                    equippedSword = item.Name
                end
            elseif item.Type == "Gun" and item.Name then
                ownedGuns[item.Name] = true
                if item.Equipped == true then
                    equippedGun = item.Name
                end
            elseif item.Type == "Blox Fruit" and item.Name then
                ownedFruits[item.Name] = true
            elseif item.Type == "Wear" and item.Name and item.NetworkedUID then
                wearUIDs[item.Name] = item.NetworkedUID
                if item.Equipped == true and not string.find(item.Name, "Ring of") then
                    if equippedWear == "None" then
                        equippedWear = item.Name
                    else
                        equippedWear = equippedWear .. ", " .. item.Name
                    end
                end
            end
        end
    end

    return equippedSword, equippedGun, equippedFruit, equippedWear, equippedFightingStyle, wearUIDs, ownedSwords, ownedGuns, ownedFruits
end

local function getRace()
    local playerData = LocalPlayer:FindFirstChild("Data")
    if playerData then
        local raceValue = playerData:FindFirstChild("Race")
        if raceValue then
            return raceValue.Value
        end
    end
    return "Human"
end

local function rerollRace()
    local fragmentsValue = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Fragments")
    local fragments = fragmentsValue and fragmentsValue.Value or 0
    if fragments < 3000 then
        warn("[AutoBuild] Skipping reroll — Fragments too low: " .. fragments .. " / 3000")
        return getRace()
    end
    warn("[AutoBuild] Rolling for new race...")
    local Event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
    local Result = Event:InvokeServer("BlackbeardReward", "Reroll", "2")
    warn("[AutoBuild] Reroll result: " .. tostring(Result))
    task.wait(1)
    return getRace()
end

local function buyFightingStyle(styleName)
    local remote = FightingStyleBuyRemotes[styleName]
    if not remote then
        warn("[AutoBuild] Unknown fighting style: " .. styleName)
        return false
    end

    warn("[AutoBuild] Tweening to " .. styleName .. " NPC...")
    local location = FightingStyleLocations[styleName]
    TweenTo(location)
    WaitForTween()

    warn("[AutoBuild] Buying fighting style: " .. styleName)
    local Event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
    local Result = Event:InvokeServer(remote)
    task.wait(1)

    warn("[AutoBuild] Buy result for " .. styleName .. ": " .. tostring(Result))
    if Result == 0 then
        warn("[AutoBuild] Failed to buy " .. styleName .. ", moving to next...")
        return false
    else
        warn("[AutoBuild] Successfully obtained " .. styleName)
        return true
    end
end


local function applyLoadout()
    if not getgenv().AutoLoadout.autoEquip then
        return
    end
    warn("[AutoBuild] Checking loadout...")

    if getgenv().AutoLoadout.autoTravel then
        local placeId = game.PlaceId
        if placeId == 7449423635 then
            warn("[AutoBuild] Already in Sea 3, proceeding with equip...")
        elseif placeId == 4442272183 or placeId == 2753915549 then
            warn("[AutoBuild] In Sea 2 or Sea 1, traveling to Sea 3 first...")
            local statusFileName = LocalPlayer.Name .. "-autoBuild.json"
            writefile(statusFileName, '{"status": "traveled"}')
            ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("TravelZou")
            task.wait(2)
            kickPlayer()
            return
        else
            warn("[AutoBuild] Unknown PlaceId: " .. placeId .. ")")
            return
        end
    end

    local equipData = {}
    local currentSword, currentGun, currentFruit, currentWear, currentFightingStyle, wearUIDs, ownedSwords, ownedGuns, ownedFruits = getEquippedItems()
    local config = getgenv().AutoLoadout

    warn("Current: Sword=" .. currentSword .. " | Gun=" .. currentGun .. " | Fruit=" .. currentFruit .. " | Wear=" .. currentWear .. " | FightingStyle=" .. currentFightingStyle)

    warn("[AutoBuild] Checking race...")
    local currentRace = getRace()
    local desiredRaces = type(config.race) == "table" and config.race or {config.race}
    warn("[AutoBuild] Desired races: " .. table.concat(desiredRaces, ", "))

    local raceMatches = false
    while not raceMatches do
        local raceMatches = false
        for _, race in ipairs(desiredRaces) do
            if currentRace == race then
                raceMatches = true
                break
            end
        end

        if not raceMatches then
            warn("[AutoBuild] Current race: " .. currentRace .. " - does not match desired. Rerolling...")
            currentRace = rerollRace()
            warn("[AutoBuild] New race after reroll: " .. currentRace)
        else
            warn("[AutoBuild] Successfully got desired race: " .. currentRace)
            break
        end
    end

    warn("[AutoBuild] Checking fighting styles...")
    local fightingStyles = type(config.fightingStyles) == "table" and config.fightingStyles or {config.fightingStyles}
    local foundOwned = false
    equipData = {}
    currentSword, currentGun, currentFruit, currentWear, currentFightingStyle, wearUIDs, ownedSwords, ownedGuns, ownedFruits = getEquippedItems()
    for _, style in ipairs(fightingStyles) do
        if style ~= "" then
            local fsResult = equipData[style]
            if fsResult == 2 or fsResult == 1 then
                if currentFightingStyle ~= style then
                    warn("[AutoBuild] Equipping owned fighting style: " .. style)
                    buyFightingStyle(style)
                    task.wait(0.5)
                    equipData = {}
                    currentSword, currentGun, currentFruit, currentWear, currentFightingStyle, wearUIDs, ownedSwords, ownedGuns, ownedFruits = getEquippedItems()
                else
                    warn("[AutoBuild] Fighting style already equipped: " .. style)
                end
                equipData[style] = 2
                foundOwned = true
                break
            elseif fsResult == 0 then
                warn("[AutoBuild] Skipping " .. style .. " (previously failed to obtain)")
            else
                warn("[AutoBuild] Attempting to buy fighting style: " .. style)
                local result = buyFightingStyle(style) and 1 or 0
                equipData[style] = result
                equipData = {}
                currentSword, currentGun, currentFruit, currentWear, currentFightingStyle, wearUIDs, ownedSwords, ownedGuns, ownedFruits = getEquippedItems()
                if result == 1 or result == 2 then
                    foundOwned = true
                    break
                end
            end
        end
    end
    if not foundOwned then
        warn("[AutoBuild] No fighting style could be equipped or bought from config.")
    end
    local fruitsData = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("GetFruits", false)
    local permanentFruits = {}
    if type(fruitsData) == "table" then
        for _, fruit in ipairs(fruitsData) do
            if type(fruit) == "table" and fruit.HasPermanent and fruit.Name then
                permanentFruits[fruit.Name] = true
            end
        end
    end
    local fruitToEquip = nil
    for _, fruit in ipairs(type(config.fruit)=="table" and config.fruit or {config.fruit}) do
        if fruit ~= "" then
            local fResult = equipData[fruit]
            if fResult == 0 then
                warn("[AutoBuild] Skipping " .. fruit .. " (previously failed to obtain)")
            elseif permanentFruits[fruit] then
                fruitToEquip = fruit
                break
            end
        end
    end
    if fruitToEquip then
        if currentFruit == fruitToEquip then
            equipData[fruitToEquip] = 2
            warn("[AutoBuild] Fruit already equipped: " .. fruitToEquip)
        else
            warn("[AutoBuild] Equipping fruit: " .. fruitToEquip)
            ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("SwitchFruit", fruitToEquip)
            task.wait(0.5)
            equipData[fruitToEquip] = 1
        end
    else
        warn("[AutoBuild] No permanent fruit found or all skipped.")
    end
    local swords = type(config.sword) == "table" and config.sword or {config.sword}
    for _, sword in ipairs(swords) do
        if sword ~= "" then
            local sResult = equipData[sword]
            if sResult == 0 then
                warn("[AutoBuild] Skipping " .. sword .. " (previously failed to obtain)")
            elseif sResult == 2 then
                warn("[AutoBuild] Skipping " .. sword .. " (already owned)")
            elseif ownedSwords[sword] then
                if currentSword == sword then
                    equipData[sword] = 2
                    warn("[AutoBuild] Sword already equipped: " .. sword)
                else
                    warn("[AutoBuild] Equipping sword: " .. sword)
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("LoadItem", sword)
                    task.wait(0.5)
                    equipData[sword] = 1
                end
                break
            else
                warn("[AutoBuild] Sword not found in inventory: " .. sword .. ", marking as failed.")
                equipData[sword] = 0
            end
        end
    end
    local guns = type(config.gun) == "table" and config.gun or {config.gun}
    for _, gun in ipairs(guns) do
        if gun ~= "" then
            local gResult = equipData[gun]
            if gResult == 0 then
                warn("[AutoBuild] Skipping " .. gun .. " (previously failed to obtain)")
            elseif gResult == 2 then
                warn("[AutoBuild] Skipping " .. gun .. " (already owned)")
            elseif ownedGuns[gun] then
                if currentGun == gun then
                    equipData[gun] = 2
                    warn("[AutoBuild] Gun already equipped: " .. gun)
                else
                    warn("[AutoBuild] Equipping gun: " .. gun)
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("LoadItem", gun)
                    task.wait(0.5)
                    equipData[gun] = 1
                end
                break
            else
                warn("[AutoBuild] Gun not found in inventory: " .. gun .. ", marking as failed.")
                equipData[gun] = 0
            end
        end
    end
    local wears = type(config.wear) == "table" and config.wear or {config.wear}
    for _, wear in ipairs(wears) do
        if wear ~= "" then
            local wResult = equipData[wear]
            if wResult == 0 then
                warn("[AutoBuild] Skipping " .. wear .. " (previously failed to obtain)")
            elseif wResult == 2 then
                warn("[AutoBuild] Skipping " .. wear .. " (already owned)")
            elseif wearUIDs[wear] then
                if string.find(currentWear, wear) then
                    equipData[wear] = 2
                    warn("[AutoBuild] Wear already equipped: " .. wear)
                else
                    warn("[AutoBuild] Equipping wear: " .. wear)
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("LoadItem", wearUIDs[wear])
                    task.wait(0.5)
                    equipData[wear] = 1
                end
                break
            else
                warn("[AutoBuild] Wear not found in inventory: " .. wear .. ", marking as failed.")
                equipData[wear] = 0

            end
        end
    end

    warn("[AutoBuild] Loadout applied!")

    if getgenv().AutoBuildPostLoad then
        if type(getgenv().AutoBuildPostLoad) == "function" then
            task.spawn(function()
                local ok, err = pcall(getgenv().AutoBuildPostLoad)
                if not ok then warn("[AutoBuild] Error running post-equip function: " .. tostring(err)) end
            end)
        elseif type(getgenv().AutoBuildPostLoad) == "table" then
            task.spawn(function()
                for _, entry in ipairs(getgenv().AutoBuildPostLoad) do
                    if type(entry) == "string" then
                        local ok, err = pcall(function()
                            warn("[AutoBuild] Loading post-equip script: " .. entry)
                            loadstring(game:HttpGet(entry))()
                        end)
                        if not ok then warn("[AutoBuild] Error loading post-equip script: " .. tostring(err)) end
                    elseif type(entry) == "function" then
                        local ok, err = pcall(entry)
                        if not ok then warn("[AutoBuild] Error running post-equip function: " .. tostring(err)) end
                    end
                end
            end)
        end
    else
        print("[AutoBuild] No post-equip scripts defined.")
    end

end

task.spawn(function()
    warn("[AutoBuild] Script loaded. Checking status file...")
    local statusFileName = LocalPlayer.Name .. "-autoBuild.json"
    if isfile(statusFileName) then
        local status = readfile(statusFileName)
        warn("[AutoBuild] Status file found: " .. status)
        if string.find(status, '"traveled"') then
            warn("[AutoBuild] Previous travel detected, kicking player...")
            delfile(statusFileName)
            kickPlayer()
            return
        end
    end
    warn("[AutoBuild] Waiting 10 seconds before applying loadout...")
    task.wait(10)
    applyLoadout()
end)
