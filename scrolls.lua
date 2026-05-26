repeat wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "CraftingTracker"
gui.ResetOnSpawn = false

pcall(function()
	gui.Parent = game:GetService("CoreGui")
end)

if not gui.Parent then
	gui.Parent = lp:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 50)
frame.Position = UDim2.new(1, -340, 0.5, -25)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -16, 1, 0)
label.Position = UDim2.new(0, 8, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(220, 220, 220)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextWrapped = true
label.Font = Enum.Font.Code
label.TextSize = 13
label.Text = "Starting crafting script..."
label.Parent = frame

local dragging, dragStart, startPos

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

game:GetService("UserInputService").InputChanged:Connect(function(input)
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

local commonMaterials = {["Fool's Gold"] = 3, ["Shark Tooth"] = 2}
local rareMaterials = {["Electric Wing"] = 2, ["Fool's Gold"] = 5, ["Shark Tooth"] = 4}
local legendaryMaterials = {["Leviathan Scale"] = 5, ["Electric Wing"] = 3, ["Mutant Tooth"] = 1, ["Fool's Gold"] = 7}
local mythicalMaterials = {["Leviathan Heart"] = 1, ["Leviathan Scale"] = 15, ["Terror Eyes"] = 1, ["Fool's Gold"] = 20}

local RF_Craft = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/Craft")
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local function getInventory()
	return CommF_:InvokeServer("getInventory")
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

local function hasMaterials(requirements)
	local inventory = getInventory()
	local matCounts = {}

	for _, item in pairs(inventory) do
		if item.Type == "Material" then
			matCounts[item.Name] = item.Count
		end
	end

	for matName, qty in pairs(requirements) do
		if not matCounts[matName] or matCounts[matName] < qty then
			return false, matCounts, matName, qty, matCounts[matName] or 0
		end
	end

	return true, matCounts
end

local function craftScroll(displayName, craftName, currentCount, requirements)
	log(displayName .. " Scrolls: " .. currentCount .. "/10")

	local enough, _, missingName, neededQty, ownedQty = hasMaterials(requirements)

	if enough then
		local success, err = pcall(function()
			RF_Craft:InvokeServer("Craft", craftName, 1, {})
		end)

		if success then
			log("Crafted 1 " .. displayName .. " Scroll")
		else
			log("Craft failed: " .. tostring(err))
		end
	else
		log("Need " .. missingName .. ": " .. ownedQty .. "/" .. neededQty)
	end
end

log("Checking scrolls...")

while true do
	local commonScrolls, rareScrolls, legendaryScrolls, mythicalScrolls = getScrollCounts()

	if commonScrolls < 10 then
		craftScroll("Common", "CommonScroll", commonScrolls, commonMaterials)
	elseif rareScrolls < 10 then
		craftScroll("Rare", "RareScroll", rareScrolls, rareMaterials)
	elseif legendaryScrolls < 10 then
		craftScroll("Legendary", "LegendaryScroll", legendaryScrolls, legendaryMaterials)
	elseif mythicalScrolls < 10 then
		craftScroll("Mythical", "MythicalScroll", mythicalScrolls, mythicalMaterials)
	else
		break
	end

	task.wait(5)
end

log("Crafting completed for " .. lp.Name)
