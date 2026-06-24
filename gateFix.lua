print('gateFix loaded')
local Workspace  = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local NPC_NAME  = "Frozen Watcher"
local GATE_NAME = "LeviathanGate"

local function normalize(name)
	return tostring(name):lower():gsub("%s+", "")
end

local function findDescendantNamed(root, targetName)
	local target = normalize(targetName)
	for _, inst in ipairs(root:GetDescendants()) do
		if normalize(inst.Name) == target then
			return inst
		end
	end
	return nil
end

local function findDescendantLike(root, fragment)
	local frag = normalize(fragment)
	for _, inst in ipairs(root:GetDescendants()) do
		if normalize(inst.Name):find(frag, 1, true) then
			return inst
		end
	end
	return nil
end

local function getPosition(inst)
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	if inst:IsA("Model") then
		return inst:GetPivot()
	end
	if inst:IsA("Attachment") then
		return inst.WorldCFrame
	end
	return nil
end

local function getRootPart(npc)
	if npc:IsA("Model") then
		return npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
	end
	if npc:IsA("BasePart") then
		return npc
	end
	return nil
end

local FIND_TIMEOUT = 30

local function waitFor(getter, timeout)
	local deadline = os.clock() + timeout
	repeat
		local found = getter()
		if found then return found end
		task.wait(0.5)
	until os.clock() >= deadline
	return getter()
end

local leviathanGate = waitFor(function()
	return findDescendantNamed(Workspace, GATE_NAME) or Workspace:FindFirstChild(GATE_NAME, true)
end, FIND_TIMEOUT)
if not leviathanGate then
	warn("[gateFix] Could not find " .. GATE_NAME .. " anywhere in Workspace after " .. FIND_TIMEOUT .. "s.")
	return
end

local leftGate = waitFor(function()
	return findDescendantLike(leviathanGate, "leftgate")
end, FIND_TIMEOUT)
if not leftGate then
	warn("[gateFix] Could not find anything resembling 'left gate' inside " .. GATE_NAME .. " after " .. FIND_TIMEOUT .. "s.")
	return
end

local targetCFrame = getPosition(leftGate)
if not targetCFrame then
	warn("[gateFix] Found '" .. leftGate.Name .. "' but couldn't read a position from it.")
	return
end

print("[gateFix] Locking " .. NPC_NAME .. " to " .. leftGate:GetFullName())

local connection
local watcherConn

local function pin(npc)
	local root = getRootPart(npc)
	if not root then return end

	if root:IsA("BasePart") then
		root.Anchored = true
		root.CFrame = targetCFrame
	elseif npc:IsA("Model") then
		npc:PivotTo(targetCFrame)
	end

	if connection then
		connection:Disconnect()
	end

	connection = RunService.Heartbeat:Connect(function()
		if not npc.Parent then
			connection:Disconnect()
			connection = nil
			return
		end
		if root:IsA("BasePart") then
			if root.CFrame ~= targetCFrame then
				root.CFrame = targetCFrame
			end
		elseif npc:IsA("Model") then
			npc:PivotTo(targetCFrame)
		end
	end)
end

local npcFolder = Workspace:FindFirstChild("NPCs")
if not npcFolder then
	warn("[gateFix] Workspace.NPCs not found.")
	return
end

local existing = npcFolder:FindFirstChild(NPC_NAME)
if existing then
	pin(existing)
end

watcherConn = npcFolder.ChildAdded:Connect(function(child)
	if child.Name == NPC_NAME then
		pin(child)
	end
end)

getgenv().GateFixDisconnect = function()
	if connection then connection:Disconnect() end
	if watcherConn then watcherConn:Disconnect() end
end
