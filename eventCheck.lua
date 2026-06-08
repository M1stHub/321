local cfg = getgenv().EventCheckConfig or {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local requestFunc = request or http_request or (syn and syn.request)

local allowedSet = {}
local hasAllowedAccounts = type(cfg.allowedAccounts) == "table" and #cfg.allowedAccounts > 0
if hasAllowedAccounts then
    for _, name in ipairs(cfg.allowedAccounts) do
        allowedSet[tostring(name)] = true
    end
end

local function sendSwitchWebhook(direction)
    local sw = cfg.switchWebhook
    if not sw or not sw.url or not requestFunc then return end
    if LocalPlayer.Name ~= sw.senderAccount then return end
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
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    return leaderstats and leaderstats:FindFirstChild("Damage") ~= nil
end

local function findRandomDungeonPlayer()
    if not hasAllowedAccounts then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if not allowedSet[player.Name] then
            return player
        end
    end
    return nil
end

local function kickIfRandomInDungeon()
    if not isInDungeon() then return false end
    local randomPlayer = findRandomDungeonPlayer()
    if not randomPlayer then return false end
    warn("[EventCheck] Random player detected in dungeon: " .. randomPlayer.Name)
    LocalPlayer:Kick("random detected")
    return true
end

local dungeonRandomMonitorStarted = false
local function startDungeonRandomMonitor()
    if dungeonRandomMonitorStarted then return end
    dungeonRandomMonitorStarted = true
    task.spawn(function()
        while isInDungeon() do
            if kickIfRandomInDungeon() then return end
            task.wait(1)
        end
        dungeonRandomMonitorStarted = false
    end)
end

getgenv().leviInProgress = false

local function setFpsCap(cap)
    if typeof(setfpscap) == "function" then
        pcall(setfpscap, cap)
    end
end

local function findInMap(...)
    local node = workspace:FindFirstChild("Map")
    for _, name in ipairs({...}) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

local function waitForGate()
    while true do
        if findInMap("LeviathanGate", "DOORLEFT") then return end
        task.wait(1)
    end
end

local function waitForHeart()
    local deadline = tick() + 90
    while tick() < deadline do
        if findInMap("FrozenHeart") then return true end
        task.wait(1)
    end
    return false
end

local function waitForSeatOrTimeout()
    local boat = workspace:FindFirstChild("Boats")
        and workspace.Boats:FindFirstChild("Beast Hunter")
    if not boat then
        task.wait(120)
        return
    end

    local seatUsed    = false
    local connections = {}
    for i, cannon in ipairs(boat:GetChildren()) do
        local seat = cannon:FindFirstChild("Seat")
        if seat then
            connections[i] = seat.ChildAdded:Connect(function(child)
                if child.Name == "SeatWeld" and not seatUsed then
                    seatUsed = true
                    for _, c in pairs(connections) do c:Disconnect() end
                end
            end)
        end
    end

    local elapsed = 0
    repeat
        task.wait(0.1)
        elapsed += 0.1
    until seatUsed or elapsed > 120

    if not seatUsed then
        for _, c in pairs(connections) do c:Disconnect() end
    end
end

task.spawn(function()
    while true do
        waitForGate()
        getgenv().leviInProgress = true

        if waitForHeart() then
            setFpsCap(80)
            waitForSeatOrTimeout()
            task.wait(1)
            setFpsCap(30)
        end

        getgenv().leviInProgress = false
        task.wait(5)
    end
end)

local DataRemote = game.ReplicatedStorage.DungeonShared:WaitForChild("DataRemote")

local playerName = LocalPlayer.Name
local FLAG_FILE = "MistFlag-Global.txt"

local DUNGEON_MIN_ENERGY = 10
local DUNGEON_START_ENERGY = 50

local lastFlag = nil
local dungeonStarted = false
local leviStarted = false

local function startDungeons()
    if dungeonStarted or not cfg.executeDungeons then return end
    if game.PlaceId ~= 73902483975735 then return end
    if kickIfRandomInDungeon() then return end
    if isInDungeon() then
        startDungeonRandomMonitor()
    end
    dungeonStarted = true
    task.spawn(function()
        local ok, err = pcall(cfg.executeDungeons)
        if not ok then warn("[EventCheck] executeDungeons error: " .. tostring(err)) end
    end)
end

local function startLevi()
    if leviStarted or not cfg.executeLevi then return end
    if game.PlaceId == 73902483975735 then return end
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
    startLevi()
end

local function switchFlagToLevi()
    setFlag("Leviathan")
    sendSwitchWebhook("→ Leviathan")
end

local function switchToDungeons(fromLevi)
    if lastFlag ~= "Dungeons" then
        setFlag("Dungeons")
        sendSwitchWebhook("→ Dungeons")
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
            switchFlagToLevi()
            LocalPlayer:Kick("dungeons done")
        end

    elseif flag == "Leviathan" then
        if game.PlaceId == 73902483975735 then
            print("[MistFlag] Flag is Leviathan, in dungeon hub — kicking to transition")
            setFlag("Leviathan")
            LocalPlayer:Kick("dungeons done")
            return
        end
        if energy >= DUNGEON_START_ENERGY and not getgenv().leviInProgress then
            print("[MistFlag] Energy refilled (" .. energy .. ") — switching to Dungeons")
            switchToDungeons(true)
        else
            setFlag("Leviathan")
            startLevi()
        end

    else
        print("[MistFlag] No flag found — energy: " .. energy)
        if energy >= DUNGEON_START_ENERGY and not getgenv().leviInProgress then
            switchToDungeons()
            if game.PlaceId ~= 73902483975735 then
                teleportToHub()
            end
        else
            switchToLevi()
        end
    end
end

if cfg.leviOnly then
    if kickIfRandomInDungeon() then return end
    startLevi()
else
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
            task.wait(180)
            if not isInDungeon() then
                local ok, err = pcall(update)
                if not ok then warn("[EventCheck] poll error: " .. tostring(err)) end
            end
        end
    end)
end
