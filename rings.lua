local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
))()

local Window = Fluent:CreateWindow({
    Title = "Ring Inventory",
    SubTitle = "by Mist",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CommF = Remotes:WaitForChild("CommF_")
local Interact = Remotes:WaitForChild("AccessoryInteract")

local function getInventory()
    return CommF:InvokeServer("getInventory")
end

local function getBaseRingName(name)
    if not name then return "" end
    local base = name:match("^Ring of the (.+)") or name:match("^Ring of (.+)")
    if not base then return "" end
    return base:gsub("%s+[IVX]+$", ""):match("^%s*(.-)%s*$")
end

local allowedTypes = {
    ["Might"] = true,
    ["Spirit"] = true,
    ["Steelheart"] = true,
    ["Arcanist"] = true,
    ["Outlaw"] = true,
    ["Twin Blades"] = true
}

local function getScrappableRings(inv)
    local t = {}
    for _, v in pairs(inv) do
        if type(v) == "table"
            and v.Name
            and v.NetworkedUID
            and (v.Type == "Wear" or v.Type == "Accessory")
            and not v.Equipped
            and not v.Locked
            and not v.Favorited
            and (v.Rarity or 0) ~= 4
        then
            local base = getBaseRingName(v.Name)
            if allowedTypes[base] then
                v.BaseType = base
                t[#t + 1] = v
            end
        end
    end
    return t
end

local function getRingsByTypeAndTier(inv, ringType, tier)
    local results = {}
    for _, v in pairs(inv) do
        if type(v) == "table"
            and v.Name and v.NetworkedUID
            and (v.Type == "Wear" or v.Type == "Accessory")
            and not v.Equipped and not v.Locked and not v.Favorited
            and v.Rarity == tier
        then
            local base = getBaseRingName(v.Name)
            if base == ringType then
                results[#results + 1] = v
            end
        end
    end
    return results
end

Fluent:Notify({
    Title = "Ring Inventory",
    Content = "Loaded",
    Duration = 4
})

Window:SelectTab(1)

local ringTypes = { "Might", "Spirit", "Steelheart", "Arcanist", "Outlaw", "Twin Blades" }
local selectedRingType = "Outlaw"

Tabs.Main:AddDropdown("RingType", {
    Title = "Ring Type to Keep / Fuse",
    Values = ringTypes,
    Default = selectedRingType,
    Multi = false
}):OnChanged(function(v)
    selectedRingType = v
end)

Tabs.Main:AddButton({
    Title = "Scrap Rings",
    Description = "Scrap all rings except selected type (T4 protected)",
    Callback = function()
        local ok, err = pcall(function()
            CommF:InvokeServer("getInventory")
            task.wait(0.35)
            local inv = CommF:InvokeServer("getInventory")

            local rings = getScrappableRings(inv)
            local count = 0

            for _, v in ipairs(rings) do
                if v.BaseType ~= selectedRingType then
                    Interact:InvokeServer("b", { v.NetworkedUID })
                    count += 1
                    task.wait(0.15)
                end
            end

            Fluent:Notify({
                Title = "Scrap",
                Content = "Scrapped " .. count .. " rings",
                Duration = 4
            })
        end)

        if not ok then
            Fluent:Notify({
                Title = "Scrap Error",
                Content = tostring(err),
                Duration = 6
            })
        end
    end
})

Tabs.Main:AddButton({
    Title = "Roll Rings",
    Description = "Roll as many times as Simulation Data allows",
    Callback = function()
        local ok, err = pcall(function()
            local inv = getInventory()
            local sim = 0

            for _, v in pairs(inv) do
                if v.Name and v.Name:find("Simulation Data") and v.Count then
                    sim = v.Count
                    break
                end
            end

            local rolls = math.floor(sim / 400)
            if rolls < 1 then
                Fluent:Notify({
                    Title = "Roll",
                    Content = "Not enough Simulation Data",
                    Duration = 4
                })
                return
            end

            for i = 1, rolls do
                Interact:InvokeServer("d")
                task.wait(0.1)
            end

            Fluent:Notify({
                Title = "Roll",
                Content = "Rolled " .. rolls .. " times",
                Duration = 4
            })
        end)

        if not ok then
            Fluent:Notify({
                Title = "Roll Error",
                Content = tostring(err),
                Duration = 6
            })
        end
    end
})

Tabs.Main:AddButton({
    Title = "Auto Fuse",
    Description = "Fuse selected ring type from tier 1 → 4",
    Callback = function()
        local ok, err = pcall(function()
            local totalFused = 0

            for tier = 1, 3 do
                while true do
                    task.wait(0.35)
                    local inv = CommF:InvokeServer("getInventory")
                    task.wait(0.35)
                    local rings = getRingsByTypeAndTier(inv, selectedRingType, tier)

                    if #rings < 3 then break end

                    Interact:InvokeServer("a",
                        rings[1].NetworkedUID,
                        rings[2].NetworkedUID,
                        rings[3].NetworkedUID
                    )
                    totalFused += 1
                    task.wait(0.5)
                end
            end

            Fluent:Notify({
                Title = "Auto Fuse",
                Content = "Done — " .. totalFused .. " fuses on " .. selectedRingType,
                Duration = 5
            })
        end)

        if not ok then
            Fluent:Notify({
                Title = "Fuse Error",
                Content = tostring(err),
                Duration = 6
            })
        end
    end
})
