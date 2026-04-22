repeat wait() until game:IsLoaded()
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if Remotes and Remotes:FindFirstChild("DMGDEBUG") then
	Remotes.DMGDEBUG:Destroy()
end

local Priorities = getgenv().CardPriorities or {
    ["HYPER!"] = 1,
    ["Melee"] = 2,
    ["Lifesteal"] = 3,
    ["Fortress"] = 4,
    ["Overflow"] = 5,
    ["Defense"] = 6,
    ["Armor"] = 7,
    ["Unbreakable"] = 8
}

local function stripHtmlTags(text)
    if type(text) ~= "string" then
        return tostring(text)
    end
    local cleaned = text:gsub("<[^>]+>", "")
    cleaned = cleaned:gsub("&lt;", "<")
    cleaned = cleaned:gsub("&gt;", ">")
    cleaned = cleaned:gsub("&amp;", "&")
    cleaned = cleaned:gsub("&quot;", '"')
    cleaned = cleaned:gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
    return cleaned
end

local function findClickable(instance)
    if not instance then
        return nil
    end
    if instance:IsA("GuiButton") then
        return instance
    end
    return instance:FindFirstAncestorWhichIsA("GuiButton")
end

local function clickAt(x, y)
    pcall(VirtualInputManager.SendMouseMoveEvent, VirtualInputManager, x, y, game)
    task.wait(0.02)
    pcall(VirtualInputManager.SendMouseButtonEvent, VirtualInputManager, x, y, 0, true, game, 0)
    task.wait(0.02)
    pcall(VirtualInputManager.SendMouseButtonEvent, VirtualInputManager, x, y, 0, false, game, 0)
end

local function scanAndClick()
    local foundCards = {}
    
    for _, screenGui in ipairs(PlayerGui:GetChildren()) do
        if screenGui:IsA("ScreenGui") and screenGui.Name == "ScreenGui" then
            for _, frame in ipairs(screenGui:GetChildren()) do
                if frame:IsA("Frame") and frame.Name == "1" then
                    for _, child in ipairs(frame:GetDescendants()) do
                        if child.Name == "DisplayName" and (child:IsA("TextLabel") or child:IsA("TextButton")) then
                            local cleanName = stripHtmlTags(child.Text or "")
                            table.insert(foundCards, {
                                name = cleanName,
                                element = child,
                                priority = Priorities[cleanName] or 9999
                            })
                        end
                    end
                end
            end
        end
    end
    
    table.sort(foundCards, function(a, b)
        return a.priority < b.priority
    end)
    
    if #foundCards > 0 then
        local bestCard = foundCards[1]
        local clickable = findClickable(bestCard.element) or bestCard.element
        local pos = clickable.AbsolutePosition + clickable.AbsoluteSize / 2
        local x = math.floor(pos.X)
        local y = math.floor(pos.Y)
        
        local prioText = bestCard.priority == 9999 and "Random" or "Priority " .. bestCard.priority
        local logText = string.format("[%s] %s", prioText, bestCard.name)
        warn("Picking: " .. logText)
        clickAt(x, y)
        return true
    end
    return false
end

game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)

task.spawn(function()
    warn("Card Picker started - scanning every 0.5s")
    while task.wait(0.5) do
        scanAndClick()
    end
end)
