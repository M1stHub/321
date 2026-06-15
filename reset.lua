local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local RESET_AFTER = 300
local MOVE_THRESHOLD = 5

local afkTimer = 0
local lastCheckTime = os.clock()
local lastPosition = nil

local function horizontalDistance(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function forceReset(character, humanoid)
	if humanoid then
		pcall(function()
			humanoid.Health = 0
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end)
	end

	if character then
		pcall(function()
			character:BreakJoints()
		end)
	end
end

localPlayer.CharacterAdded:Connect(function(character)
	afkTimer = 0
	lastPosition = nil
	lastCheckTime = os.clock()
	character:WaitForChild("HumanoidRootPart")
	lastPosition = character.HumanoidRootPart.Position
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local delta = now - lastCheckTime
	lastCheckTime = now

	local character = localPlayer.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end

	if not lastPosition then
		lastPosition = root.Position
		return
	end

	if horizontalDistance(root.Position, lastPosition) >= MOVE_THRESHOLD then
		afkTimer = 0
		lastPosition = root.Position
	else
		afkTimer += delta
		if afkTimer >= RESET_AFTER then
			forceReset(character, humanoid)
			afkTimer = 0
			lastPosition = nil
		end
	end
end)

if localPlayer.Character then
	local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root then lastPosition = root.Position end
end
