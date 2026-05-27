repeat wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

local oldGui = CoreGui:FindFirstChild("CraftingTracker")
if oldGui then
	oldGui:Destroy()
end

oldGui = playerGui:FindFirstChild("CraftingTracker")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CraftingTracker"
gui.ResetOnSpawn = false

pcall(function()
	gui.Parent = CoreGui
end)

if not gui.Parent then
	gui.Parent = playerGui
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 110)
frame.Position = UDim2.new(1, -350, 0.5, -55)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -16, 1, -12)
label.Position = UDim2.new(0, 8, 0, 6)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(220, 220, 220)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.TextWrapped = false
label.Font = Enum.Font.Code
label.TextSize = 13
label.Text = "Starting crafting script..."
label.Parent = frame

local dragging = false
local dragStart = nil
local startPos = nil

frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)

frame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart

		frame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)

local function log(msg)
	print(msg)
	label.Text = msg
end

local commonMaterials = {
	{"Fool's Gold", 3},
	{"Shark Tooth", 2}
}

local rareMaterials = {
	{"Electric Wing", 2},
	{"Fool's Gold", 5},
	{"Shark Tooth", 4}
}

local legendaryMaterials = {
	{"Leviathan Scale", 5},
	{"Electric Wing", 3},
	{"Mutant Tooth", 1},
	{"Fool's Gold", 7}
}

local mythicalMaterials = {
	{"Leviathan Heart", 1},
	{"Leviathan Scale", 15},
	{"Terror Eyes", 1},
	{"Fool's Gold", 20}
}

local RF_Craft = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/Craft")
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local function getInventory()
	return CommF_:InvokeServer("getInventory")
end

local function getMaterialCounts(inventory)
	local matCounts = {}

	for _, item in pairs(inventory) do
		if item.Type == "Material" then
			matCounts[item.Name] = item.Count
		end
	end

	return matCounts
end

local function getScrollCounts()
	local inventory = getInventory()

	local commonCount = 0
	local rareCount = 0
	local legendaryCount = 0
	local mythicalCount = 0

	for _, item in pairs(inventory) do
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

local function updateTracker(displayName, currentCount, targetCount, requirements, footer)
	local inventory = getInventory()
	local matCounts = getMaterialCounts(inventory)

	local lines = {}
	table.insert(lines, "Crafting Scroll " .. displayName .. " " .. currentCount .. "/" .. targetCount)

	for _, req in ipairs(requirements) do
		local matName = req[1]
		local neededQty = req[2]
		local ownedQty = matCounts[matName] or 0

		table.insert(lines, matName .. " " .. ownedQty .. "/" .. neededQty)
	end

	if footer then
		table.insert(lines, footer)
	end

	label.Text = table.concat(lines, "\n")
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
