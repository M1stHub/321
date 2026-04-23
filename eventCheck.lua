local cfg = getgenv().EventCheckConfig or {}
local HttpService = game:GetService("HttpService")
local requestFunc = request or http_request or (syn and syn.request)

local function sendSwitchWebhook(direction)
    local sw = cfg.switchWebhook
    if not sw or not sw.url or not requestFunc then return end
    local Players = game:GetService("Players")
    if Players.LocalPlayer.Name ~= sw.senderAccount then return end
    pcall(function()
        requestFunc({
            Url = sw.url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "mode switch",
                embeds = {{
                    title = "Mode Switch",
                    description = direction,
                    color = direction:find("Dungeons") and 0x00BFFF or 0xFF6600,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            })
        })
    end)
end

local function isInDungeon()
    local leaderstats = game:GetService("Players").LocalPlayer:FindFirstChild("leaderstats")
    return leaderstats and leaderstats:FindFirstChild("Damage") ~= nil
end

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

local DataRemote = game.ReplicatedStorage.DungeonShared:WaitForChild("DataRemote")

local Players = game:GetService("Players")

local playerName = Players.LocalPlayer.Name
local FLAG_FILE = playerName .. "-MistFlag.txt"

local DUNGEON_MIN_ENERGY = 10
local DUNGEON_START_ENERGY = 50

local lastFlag = nil
local dungeonStarted = false
local leviStarted = false

local function startDungeons()
    if dungeonStarted or not cfg.executeDungeons then return end
    if game.PlaceId ~= 73902483975735 then return end
    dungeonStarted = true
    task.spawn(function()
        local ok, err = pcall(cfg.executeDungeons)
        if not ok then warn("[EventCheck] executeDungeons error: " .. tostring(err)) end
    end)
end

local function startLevi()
    if leviStarted or not cfg.executeLevi then return end
    leviStarted = true
    task.spawn(function()
        local ok, err = pcall(cfg.executeLevi)
        if not ok then warn("[EventCheck] executeLevi error: " .. tostring(err)) end
    end)
end

local function getEnergy()
    local data = DataRemote:InvokeServer("GetData")
    return math.floor(data.CurrentEnergy)
end

local function readFlag()
    if isfile(FLAG_FILE) then return readfile(FLAG_FILE) end
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

local function switchToLevi()
    setFlag("Leviathan")
    sendSwitchWebhook("→ Leviathan")
    local allAccounts = (getgenv().EventCheckConfig or {}).allowedAccounts or {}
    for _, name in ipairs(allAccounts) do
        if name ~= playerName then
            pcall(writefile, name .. "-MistFlag.txt", "Leviathan")
        end
    end
    startLevi()
end

local function switchToDungeons(fromLevi)
    if lastFlag ~= "Dungeons" then
        setFlag("Dungeons")
        sendSwitchWebhook("→ Dungeons")
        local allAccounts = (getgenv().EventCheckConfig or {}).allowedAccounts or {}
        for _, name in ipairs(allAccounts) do
            if name ~= playerName then
                pcall(writefile, name .. "-MistFlag.txt", "Dungeons")
            end
        end
    end
    if fromLevi then waitForLeviDone() end
    startDungeons()
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
            else
                startDungeons()
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
            startLevi()
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

if isInDungeon() then
    startDungeons()
else
    local ok, err = pcall(update)
    if not ok then warn("[EventCheck] update() error: " .. tostring(err)) end
end

DataRemote.OnClientInvoke = function(p, ...)
    if p == "DataUpdated" then
        if isInDungeon() then return end
        local ok, err = pcall(update)
        if not ok then warn("[EventCheck] update() error: " .. tostring(err)) end
    end
end

task.spawn(function()
    while true do
        task.wait(30)
        if not isInDungeon() then
            local ok, err = pcall(update)
            if not ok then warn("[EventCheck] poll error: " .. tostring(err)) end
        end
    end
end)
