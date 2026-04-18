repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Tracker = Instance.new("ScreenGui")
Tracker.Name = "Tracker"
Tracker.Parent = player:WaitForChild("PlayerGui")
Tracker.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function addStroke(obj, color, thickness)
	if obj and not obj:FindFirstChildOfClass("UIStroke") then
		local stroke = Instance.new("UIStroke")
		stroke.Color = color or Color3.fromRGB(255, 255, 255)
		stroke.Thickness = thickness or 1
		stroke.Parent = obj
	end
end

local function newInstance(class, parent, props)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end

local function addCorner(parent)
	Instance.new("UICorner").Parent = parent
end

local MainBG = newInstance("Frame", Tracker, {
	Name = "MainBG",
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -3, 0, -55),
	Size = UDim2.new(0, 250, 0, 305)
})
addCorner(MainBG)
addStroke(MainBG)

newInstance("TextLabel", MainBG, {
	Name = "MainText",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.new(-0.0499185324, 0, -0.00327868853, 0),
	Size = UDim2.new(0, 249, 0, 50),
	Font = Enum.Font.Arial,
	Text = "Tracker",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 18
})

local Items = newInstance("Frame", MainBG, {
	Name = "Items",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.new(-0.0329896919, 0, 0.145446181, 0),
	Size = UDim2.new(0, 250, 0, 260)
})
newInstance("UIListLayout", Items, {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0.05, 0)
})
newInstance("UIPadding", MainBG, {PaddingLeft = UDim.new(0.05, 0)})

local function makeBar(parent, itemName)
	local label = newInstance("TextLabel", parent, {
		Name = itemName,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 60, 0, 30),
		Font = Enum.Font.Arial,
		Text = itemName,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local bg = newInstance("Frame", label, {
		Name = "BG",
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Position = UDim2.new(-0.0777496323, 0, 1, 0),
		Size = UDim2.new(0, 250, 0, 5)
	})
	addCorner(bg)
	local bar = newInstance("Frame", bg, {
		Name = "Bar",
		BackgroundColor3 = Color3.fromRGB(85, 255, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.0112934569, 0, 0, 0),
		Size = UDim2.new(0, 0, 1, 0)
	})
	newInstance("UICorner", bar, {Name = "BarCorner"})
	local counter = newInstance("TextLabel", bg, {
		Name = "Counter",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.860000014, 0, -5, 0),
		Size = UDim2.new(0, 25, 0, 25),
		Font = Enum.Font.Arial,
		Text = "0/99",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14
	})
	return {Label = label, Bar = bar, Counter = counter}
end

local itemData = {
	"Leviathan Heart",
	"Leviathan Scale",
	"Mythical Scroll",
	"Terror Eyes",
	"Fool's Gold",
	"Electrical Wings"
}

local trackerItems = {}
for i, name in ipairs(itemData) do
	local info = makeBar(Items, name)
	trackerItems[name] = info
	info.Label.LayoutOrder = i
end

local function updateBar(current, info)
	local percent = math.clamp(current / 99, 0, 1)
	local color
	if current <= 24 then
		color = Color3.fromRGB(255, 0, 0)
	elseif current <= 49 then
		color = Color3.fromRGB(255, 165, 0)
	elseif current <= 74 then
		color = Color3.fromRGB(255, 255, 0)
	else
		color = Color3.fromRGB(0, 255, 0)
	end
	info.Bar.Size = UDim2.new(percent, 0, 1, 0)
	info.Bar.BackgroundColor3 = color
	info.Counter.Text = current .. "/99"
	info.Counter.TextColor3 = color
end

local function getInventory()
	local remotesObj = RepStorage:WaitForChild("Remotes")
	local comm = remotesObj:FindFirstChild("CommF_")
	if not comm then return {} end
	local success, response = pcall(function()
		return comm:InvokeServer("getInventory")
	end)
	if success and typeof(response) == "table" then
		return response
	end
	return {}
end

local function updateTracker()
	local trackerData = {}
	for _, name in ipairs(itemData) do
		trackerData[name] = 0
	end
	local inventory = getInventory()
	for _, item in pairs(inventory) do
		pcall(function()
			if typeof(item) == "table" and trackerData[item.Name] ~= nil then
				trackerData[item.Name] = tonumber(item.Count) or 0
			end
		end)
	end
	for name, value in pairs(trackerData) do
		updateBar(value, trackerItems[name])
	end
end

game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
local notif = game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("Notifications", 10)
if notif then notif:Destroy() end

updateTracker()
while true do
	task.wait(5)
	updateTracker()
end
