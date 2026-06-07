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
local THIRD_SEA_PLACE_IDS = {
    [7449423635] = true,
    [100117331123089] = true,
}
local TRAVEL_TO_THIRD_SEA_PLACE_IDS = {
    [4442272183] = true,
    [79091703265657] = true,
    [2753915549] = true,
    [85211729168715] = true,
}

local function kickPlayer()
    warn("[AutoBuild] Kicking player to clear PS bug...")
    game.Players:FindFirstChild(LocalPlayer.Name):Kick("[AutoBuild] Clearing PS bug")
end

local function getStatusFileName()
    return LocalPlayer.Name .. "-autoBuild.json"
end

local function writeTravelStatus(fromPlaceId)
    writefile(getStatusFileName(), HttpService:JSONEncode({
        status = "traveled",
        autoBuildTravel = true,
        userId = LocalPlayer.UserId,
        fromPlaceId = fromPlaceId,
        targetSea = "ThirdSea",
        createdAt = os.time()
    }))
end

local function isThirdSea(placeId)
    return THIRD_SEA_PLACE_IDS[placeId] == true
end

local function shouldTravelToThirdSea(placeId)
    return TRAVEL_TO_THIRD_SEA_PLACE_IDS[placeId] == true
end

local function readTravelStatus()
    local statusFileName = getStatusFileName()
    if not isfile(statusFileName) then return nil end

    local rawStatus = readfile(statusFileName)
    warn("[AutoBuild] Status file found: " .. rawStatus)

    local ok, data = pcall(function()
        return HttpService:JSONDecode(rawStatus)
    end)
    if not ok or type(data) ~= "table" then
        return nil, statusFileName
    end

    if data.status == "traveled"
        and data.autoBuildTravel == true
        and data.userId == LocalPlayer.UserId
        and data.targetSea == "ThirdSea"
    then
        return data, statusFileName
    end

    return nil, statusFileName
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

local function StopTween()
    if NoClipConnection then
        NoClipConnection:Disconnect()
        NoClipConnection = nil
    end
    if BodyVelocity then
        BodyVelocity:Destroy()
        BodyVelocity = nil
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
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1e5
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = rootPart

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

        local dist = (rootPart.Position - targetPos).Magnitude
        if dist <= 8 then
            BodyVelocity.Velocity = Vector3.zero
            StopTween()
        else
            BodyVelocity.Velocity = (targetPos - rootPart.Position).Unit * 300
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


-- Fruit is intentionally not checked so accounts keep whatever fruit they have.
local function isLoadoutGood()
    local config = getgenv().AutoLoadout
    local currentSword, currentGun, _, currentWear, currentFightingStyle, _, ownedSwords, ownedGuns = getEquippedItems()
    local currentRace = getRace()

    local function matchesAny(current, list)
        list = type(list) == "table" and list or {list}
        for _, v in ipairs(list) do
            if v ~= "" and current == v then return true end
        end
        return false
    end

    if not matchesAny(currentRace, config.race) then return false end
    if not matchesAny(currentFightingStyle, config.fightingStyles) then return false end
    if not matchesAny(currentSword, config.sword) then return false end
    if not matchesAny(currentGun, config.gun) then return false end

    local wears = type(config.wear) == "table" and config.wear or {config.wear}
    for _, wear in ipairs(wears) do
        if wear ~= "" and string.find(currentWear, wear, 1, true) then return true end
    end
    return false
end

local function runPostLoad()
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

local function applyLoadout()
    if not getgenv().AutoLoadout.autoEquip then
        return
    end
    warn("[AutoBuild] Checking loadout...")

    if isLoadoutGood() then
        warn("[AutoBuild] Loadout already correct, skipping equip and running post-load.")
        runPostLoad()
        return
    end

    if getgenv().AutoLoadout.autoTravel then
        local placeId = game.PlaceId
        if isThirdSea(placeId) then
            warn("[AutoBuild] Already in Sea 3, proceeding with equip...")
        elseif shouldTravelToThirdSea(placeId) then
            warn("[AutoBuild] In Sea 2 or Sea 1, traveling to Sea 3 first...")
            writeTravelStatus(placeId)
            ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("TravelZou")
            task.wait(2)
            kickPlayer()
            return
        else
            warn("[AutoBuild] Unknown PlaceId: " .. placeId .. ")")
            return
        end
    end

    local currentSword, currentGun, _, currentWear, currentFightingStyle, wearUIDs, ownedSwords, ownedGuns = getEquippedItems()
    local config = getgenv().AutoLoadout

    warn("[AutoBuild] Sword=" .. currentSword .. " | Gun=" .. currentGun .. " | Wear=" .. currentWear .. " | FightingStyle=" .. currentFightingStyle)

    warn("[AutoBuild] Checking race...")
    local currentRace = getRace()
    local desiredRaces = type(config.race) == "table" and config.race or {config.race}
    warn("[AutoBuild] Desired races: " .. table.concat(desiredRaces, ", "))

    while true do
        local raceMatches = false
        for _, race in ipairs(desiredRaces) do
            if currentRace == race then
                raceMatches = true
                break
            end
        end

        if not raceMatches then
            local fragmentsValue = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Fragments")
            local fragments = fragmentsValue and fragmentsValue.Value or 0
            if fragments < 3000 then
                warn("[AutoBuild] Skipping reroll — Fragments too low: " .. fragments .. " / 3000")
                break
            end
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
    _, _, _, _, currentFightingStyle = getEquippedItems()
    for _, style in ipairs(fightingStyles) do
        if style ~= "" then
            if currentFightingStyle == style then
                warn("[AutoBuild] Fighting style already equipped: " .. style)
                foundOwned = true
                break
            else
                warn("[AutoBuild] Attempting to buy fighting style: " .. style)
                local result = buyFightingStyle(style)
                _, _, _, _, currentFightingStyle = getEquippedItems()
                if result then
                    foundOwned = true
                    break
                end
            end
        end
    end
    if not foundOwned then
        warn("[AutoBuild] No fighting style could be equipped or bought from config.")
    end

    currentSword, currentGun, _, currentWear, _, wearUIDs, ownedSwords, ownedGuns = getEquippedItems()

    warn("[AutoBuild] Checking swords...")
    local swords = type(config.sword) == "table" and config.sword or {config.sword}
    for _, sword in ipairs(swords) do
        if sword ~= "" then
            if ownedSwords[sword] then
                if currentSword == sword then
                    warn("[AutoBuild] Sword already equipped: " .. sword)
                else
                    warn("[AutoBuild] Equipping sword: " .. sword)
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("LoadItem", sword)
                    task.wait(0.5)
                end
                break
            else
                warn("[AutoBuild] Sword not found in inventory: " .. sword)
            end
        end
    end

    warn("[AutoBuild] Checking guns...")
    local guns = type(config.gun) == "table" and config.gun or {config.gun}
    for _, gun in ipairs(guns) do
        if gun ~= "" then
            if ownedGuns[gun] then
                if currentGun == gun then
                    warn("[AutoBuild] Gun already equipped: " .. gun)
                else
                    warn("[AutoBuild] Equipping gun: " .. gun)
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("LoadItem", gun)
                    task.wait(0.5)
                end
                break
            else
                warn("[AutoBuild] Gun not found in inventory: " .. gun)
            end
        end
    end

    warn("[AutoBuild] Checking wear...")
    local wears = type(config.wear) == "table" and config.wear or {config.wear}
    for _, wear in ipairs(wears) do
        if wear ~= "" then
            if wearUIDs[wear] then
                if string.find(currentWear, wear, 1, true) then
                    warn("[AutoBuild] Wear already equipped: " .. wear)
                else
                    warn("[AutoBuild] Equipping wear: " .. wear)
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("LoadItem", wearUIDs[wear])
                    task.wait(0.5)
                end
                break
            else
                warn("[AutoBuild] Wear not found in inventory: " .. wear)
            end
        end
    end

    warn("[AutoBuild] Loadout applied!")
    runPostLoad()
end

task.spawn(function()
    warn("[AutoBuild] Script loaded. Checking status file...")
    local travelStatus, statusFileName = readTravelStatus()
    if statusFileName then
        delfile(statusFileName)
        if travelStatus and isThirdSea(game.PlaceId) then
            warn("[AutoBuild] Previous Sea 3 travel detected, kicking player...")
            kickPlayer()
            return
        elseif travelStatus then
            warn("[AutoBuild] Travel status found outside Sea 3, continuing normally.")
        else
            warn("[AutoBuild] Ignoring old or unrelated travel status.")
        end
    end
    warn("[AutoBuild] Waiting 10 seconds before applying loadout...")
    task.wait(10)
    applyLoadout()
end)
