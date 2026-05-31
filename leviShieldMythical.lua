repeat wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

task.spawn(function()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local tries = 0
	while not lp.Team and tries < 10 do
		pcall(function()
			Remotes.CommF_:InvokeServer("SetTeam", "Marines")
		end)
		tries = tries + 1
		task.wait(1)
	end
	if lp.Team and lp.Team.Name == "Marines" then
		warn("[Script] Joined Marines")
	else
		warn("[Script] Failed to join Marines after " .. tries .. " tries")
	end
end)

task.wait(2)

-- UI
for _, n in ipairs({"CraftingTracker"}) do
	local old = CoreGui:FindFirstChild(n) or playerGui:FindFirstChild(n)
	if old then old:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "CraftingTracker"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = playerGui end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 110)
frame.Position = UDim2.new(1, -350, 0.5, -55)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

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
label.Text = "Starting..."
label.Parent = frame

local dragging, dragStart, startPos = false, nil, nil
frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true; dragStart = input.Position; startPos = frame.Position
	end
end)
frame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

local function setUI(lines, footer)
	if footer then table.insert(lines, footer) end
	label.Text = table.concat(lines, "\n")
	frame.Size = UDim2.new(0, 340, 0, math.max(50, 22 + (#lines * 17)))
end

local function log(msg)
	print(msg)
	label.Text = msg
	frame.Size = UDim2.new(0, 340, 0, 50)
end

local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local RF_Craft = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/Craft")

local function getInventory()
	return CommF_:InvokeServer("getInventory")
end

local function getMaterialCounts(inventory)
	local counts = {}
	for _, item in pairs(inventory) do
		if item.Type == "Material" then
			counts[item.Name] = item.Count
		end
	end
	return counts
end

local function hasMaterials(requirements, matCounts)
	for _, req in ipairs(requirements) do
		local have = matCounts[req[1]] or 0
		if have < req[2] then return false, req[1], req[2], have end
	end
	return true
end

-- Phase 1: Leviathan Shield
local shieldMaterials = {
	{"Mirror Fractal",  1},
	{"Leviathan Scale", 30},
	{"Electric Wing",   10},
	{"Fool's Gold",     20},
}

local function findShield(inventory)
	for _, item in pairs(inventory) do
		if item.Type == "Wear" and item.Name == "Leviathan Shield" then
			return true, item.NetworkedUID
		end
	end
	return false, nil
end

local function updateShieldUI(matCounts, footer)
	local lines = {"Crafting Leviathan Shield"}
	for _, req in ipairs(shieldMaterials) do
		table.insert(lines, req[1] .. "  " .. (matCounts[req[1]] or 0) .. "/" .. req[2])
	end
	setUI(lines, footer)
end

log("Checking Leviathan Shield...")
local inv = getInventory()
local owned, shieldUID = findShield(inv)

if not owned then
	local matCounts = getMaterialCounts(inv)
	updateShieldUI(matCounts)

	local enough, missingName, neededQty, ownedQty = hasMaterials(shieldMaterials, matCounts)
	while not enough do
		updateShieldUI(matCounts, "Missing: " .. missingName .. " " .. ownedQty .. "/" .. neededQty)
		task.wait(5)
		matCounts = getMaterialCounts(getInventory())
		enough, missingName, neededQty, ownedQty = hasMaterials(shieldMaterials, matCounts)
	end

	updateShieldUI(matCounts, "Crafting...")
	local ok, err = pcall(function()
		RF_Craft:InvokeServer("Craft", "LeviathanShield")
	end)

	task.wait(1)
	inv = getInventory()
	owned, shieldUID = findShield(inv)

	if ok and owned then
		updateShieldUI(getMaterialCounts(inv), "Crafted Leviathan Shield!")
	else
		updateShieldUI(getMaterialCounts(inv), ok and "Craft done but shield not found?" or "Craft failed: " .. tostring(err))
	end
	task.wait(2)
else
	log("Already own Leviathan Shield")
	task.wait(1)
end

if shieldUID then
	log("Equipping Leviathan Shield...")
	pcall(function() CommF_:InvokeServer("LoadItem", shieldUID) end)
	task.wait(1)
	log("Leviathan Shield equipped")
	task.wait(1)
else
	log("No UID found, skipping equip")
	task.wait(2)
end

-- Phase 2: Mythical Scrolls
local mythicalMaterials = {
	{"Leviathan Heart", 1},
	{"Leviathan Scale", 15},
	{"Terror Eyes",     1},
	{"Fool's Gold",     20},
}

local function getMythicalScrollCount()
	for _, item in pairs(getInventory()) do
		if item.Type == "Scroll" and item.Name == "Mythical Scroll" then
			return item.Count
		end
	end
	return 0
end

local function updateScrollUI(current, target, matCounts, footer)
	local lines = {"Mythical Scroll  " .. current .. "/" .. target}
	for _, req in ipairs(mythicalMaterials) do
		table.insert(lines, req[1] .. "  " .. (matCounts[req[1]] or 0) .. "/" .. req[2])
	end
	setUI(lines, footer)
end

log("Starting Mythical Scroll crafting...")

while true do
	local count = getMythicalScrollCount()
	if count >= 10 then break end

	local matCounts = getMaterialCounts(getInventory())
	local enough, missingName, neededQty, ownedQty = hasMaterials(mythicalMaterials, matCounts)

	if enough then
		local ok, err = pcall(function()
			RF_Craft:InvokeServer("Craft", "MythicalScroll", 1, {})
		end)
		matCounts = getMaterialCounts(getInventory())
		updateScrollUI(getMythicalScrollCount(), 10, matCounts, ok and "Crafted!" or "Failed: " .. tostring(err))
	else
		updateScrollUI(count, 10, matCounts, "Need " .. missingName .. " " .. ownedQty .. "/" .. neededQty)
	end

	task.wait(5)
end

log("Done! " .. lp.Name .. " — 10 Mythical Scrolls crafted")
