local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer       = Players.LocalPlayer

local function isWhitelisted()
    local v = getgenv().resetWhitelist
    return v == LocalPlayer.UserId or v == tostring(LocalPlayer.UserId)
end

local function isInModelBounds(pos, model)
    local ok, boundCF, boundSize = pcall(function() return model:GetBoundingBox() end)
    if not ok then return false end
    local localPos = boundCF:PointToObjectSpace(pos)
    local half = boundSize / 2
    return math.abs(localPos.X) <= half.X
       and math.abs(localPos.Y) <= half.Y
       and math.abs(localPos.Z) <= half.Z
end

local function isInBoatCastle(pos)
    local map = workspace:FindFirstChild("Map")
    local castle = map and map:FindFirstChild("Boat Castle")
    if not castle then return false end
    return isInModelBounds(pos, castle)
end

local function tryBoatCastleTeleport()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return end
    if not isInBoatCastle(hrp.Position) then return end

    local rf = game:GetService("ReplicatedStorage")
        :WaitForChild("Modules")
        :WaitForChild("Net")
        :WaitForChild("RF/BoatCastleTeleporters")

    pcall(function()
        local boat = CollectionService:GetTagged("BoatCastleTeleporter")[1]
        if not boat then return end
        rf:InvokeServer("InitiateTeleport", boat)
    end)
end

local function onBoatSpawned(child)
    if child.Name ~= "Beast Hunter" then return end
    if isWhitelisted() then return end

    task.spawn(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum and hum.Health > 0 then
            hum.Health = 0
        end
        LocalPlayer.CharacterAdded:Wait()
        task.wait(1)
        tryBoatCastleTeleport()
    end)
end

local function watchBoats()
    local boats = workspace:WaitForChild("Boats")

    for _, child in ipairs(boats:GetChildren()) do
        onBoatSpawned(child)
    end

    boats.ChildAdded:Connect(onBoatSpawned)
end

task.spawn(watchBoats)
