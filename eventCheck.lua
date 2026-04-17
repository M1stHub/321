local cfg = getgenv().EventCheckConfig or {}

getgenv().leviInProgress = false

local function waitForGate()
    while true do
        local doorLeft = workspace:FindFirstChild("Map")
            and workspace.Map:FindFirstChild("LeviathanGate")
            and workspace.Map.LeviathanGate:FindFirstChild("DOORLEFT")
        if doorLeft then return end
        task.wait(1)
    end
end

local function waitForHeart()
    while true do
        if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("FrozenHeart") then
            return
        end
        task.wait(1)
    end
end

local function waitForHeartGone()
    while true do
        if not (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("FrozenHeart")) then
            return
        end
        task.wait(0.5)
    end
end

task.spawn(function()
    while true do
        waitForGate()
        getgenv().leviInProgress = true

        waitForHeart()
        waitForHeartGone()
        getgenv().leviInProgress = false

        task.wait(5)
    end
end)

local ReplicatedPlayerData = require(game:GetService("ReplicatedStorage").DungeonClient.ReplicatedPlayerData)
local Players = game:GetService("Players")

local playerName = Players.LocalPlayer.Name
local FLAG_FILE = playerName .. "-MistFlag.txt"

local DUNGEON_MIN_ENERGY = 8
local DUNGEON_START_ENERGY = 40

local lastFlag = nil

local function getEnergy()
    return math.floor(ReplicatedPlayerData.get().CurrentEnergy)
end

local function readFlag()
    if isfile(FLAG_FILE) then
        return readfile(FLAG_FILE)
    end
    return nil
end

local function setFlag(state)
    if lastFlag == state then return end
    lastFlag = state
    writefile(FLAG_FILE, state)
    print("[MistFlag] " .. playerName .. " → " .. state .. " (energy: " .. getEnergy() .. ")")
end

local function teleportToHub()
    pcall(function()
        local remote = require(game.ReplicatedStorage.Modules.Net):RemoteFunction("DungeonNPCNetworkFunction")
        remote:InvokeServer("TeleportToDungeonHub", false)
    end)
end

local function waitForLeviDone()
    if getgenv().leviInProgress then
        print("[MistFlag] Levi in progress — waiting for it to finish before teleporting")
        repeat task.wait(1) until not getgenv().leviInProgress
    end
    teleportToHub()
end

local function executeLevi()
    if not cfg.executeLevi then
        warn("[EventCheck] EventCheckConfig.executeLevi not set")
        return
    end
    print("[MistFlag] Executing levi script")
    pcall(cfg.executeLevi)
end

local function switchToLevi()
    if lastFlag == "Leviathan" then return end
    setFlag("Leviathan")
    executeLevi()
end

local function switchToDungeons(fromLevi)
    if lastFlag == "Dungeons" then return end
    setFlag("Dungeons")
    if fromLevi then
        waitForLeviDone()
    end
end

local function update()
    local energy = getEnergy()
    local flag = readFlag()

    if flag == "Dungeons" then
        if energy >= DUNGEON_MIN_ENERGY then
            setFlag("Dungeons")
            if game.PlaceId ~= 73902483975735 then
                print("[MistFlag] Flag is Dungeons but not in hub — teleporting")
                teleportToHub()
            end
        else
            print("[MistFlag] Energy too low (" .. energy .. ") — switching to Leviathan")
            switchToLevi()
        end

    elseif flag == "Leviathan" then
        if energy >= DUNGEON_START_ENERGY then
            print("[MistFlag] Energy refilled (" .. energy .. ") — switching to Dungeons")
            switchToDungeons(true)
        else
            setFlag("Leviathan")
        end

    else
        print("[MistFlag] No flag found — energy: " .. energy)
        if energy >= DUNGEON_START_ENERGY then
            switchToDungeons()
            if game.PlaceId ~= 73902483975735 then
                teleportToHub()
            end
        else
            switchToLevi()
        end
    end
end

update()

if ReplicatedPlayerData.OnUpdated and ReplicatedPlayerData.OnUpdated.Event then
    ReplicatedPlayerData.OnUpdated.Event:Connect(update)
end
