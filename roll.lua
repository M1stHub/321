local Players      = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")

local TELEPORT_DISTANCE = 250

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
    RequiredLevels  = {},
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
local RequiredLevels  = RollCfg.RequiredLevels or {}

local function GetEnchantLevel(data)
    if type(data) == "table" then
        return tonumber(data.Level or data.MaxLevel or data.Value)
    end
    return tonumber(data)
end

local function IsUniqueEnchant(name, data)
    if WantedUniques[name] then return true end
    if type(data) ~= "table" then return false end

    return data.Unique ~= nil and data.Unique ~= false
end

local function IsBlessingEnchant(name, data)
    if WantedBlessings[name] then return true end
    if type(data) ~= "table" then return false end

    if (data.Blessing ~= nil and data.Blessing ~= false) or (data.IsBlessing ~= nil and data.IsBlessing ~= false) then return true end

    local enchantType = tostring(data.Type or data.Category or data.Rarity or ""):lower()
    return enchantType == "blessing" or enchantType:find("blessing", 1, true) ~= nil
end

local function GetRollStatus(enchants)
    local hasBlessing, hasUnique = false, false
    local hasWantedBlessing, hasWantedUnique = false, false

    for name, data in pairs(enchants) do
        if IsBlessingEnchant(name, data) then
            hasBlessing = true
            if WantedBlessings[name] then
                hasWantedBlessing = true
            end
        end

        if IsUniqueEnchant(name, data) then
            hasUnique = true
            if WantedUniques[name] then
                hasWantedUnique = true
            end
        end
    end

    if hasWantedBlessing and hasWantedUnique then
        return "Correct Blessing and Unique", true
    end

    if hasBlessing and hasUnique then
        if hasWantedBlessing then
            return "Correct Blessing + Wrong Unique", false
        end
        if hasWantedUnique then
            return "Wrong Blessing + Correct Unique", false
        end
        return "Blessing + Unique But Wrong One", false
    end

    if hasBlessing then
        return hasWantedBlessing and "Solo Blessing (Correct)" or "Solo Blessing", false
    end

    if hasUnique then
        return hasWantedUnique and "Solo Unique (Correct)" or "Solo Unique", false
    end

    return "No Blessing/Unique", false
end

local function HasWanted(tbl, enchants)
    for enchantName in pairs(tbl) do
        if enchants[enchantName] ~= nil then
            return true
        end
    end

    return false
end

local function HasRequiredLevels(enchants)
    for enchantName, requiredLevel in pairs(RequiredLevels) do
        local currentLevel = GetEnchantLevel(enchants[enchantName])

        if not currentLevel or currentLevel < requiredLevel then
            return false
        end
    end

    return true
end

local function ShouldKeep(enchants)
    return HasWanted(WantedBlessings, enchants)
        and HasWanted(WantedUniques, enchants)
        and HasRequiredLevels(enchants)
end

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

local function BuildEnchantText(enchants)
    local blessingLines, uniqueLines, otherLines = {}, {}, {}
    for name, data in pairs(enchants) do
        local level = GetEnchantLevel(data)
        local isBlessing = IsBlessingEnchant(name, data)
        local isUnique   = IsUniqueEnchant(name, data)
        local tag  = isUnique and " [Unique]" or (isBlessing and " [Blessing]" or "")
        local line = level and (name .. " (Lvl " .. tostring(level) .. ")" .. tag) or (name .. tag)
        if isBlessing then
            table.insert(blessingLines, line)
        elseif isUnique then
            table.insert(uniqueLines, line)
        else
            table.insert(otherLines, line)
        end
    end
    local enchantLines = {}
    for _, l in ipairs(blessingLines) do table.insert(enchantLines, l) end
    for _, l in ipairs(uniqueLines)   do table.insert(enchantLines, l) end
    for _, l in ipairs(otherLines)    do table.insert(enchantLines, l) end
    return #enchantLines > 0 and table.concat(enchantLines, "\n") or "None"
end

local function SendWebhook(enchantText, rollTitle, isGood)
    if not RollCfg.Webhook or not httpRequest then return end

    local scrollLeft = GetScrollCount()

    local payload = {
        content = isGood and "@everyone" or nil,
        embeds  = {
            {
                title  = "Roll Result (" .. rollTitle .. ")",
                color  = isGood and 0x57F287 or 0x5865F2,
                fields = {
                    { name = "Scroll",       value = scrolls[Selected],                            inline = true  },
                    { name = "Scrolls Left", value = tostring(scrollLeft),                         inline = true  },
                    { name = "Weapon",       value = WeaponType .. " - " .. (WeaponName or "Any"), inline = true  },
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

local function TweenToPosition(targetCFrame)
    local character = Players.LocalPlayer.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local startCFrame = hrp.CFrame
    local distance = (targetCFrame.Position - startCFrame.Position).Magnitude

    if distance <= TELEPORT_DISTANCE then
        hrp.CFrame = targetCFrame
        return
    end

    local parts = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            parts[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local duration = distance / (RollCfg.TweenSpeed or 150)

    local cframeValue = Instance.new("CFrameValue")
    cframeValue.Value = startCFrame

    local tween = TweenService:Create(
        cframeValue,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { Value = targetCFrame }
    )

    local connection = RunService.Heartbeat:Connect(function()
        if hrp.Parent then
            hrp.CFrame = cframeValue.Value
        end
    end)

    tween:Play()
    tween.Completed:Wait()

    connection:Disconnect()
    cframeValue:Destroy()

    if hrp.Parent then
        hrp.CFrame = targetCFrame
    end

    for part, wasCollide in pairs(parts) do
        if part.Parent then
            part.CanCollide = wasCollide
        end
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
        if typeof(modifierData) == "table" then
            if modifierData.Name then
                found[modifierData.Name] = modifierData
            else
                for enchantName, enchantValue in pairs(modifierData) do
                    found[enchantName] = enchantValue
                end
            end
        end
    end
    return found
end

local function TryEnchant()
    TweenToPosition(CFrame.new(RollPosition))
    EquipWeapon()

    local weapon = FindWeapon()
    if not weapon then return end

    local result = EnchantRemote:InvokeServer("Enchant", weapon, scrolls[Selected])
    if typeof(result) ~= "table" then return end

    local enchants = FindEnchants(result)
    local rollTitle = GetRollStatus(enchants)
    local isGood = ShouldKeep(enchants)
    if rollTitle == "Correct Blessing and Unique" and not isGood then
        rollTitle = "Correct Blessing and Unique (Missing Levels)"
    end

    local enchantText = BuildEnchantText(enchants)
    SendWebhook(enchantText, rollTitle, isGood)

    return isGood, rollTitle, enchantText
end

local DoneFileName = "RollDone_" .. tostring(Players.LocalPlayer.Name) .. "_" .. tostring(Selected) .. "_" .. tostring(WeaponName or WeaponType) .. ".txt"

local function ReadDoneFile()
    if not readfile then return nil end
    local ok, content = pcall(readfile, DoneFileName)
    if ok and content and content ~= "" then
        return content
    end
    return nil
end

local existingDone = ReadDoneFile()
if existingDone then
    print("[roll] Already found a good enchant for this weapon/scroll (" .. DoneFileName .. "):\n" .. existingDone)
    return
end

local token = {}
getgenv()._rollToken = token

local originalWeapon = nil
pcall(function()
    local inv = CommF:InvokeServer("getInventory")
    if type(inv) ~= "table" then return end
    for _, item in ipairs(inv) do
        if type(item) == "table" and item.Equipped == true
        and item.Type == WeaponType
        and item.Name ~= WeaponName then
            originalWeapon = item.Name
            break
        end
    end
end)

while task.wait(RollCfg.RollDelay or 5) do
    if getgenv()._rollToken ~= token then break end
    if GetScrollCount() == 0 then break end
    local success, isGood, rollTitle, enchantText = pcall(TryEnchant)
    if success and isGood then
        if writefile then
            local doneText = os.date("%Y-%m-%d %H:%M:%S") .. " | " .. WeaponType .. " - " .. (WeaponName or "Any")
                .. " | " .. rollTitle .. "\n" .. enchantText
            pcall(function() writefile(DoneFileName, doneText) end)
        end
        break
    end
end

if originalWeapon then
    pcall(function() CommF:InvokeServer("LoadItem", originalWeapon) end)
end
