local Players      = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")

local EnchantRemote = RepStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/EnchantInvoke")
local CommF         = RepStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

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

local httpRequest = (syn and syn.request) or http_request or request

local function ToLookup(tbl)
    local lookup = {}
    for _, v in ipairs(tbl or {}) do lookup[v] = true end
    return lookup
end

local WantedBlessings = ToLookup(RollCfg.WantedBlessings)
local WantedUniques   = ToLookup(RollCfg.WantedUniques)

local function GetScrollCount()
    local count = 0
    pcall(function()
        local inv = CommF:InvokeServer("getInventory")
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
    for name, data in pairs(enchants) do
        local level = type(data) == "table" and (data.Level or data.MaxLevel)
        local tag   = (type(data) == "table" and data.Unique) and " [Unique]" or ""
        local line  = level and (name .. " (Lvl " .. tostring(level) .. ")" .. tag) or (name .. tag)
        table.insert(enchantLines, line)
    end
    local enchantText = #enchantLines > 0 and table.concat(enchantLines, "\n") or "None"
    local scrollLeft  = GetScrollCount()

    local payload = {
        content = isGood and "@everyone" or nil,
        embeds  = {
            {
                title  = isGood and "LETS FUCKING GOOO" or "Roll Result",
                color  = isGood and 0x57F287 or 0x5865F2,
                fields = {
                    { name = "Scroll",       value = scrolls[Selected],                            inline = true  },
                    { name = "Scrolls Left", value = tostring(scrollLeft),                         inline = true  },
                    { name = "Weapon",       value = WeaponType .. " · " .. (WeaponName or "Any"), inline = true  },
                    { name = "Enchants",     value = "```\n" .. enchantText .. "\n```",             inline = false },
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

    local parts = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            parts[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local distance = (root.Position - position).Magnitude
    local tween = TweenService:Create(
        root,
        TweenInfo.new(distance / (RollCfg.TweenSpeed or 150), Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(position) }
    )
    tween:Play()
    tween.Completed:Wait()

    for part, wasCollide in pairs(parts) do
        part.CanCollide = wasCollide
    end
end

local function FindWeapon()
    local function matchItem(item)
        if WeaponName then return item.Name == WeaponName end
        return item:GetAttribute("WeaponType") == WeaponType
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
    pcall(function() CommF:InvokeServer("LoadItem", WeaponName) end)
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
        if typeof(modifierData) == "table" and modifierData.Name then
            found[modifierData.Name] = modifierData
        end
    end
    return found
end

local function HasWanted(tbl, enchants)
    for enchantName in pairs(tbl) do
        if enchants[enchantName] ~= nil then return true end
    end
    return false
end

local function ShouldKeep(enchants)
    if not HasWanted(WantedBlessings, enchants) then return false end
    if not HasWanted(WantedUniques, enchants) then return false end
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

local token = {}
getgenv()._rollToken = token

local originalWeapon = nil
pcall(function()
    local inv = CommF:InvokeServer("getInventory")
    if type(inv) ~= "table" then return end
    for _, item in ipairs(inv) do
        pcall(function()
            if item.Equipped and item.Name ~= WeaponName
            and (item.Type == "Sword" or item.Type == "Gun") then
                originalWeapon = item.Name
            end
        end)
    end
end)

while task.wait(RollCfg.RollDelay or 5) do
    if getgenv()._rollToken ~= token then break end
    local success, result = pcall(TryEnchant)
    if success and result then break end
end

if originalWeapon and originalWeapon ~= WeaponName then
    pcall(function() CommF:InvokeServer("LoadItem", originalWeapon) end)
end
