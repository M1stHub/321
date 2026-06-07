local Players      = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")

local EnchantRemote = RepStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/EnchantInvoke")
local CommF         = RepStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local Comm          = RepStorage:WaitForChild("Comm", 5)

local scrolls = {
    Com  = "Common Scroll",
    Rare = "Rare Scroll",
    Leg  = "Legendary Scroll",
    Myth = "Mythical Scroll"
}

local RollCfg = getgenv().RollCfg or {
    Selected        = "Myth",
    WeaponType      = "Sword",
    WeaponName      = nil,
    WantedBlessings = {},
    WantedUniques   = {},
    RollDelay       = 5,
    TweenSpeed      = 275,
    Webhook         = nil,
}

local Selected   = RollCfg.Selected
local WeaponType = RollCfg.WeaponType or "Sword"
local WeaponName = RollCfg.WeaponName

local RollPosition = Vector3.new(
    -15901.00390625,
    484.1939697265625,
    945.1946411132812
)

local function ToLookup(tbl)
    local lookup = {}
    for _, v in ipairs(tbl or {}) do
        lookup[v] = true
    end
    return lookup
end

local WantedBlessings = ToLookup(RollCfg.WantedBlessings)
local WantedUniques   = ToLookup(RollCfg.WantedUniques)

local httpRequest = (syn and syn.request) or http_request or request

local function GetScrollCount()
    local count = 0
    pcall(function()
        local inv = Comm:InvokeServer("getInventory")
        if type(inv) ~= "table" then return end
        for _, item in ipairs(inv) do
            pcall(function()
                if item.Name == scrolls[Selected] then
                    count = tonumber(item.Count) or 0
                end
            end)
        end
    end)
    return count
end

local function SendWebhook(enchants, isGood)
    if not RollCfg.Webhook or not httpRequest then return end

    local enchantLines = {}
    for k, v in pairs(enchants) do
        table.insert(enchantLines, k .. ": " .. tostring(v))
    end
    local enchantText = #enchantLines > 0 and table.concat(enchantLines, "\n") or "None"

    local scrollLeft = GetScrollCount()

    local payload = {
        content = isGood and "@everyone" or nil,
        embeds  = {
            {
                title  = isGood and "LETS FUCKING GOOO" or "Roll Result",
                color  = isGood and 0x57F287 or 0x5865F2,
                fields = {
                    { name = "Scroll",        value = scrolls[Selected],                                 inline = true  },
                    { name = "Scrolls Left",  value = tostring(scrollLeft),                              inline = true  },
                    { name = "Weapon",        value = WeaponType .. " · " .. (WeaponName or "Any"),      inline = true  },
                    { name = "Enchants",      value = "```\n" .. enchantText .. "\n```",                 inline = false },
                },
            }
        }
    }

    pcall(function()
        httpRequest({
            Url     = RollCfg.Webhook,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload),
        })
    end)
end

local function TweenToPosition(position)
    local character = Players.LocalPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local distance = (root.Position - position).Magnitude
    local speed    = RollCfg.TweenSpeed or 150

    local tween = TweenService:Create(
        root,
        TweenInfo.new(distance / speed, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(position) }
    )

    tween:Play()
    tween.Completed:Wait()
end

local function FindWeapon()
    local function matchItem(item)
        if item:GetAttribute("WeaponType") ~= WeaponType then return false end
        if WeaponName and item.Name ~= WeaponName then return false end
        return true
    end

    for _, item in ipairs(Players.LocalPlayer.Backpack:GetChildren()) do
        if matchItem(item) then return item end
    end
    for _, item in ipairs(Players.LocalPlayer.Character:GetChildren()) do
        if matchItem(item) then return item end
    end
    return nil
end

local function EquipWeapon()
    if not WeaponName then return end
    if FindWeapon() then return end

    pcall(function()
        CommF:InvokeServer("LoadItem", WeaponName)
    end)

    task.wait(1)
end

local function FindEnchants(result)
    local found     = {}
    local modifiers = result.Modifiers

    if not modifiers then
        for _, v in pairs(result) do
            if typeof(v) == "table" and v.Modifiers then
                modifiers = v.Modifiers
                break
            end
        end
    end

    if typeof(modifiers) ~= "table" then return found end

    for _, modifierData in pairs(modifiers) do
        if typeof(modifierData) == "table" then
            for enchantName, enchantValue in pairs(modifierData) do
                found[enchantName] = enchantValue
            end
        end
    end

    return found
end

local function HasWanted(tbl, enchants)
    for enchantName in pairs(tbl) do
        if enchants[enchantName] then
            print("Found:", enchantName)
            return true
        end
    end
    return false
end

local function ShouldKeep(enchants)
    if not HasWanted(WantedBlessings, enchants) then return false end
    if not HasWanted(WantedUniques, enchants) then return false end
    print("Good roll found")
    return true
end

local function TryEnchant()
    TweenToPosition(RollPosition)
    EquipWeapon()

    local weapon = FindWeapon()
    if not weapon then return end

    local result = EnchantRemote:InvokeServer("Enchant", weapon, scrolls[Selected])
    if typeof(result) ~= "table" then return end

    local enchants = FindEnchants(result)
    local isGood   = ShouldKeep(enchants)

    SendWebhook(enchants, isGood)

    if isGood then return true end
    return false
end

while task.wait(RollCfg.RollDelay or 5) do
    local success, result = pcall(TryEnchant)
    if success and result then break end
end
