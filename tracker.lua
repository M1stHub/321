repeat task.wait() until game:IsLoaded()
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")

local requestFunc = request or http_request or (syn and syn.request)
if not requestFunc then return end

local webhooks = getgenv().trackerWebhooks
if not webhooks then return end

local lastSent = 0
local COOLDOWN = 30

local function formatFrags(frags)
    frags = frags or 0

    local function formatUnit(value, divisor, suffix)
        local num = value / divisor
        local formatted = string.format("%.1f", num)
        formatted = formatted:gsub("%.0$", "")
        return formatted .. suffix
    end

    if frags < 1000 then
        return tostring(frags)
    elseif frags < 1e6 then
        return formatUnit(frags, 1e3, "k")
    elseif frags < 1e9 then
        return formatUnit(frags, 1e6, "m")
    else
        return formatUnit(frags, 1e9, "b")
    end
end

local function formatNumber(value)
    value = math.floor(tonumber(value) or 0)

    local left, num, right = tostring(value):match("^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

pcall(function()
    local player = Players.LocalPlayer
    if not player or player.UserId == getgenv().notiAcc then return end

    player.CameraMinZoomDistance = 0
    player.CameraMaxZoomDistance = 128

    local currentCamera = workspace.CurrentCamera
    if not currentCamera then return end

    task.spawn(function()
        for i = 1, 10 do
            currentCamera.CameraType = Enum.CameraType.Custom
            player.CameraMinZoomDistance = 0
            task.wait(0.01)
        end
        player.CameraMaxZoomDistance = 0
        task.wait(0.1)
        player.CameraMaxZoomDistance = 128
    end)
end)

local function ImGoated()
    local now = os.clock()
    if now - lastSent < COOLDOWN then return end

    pcall(function()
        local player = Players.LocalPlayer
        if not player then return end

        local webhookUrl = webhooks[player.Name]
        if not webhookUrl then return end

        local remotesObj
        local remotesSuccess = pcall(function()
            remotesObj = RepStorage:WaitForChild("Remotes", 10)
        end)
        if not remotesSuccess or not remotesObj then return end

        local comm = remotesObj:FindFirstChild("CommF_")
        if not comm then return end

        local success, response = pcall(function()
            return comm:InvokeServer("getInventory")
        end)

        if not success or typeof(response) ~= "table" then return end

        local frags = 0
        pcall(function()
            local data = player:FindFirstChild("Data")
            if data then
                local fragments = data:FindFirstChild("Fragments")
                if fragments and fragments:IsA("IntValue") then
                    frags = fragments.Value or 0
                end
            end
        end)

        local energyText = "Unknown"
        pcall(function()
            local replicatedPlayerData = require(RepStorage:WaitForChild("DungeonClient"):WaitForChild("ReplicatedPlayerData"))
            local data = replicatedPlayerData.get()
            if typeof(data) ~= "table" then return end

            local currentEnergy = tonumber(data.CurrentEnergy)
            if not currentEnergy then return end

            energyText = tostring(math.floor(currentEnergy))
        end)

        local tracker = {
            ["Mythical Scroll"] = 0,
            ["Leviathan Heart"] = 0,
            ["Leviathan Scale"] = 0,
            ["Terror Eyes"] = 0,
            ["Fool's Gold"] = 0
        }

        local mythicalFruits = {}
        local legendaryFruits = {}
        local ringCounts = {}

        local function cleanItemName(name)
            name = tostring(name or "")
            name = name:gsub("<.->", "")
            name = name:gsub("%s+", " ")
            return name:match("^%s*(.-)%s*$")
        end

        local function isTrackedRing(name)
            name = cleanItemName(name)
            local nameLower = name:lower()

            if nameLower == "tomoe ring" or nameLower == "spring" then
                return false
            end

            return nameLower:match("^ring of ") ~= nil
        end

        for _, item in pairs(response) do
            pcall(function()
                if typeof(item) ~= "table" then return end

                if tracker[item.Name] ~= nil then
                    tracker[item.Name] = tonumber(item.Count) or 0
                end

                if isTrackedRing(item.Name) or isTrackedRing(item.DisplayName) then
                    local displayName = cleanItemName(item.DisplayName or item.Name or "Unknown")
                    local count = tonumber(item.Count) or 1
                    ringCounts[displayName] = (ringCounts[displayName] or 0) + count
                end

                if item.Type == "Blox Fruit" then
                    local rarity = tonumber(item.Rarity) or 0
                    local name = item.DisplayName or item.Name or "Unknown"
                    local count = tonumber(item.Count) or 1
                    local entry = name .. " x" .. count

                    if rarity == 4 then
                        table.insert(mythicalFruits, entry)
                    elseif rarity == 3 then
                        table.insert(legendaryFruits, entry)
                    end
                end
            end)
        end

        local mythicalList = #mythicalFruits > 0 and table.concat(mythicalFruits, "\n") or "None"
        local legendaryList = #legendaryFruits > 0 and table.concat(legendaryFruits, "\n") or "None"
        local rings = {}
        for name, count in pairs(ringCounts) do
            table.insert(rings, name .. " x" .. count)
        end
        table.sort(rings)

        local ringList = #rings > 0 and table.concat(rings, "\n") or "None"

        local fields = {
            {name = "Fragments", value = formatFrags(frags), inline = true},
            {name = "Energy", value = energyText, inline = true},
            {name = "Leviathan Heart", value = tostring(tracker["Leviathan Heart"]), inline = true},
            {name = "Leviathan Scale", value = tostring(tracker["Leviathan Scale"]), inline = true},
            {name = "Mythical Scroll", value = tostring(tracker["Mythical Scroll"]), inline = true},
            {name = "Terror Eyes", value = tostring(tracker["Terror Eyes"]), inline = true},
            {name = "Fool's Gold", value = tostring(tracker["Fool's Gold"]), inline = true},
            {name = "Mythical Fruits", value = "```\n" .. mythicalList .. "\n```", inline = true},
            {name = "Legendary Fruits", value = "```\n" .. legendaryList .. "\n```", inline = true},
            {name = "Rings", value = "```\n" .. ringList .. "\n```", inline = false},
            {name = "", value = "||" .. (player.Name or "Unknown") .. "||", inline = false}
        }

        local ok = pcall(function()
            requestFunc({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    username = "levi is gay",
                    embeds = {{
                        title = "waves",
                        color = 0x1F51FF,
                        fields = fields,
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }}
                })
            })
        end)

        if ok then
            lastSent = os.clock()
        end
    end)
end

task.wait(2)
ImGoated()

while true do
    task.wait(1200)
    ImGoated()
end
