print("Starting crafting script...")

local commonMaterials = {["Fool's Gold"] = 3, ["Shark Tooth"] = 2}
local rareMaterials = {["Electric Wing"] = 2, ["Fool's Gold"] = 5, ["Shark Tooth"] = 4}
local legendaryMaterials = {["Leviathan Scale"] = 5, ["Electric Wing"] = 3, ["Mutant Tooth"] = 1, ["Fool's Gold"] = 7}
local mythicalMaterials = {["Leviathan Heart"] = 1, ["Leviathan Scale"] = 15, ["Terror Eyes"] = 1, ["Fool's Gold"] = 20}

local RF_Craft = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/Craft")

function getInventory()
    return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("getInventory")
end

function getScrollCounts()
    local inventory = getInventory()
    local commonCount = 0
    local rareCount = 0
    local legendaryCount = 0
    local mythicalCount = 0
    for i, item in pairs(inventory) do
        if item.Type == "Scroll" then
            if item.Name == "Common Scroll" then
                commonCount = item.Count
            elseif item.Name == "Rare Scroll" then
                rareCount = item.Count
            elseif item.Name == "Legendary Scroll" then
                legendaryCount = item.Count
            elseif item.Name == "Mythical Scroll" then
                mythicalCount = item.Count
            end
        end
    end
    return commonCount, rareCount, legendaryCount, mythicalCount
end

function hasMaterials(requirements)
    local inventory = getInventory()
    local matCounts = {}
    for i, item in pairs(inventory) do
        if item.Type == "Material" then
            matCounts[item.Name] = item.Count
        end
    end
    for matName, qty in pairs(requirements) do
        if not matCounts[matName] or matCounts[matName] < qty then
            return false, matCounts
        end
    end
    return true, matCounts
end

while true do
    local commonScrolls, rareScrolls, legendaryScrolls, mythicalScrolls = getScrollCounts()
    if commonScrolls < 10 then
        local enough, matCounts = hasMaterials(commonMaterials)
        print("Common Scrolls:", commonScrolls, "/10")
        if enough then
            RF_Craft:InvokeServer("Craft", "CommonScroll", 1, {})
            print("Crafted 1 Common Scroll")
        else
            print("Not enough materials for Common Scroll")
        end
        task.wait(5)
    elseif rareScrolls < 10 then
        local enough, matCounts = hasMaterials(rareMaterials)
        print("Rare Scrolls:", rareScrolls, "/10")
        if enough then
            RF_Craft:InvokeServer("Craft", "RareScroll", 1, {})
            print("Crafted 1 Rare Scroll")
        else
            print("Not enough materials for Rare Scroll")
        end
        task.wait(5)
    elseif legendaryScrolls < 10 then
        local enough, matCounts = hasMaterials(legendaryMaterials)
        print("Legendary Scrolls:", legendaryScrolls, "/10")
        if enough then
            RF_Craft:InvokeServer("Craft", "LegendaryScroll", 1, {})
            print("Crafted 1 Legendary Scroll")
        else
            print("Not enough materials for Legendary Scroll")
        end
        task.wait(5)
    elseif mythicalScrolls < 10 then
        local enough, matCounts = hasMaterials(mythicalMaterials)
        print("Mythical Scrolls:", mythicalScrolls, "/10")
        if enough then
            RF_Craft:InvokeServer("Craft", "MythicalScroll", 1, {})
            print("Crafted 1 Mythical Scroll")
        else
            print("Not enough materials for Mythical Scroll")
        end
        task.wait(5)
    else
        break
    end
end

print("Crafting completed for", game.Players.LocalPlayer.Name)
