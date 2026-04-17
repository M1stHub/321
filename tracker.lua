repeat task.wait() until game:IsLoaded()
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")

local requestFunc = request or http_request or (syn and syn.request)
if not requestFunc then return end

local webhooks = getgenv().webhooks
if not webhooks then return end

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

pcall(function()
    local p = Players.LocalPlayer
    if not p then return end
    p.CameraMaxZoomDistance = p.CameraMaxZoomDistance + 50
    p.CameraMinZoomDistance = p.CameraMaxZoomDistance
end)

local function ImGoated()
    pcall(function()
        local player = Players.LocalPlayer
        if not player then return end

        local webhookUrl = webhooks[player.UserId]
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

        local tracker = {
            ["Mythical Scroll"] = 0,
            ["Leviathan Heart"] = 0,
            ["Leviathan Scale"] = 0,
            ["Terror Eyes"] = 0,
            ["Fool's Gold"] = 0
        }

        local mythicalFruits = {}
        local legendaryFruits = {}
        
        for _, item in pairs(response) do
            pcall(function()
                if typeof(item) ~= "table" then return end
        
                if tracker[item.Name] ~= nil then
                    tracker[item.Name] = tonumber(item.Count) or 0
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

        local fields = {
            {name = "Fragments", value = formatFrags(frags), inline = true},
            {name = "Leviathan Heart", value = tostring(tracker["Leviathan Heart"]), inline = true},
            {name = "Leviathan Scale", value = tostring(tracker["Leviathan Scale"]), inline = true},
            {name = "Mythical Scroll", value = tostring(tracker["Mythical Scroll"]), inline = true},
            {name = "Terror Eyes", value = tostring(tracker["Terror Eyes"]), inline = true},
            {name = "Fool's Gold", value = tostring(tracker["Fool's Gold"]), inline = true},
            {name = "Mythical Fruits", value = "```\n" .. mythicalList .. "\n```", inline = false},
            {name = "Legendary Fruits", value = "```\n" .. legendaryList .. "\n```", inline = false},
            {name = "", value = "||" .. (player.Name or "Unknown") .. "||", inline = false}
        }

        pcall(function()
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
    end)
end

task.wait(2)
ImGoated()

while true do
    task.wait(1200)
    ImGoated()
end
