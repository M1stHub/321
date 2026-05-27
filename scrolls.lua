repeat wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local oldGui = game:GetService("CoreGui"):FindFirstChild("CraftingTracker")

if oldGui then
	oldGui:Destroy()
end

local playerGui = lp:WaitForChild("PlayerGui")
oldGui = playerGui:FindFirstChild("CraftingTracker")

if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CraftingTracker"
gui.ResetOnSpawn = false

(lines, "\n")
	frame.Size = UDim2.new(0, 340, 0, math.max(50, 22 + (#lines * 17)))

	return matCounts
end

local function hasMaterials(requirements, matCounts)
	for _, req in ipairs(requirements) do
		local matName = req[1]
		local neededQty = req[2]
		local ownedQty = matCounts[matName] or 0

		if ownedQty < neededQty then
			return false, matName, neededQty, ownedQty
		end
	end

	return true
end

local function craftScroll(displayName, craftName, currentCount, targetCount, requirements)
	local matCounts = updateTracker(displayName, currentCount, targetCount, requirements)
	local enough, missingName, neededQty, ownedQty = hasMaterials(requirements, matCounts)

	if enough then
		local success, err = pcall(function()
			RF_Craft:InvokeServer("Craft", craftName, 1, {})
		end)

		if success then
			updateTracker(displayName, currentCount, targetCount, requirements, "Crafted 1 " .. displayName .. " Scroll")
		else
			updateTracker(displayName, currentCount, targetCount, requirements, "Craft failed: " .. tostring(err))
		end
	else
		updateTracker(displayName, currentCount, targetCount, requirements, "Need " .. missingName .. " " .. ownedQty .. "/" .. neededQty)
	end
end

log("Checking scrolls...")

while true do
	local commonScrolls, rareScrolls, legendaryScrolls, mythicalScrolls = getScrollCounts()

	if commonScrolls < 11 then
		craftScroll("Common", "CommonScroll", commonScrolls, 11, commonMaterials)
	elseif rareScrolls < 11 then
		craftScroll("Rare", "RareScroll", rareScrolls, 11, rareMaterials)
	elseif legendaryScrolls < 11 then
		craftScroll("Legendary", "LegendaryScroll", legendaryScrolls, 11, legendaryMaterials)
	elseif mythicalScrolls < 10 then
		craftScroll("Mythical", "MythicalScroll", mythicalScrolls, 10, mythicalMaterials)
	else
		break
	end

	task.wait(5)
end

log("Crafting completed for " .. lp.Name)
