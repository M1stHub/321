local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer       = Players.LocalPlayer

local TIKI_P1 = Vector3.new(-16008, 252, -188)
local TIKI_P2 = Vector3.new(-16952, -4, 842)
local TIKI_LO = Vector3.new(math.min(TIKI_P1.X, TIKI_P2.X), math.min(TIKI_P1.Y, TIKI_P2.Y), math.min(TIKI_P1.Z, TIKI_P2.Z))
local TIKI_HI = Vector3.new(math.max(TIKI_P1.X, TIKI_P2.X), math.max(TIKI_P1.Y, TIKI_P2.Y), math.max(TIKI_P1.Z, TIKI_P2.Z))

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

local function isInTiki(pos)
    return pos.X >= TIKI_LO.X and pos.X <= TIKI_HI.X
       and pos.Y >= TIKI_LO.Y and pos.Y <= TIKI_HI.Y
       and pos.Z >= TIKI_LO.Z and pos.Z <= TIKI_HI.Z
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

local function runGuard()
    local boats = workspace:WaitForChild("Boats")

    while true do
        while not boats:FindFirstChild("Beast Hunter") do task.wait(1) end

        local hunter = boats:FindFirstChild("Beast Hunter")
        local hunterInTiki = hunter and isInTiki(hunter:GetPivot().Position)

        if hunterInTiki and not isWhitelisted() then
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local hrp  = char:FindFirstChild("HumanoidRootPart")

            if hrp and not isInTiki(hrp.Position) then
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1)
                tryBoatCastleTeleport()
            end
        end

        while boats:FindFirstChild("Beast Hunter") do task.wait(1) end
    end
end

task.spawn(runGuard)
