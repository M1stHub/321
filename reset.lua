local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local afkTimer = 0
local lastCheckTime = tick()
local lastPosition = nil

localPlayer.CharacterAdded:Connect(function(character)
	afkTimer = 0
	lastPosition = nil
	lastCheckTime = tick()
	character:WaitForChild("HumanoidRootPart")
	lastPosition = character.HumanoidRootPart.Position
end)

RunService.Heartbeat:Connect(function()
	local now = tick()
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

	if (root.Position * Vector3.new(1, 0, 1) - lastPosition * Vector3.new(1, 0, 1)).Magnitude >= 5 then
		afkTimer = 0
		lastPosition = root.Position
	else
		afkTimer += delta
		if afkTimer >= 300 then
			humanoid.Health = 0
			afkTimer = 0
			lastPosition = nil
		end
	end
end)

if localPlayer.Character then
	local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root then lastPosition = root.Position end
end
