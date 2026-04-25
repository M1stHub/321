local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local TIKI_MIN = Vector3.new(-15982, 9, 699)
local TIKI_MAX = Vector3.new(-16353, 347, 8)

local FOLDER_NAME = "__BoatGuardViz"
local old = workspace:FindFirstChild(FOLDER_NAME)
if old then old:Destroy() end

local function isInTikiXZ(pos)
    return pos.X >= math.min(TIKI_MIN.X, TIKI_MAX.X) and pos.X <= math.max(TIKI_MIN.X, TIKI_MAX.X)
       and pos.Z >= math.min(TIKI_MIN.Z, TIKI_MAX.Z) and pos.Z <= math.max(TIKI_MIN.Z, TIKI_MAX.Z)
end

local function getBoat()
    local boats = workspace:FindFirstChild("Boats")
    return boats and boats:FindFirstChild("Beast Hunter")
end

local lastKill = 0
local KILL_COOLDOWN = 3

RunService.Heartbeat:Connect(function()
    local now = tick()

    local boat = getBoat()
    if not boat then return end

    local seat = boat:FindFirstChild("VehicleSeat", true)
    if not seat or not seat:FindFirstChild("SeatWeld") then return end

    local primary = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not primary or not isInTikiXZ(primary.Position) then return end

    local localChar = LocalPlayer.Character
    local localRoot = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar.PrimaryPart)
    if localRoot and isInTikiXZ(localRoot.Position) then return end

    if (now - lastKill) >= KILL_COOLDOWN then
        lastKill = now
        local hum = localChar and localChar:FindFirstChildWhichIsA("Humanoid")
        if hum and hum.Health > 0 then
            hum.Health = 0
        end
    end
end)
