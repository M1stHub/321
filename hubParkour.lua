repeat wait() until game:IsLoaded() and game.Players and game.Players.LocalPlayer
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM        = game:GetService("VirtualInputManager")

local lp  = Players.LocalPlayer
local cam = workspace.CurrentCamera

if getgenv().__stopP then pcall(getgenv().__stopP) end
task.wait(0.1)

local botCfg = getgenv().DungeonBotConfig or {}
local ALLOWED_ACCOUNTS = botCfg.allowedAccounts or {
    "1", "2", "3", "4",
}

local CFG = {
    reach                 = 6,
    moveRefresh           = 0.12,
    walkInDistance        = 18,
    warmup                = 0.75,
    pathJitter            = 2,
    pathJitterFade        = 75,
    dashCooldown          = 0.28,
    dashCooldownJitter    = 0.04,
    dashDistance          = 37,
    dashHold              = 0.035,
    dashMinFlatDistance   = 49,
    jumpCooldown          = 0.075,
    jumpHold              = 0.055,
    burstJumps            = 3,
    burstJumpInterval     = 0.18,
    preJumpZ              = -135,
    climbTop              = 260,
    cruiseFloor           = 252,
    finalFloorY           = 233,
    finalPlatformDistance = 24,
    obstacleBypassZ       = -336,
    obstacleRightX        = -215,
    obstacleLeftX         = -500,
    obstaclePad           = 10,
    stuckCheck            = 0.55,
    stuckMove             = 2.5,
    stuckLimit            = 5,
    maxRunTime            = 35,
    padWaitSecs           = botCfg.padWaitSecs   or 20,
    regroupRadius         = botCfg.regroupRadius or 15,
    padPoll               = 0.3,
    padFrontExtra         = botCfg.padFrontExtra or 18,
    padVerifySecs         = botCfg.padVerifySecs or 0.85,
    ringMin               = 5,
    ringMax               = 18,
    bailDeckTolerance     = 2.2,
    multiPad              = getgenv().ParkourMultiPad     ~= false,
    startDungeon          = getgenv().ParkourStartDungeon ~= false,
    debugGui              = getgenv().ParkourDebugGui     ~= false,
    forcePadBail          = getgenv().ParkourForcePadBail == true,
}

local TRIP_Z      = -172
local STOP_JUMP_Z = -318
local OBSTACLE_BOX = { minX = -393, maxX = -305, minZ = -357, maxZ = -246 }

local PADS = {
    {
        id      = 3,
        name    = "DUNGEON_TELEPORTER3",
        color   = Color3.fromRGB(100, 255, 0),
        rally   = Vector3.new(-466, 235, -423),
        walkOn  = Vector3.new(-487, 237, -433),
        transit = {},
    },
    {
        id      = 2,
        name    = "DUNGEON_TELEPORTER2",
        color   = Color3.fromRGB(255, 100, 0),
        rally   = Vector3.new(-423.566925, 235.028915, -387.250397),
        walkOn  = Vector3.new(-360.964539, 236.566925, -447.527710),
        transit = {
            Vector3.new(-423.566925, 235.028915, -387.250397),
        },
    },
    {
        id      = 1,
        name    = "DUNGEON_TELEPORTER1",
        color   = Color3.fromRGB(0, 255, 255),
        rally   = Vector3.new(-294.361115, 235.028915, -387.542358),
        walkOn  = Vector3.new(-231.894653, 236.566925, -432.720825),
        transit = {
            Vector3.new(-423.566925, 235.028915, -387.250397),
            Vector3.new(-294.361115, 235.028915, -387.542358),
        },
    },
}

local running = true
local char, hum, hrp

local oldCameraType   = cam and cam.CameraType
local oldCameraCFrame = cam and cam.CFrame
local oldAutoRotate   = nil

local DBG = {
    traj   = {}, jumps = {}, dashes = {}, bails = {},
    phase  = "init", coord = "-", pad = nil, segment = nil,
    target = nil, moveTarget = nil, done = false, runBias = nil,
}

getgenv().__pk    = DBG
getgenv().__pdone = false

local function randBetween(a, b)
    return a + math.random() * (b - a)
end

local function flatDir(a, b)
    local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
    local m = d.Magnitude
    if m < 1e-4 then return Vector3.new(0, 0, 0), 0 end
    return d / m, m
end

local function flatDist(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local allowedLookup = {}
for _, name in ipairs(ALLOWED_ACCOUNTS) do
    allowedLookup[name] = true
end

local function isAllowed(name)
    return allowedLookup[name] == true
end

local function totalAllowed()
    return math.max(#ALLOWED_ACCOUNTS, 1)
end

local function refreshCharacter()
    char = lp.Character or lp.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid")
    hrp  = char:WaitForChild("HumanoidRootPart")
    return char, hum, hrp
end

local function padFolder()
    local map = workspace:FindFirstChild("Map")
    local hub = map and map:FindFirstChild("Simulation Hub")
    return hub and hub:FindFirstChild("Pads")
end

local function getPadObject(pad)
    local pads = padFolder()
    return pads and pads:FindFirstChild(pad.name)
end

local function getPadPart(pad)
    local obj = getPadObject(pad)
    return obj and obj:FindFirstChild("Pad")
end

local function isPlayerOnPad(player, pad)
    local part = getPadPart(pad)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not part or not root then return false end

    local local_ = part.CFrame:PointToObjectSpace(root.Position)
    local half, margin = part.Size * 0.5, 3
    return math.abs(local_.X) <= half.X + margin
        and math.abs(local_.Z) <= half.Z + margin
        and root.Position.Y >= part.Position.Y - 8
        and root.Position.Y <= part.Position.Y + 18
end

local function padRandomCount(pad)
    local n = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if not isAllowed(player.Name) and isPlayerOnPad(player, pad) then
            n += 1
        end
    end
    return n
end

local function padAnyCount(pad)
    local n = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if isPlayerOnPad(player, pad) then
            n += 1
        end
    end
    return n
end

local function allowedOnPadCount(pad)
    local n = 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do
        local player = Players:FindFirstChild(name)
        if player and isPlayerOnPad(player, pad) then
            n += 1
        end
    end
    return n
end

local function onlyAllowedOnPad(pad)
    return padRandomCount(pad) == 0
end

local function meOnPad(pad)
    return isPlayerOnPad(lp, pad)
end

local function accsNear(point, radius)
    local n = 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do
        local player = Players:FindFirstChild(name)
        local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and flatDist(root.Position, point) <= radius then
            n += 1
        end
    end
    return n
end

local function findPadById(id)
    for _, pad in ipairs(PADS) do
        if pad.id == id or pad.name == id or tostring(pad.id) == tostring(id) then
            return pad
        end
    end
end
local function deckFloorY(x, z)
    local filter = {}
    if char then table.insert(filter, char) end
    for _, n in ipairs({ "ParkourVis", "ParkourPadVis" }) do
        local f = workspace:FindFirstChild(n)
        if f then table.insert(filter, f) end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter

    local result = workspace:Raycast(Vector3.new(x, 255, z), Vector3.new(0, -45, 0), params)
    return result and result.Position.Y or nil
end

local function ringPoint(pad, minZDot)
    minZDot = minZDot or -1

    local part = getPadPart(pad)
    if not part then return pad.rally or pad.walkOn end

    local c = part.Position
    local halfX, halfZ = part.Size.X * 0.5, part.Size.Z * 0.5
    local edge = math.max(halfX, halfZ)

    for _ = 1, 18 do
        local ang = math.random() * math.pi * 2
        local dx, dz = math.cos(ang), math.sin(ang)
        if dz >= minZDot then
            local rad = edge + randBetween(CFG.ringMin, CFG.ringMax)
            local x, z = c.X + dx * rad, c.Z + dz * rad
            local fy = deckFloorY(x, z)
            if fy and math.abs(fy - c.Y) <= CFG.bailDeckTolerance then
                local off = part.CFrame:PointToObjectSpace(Vector3.new(x, c.Y, z))
                if math.abs(off.X) > halfX + 2 or math.abs(off.Z) > halfZ + 2 then
                    return Vector3.new(x, fy + 3, z)
                end
            end
        end
    end

    local f = pad.rally and Vector3.new(pad.rally.X - c.X, 0, pad.rally.Z - c.Z) or Vector3.new(0, 0, 1)
    f = (f.Magnitude > 0.1) and f.Unit or Vector3.new(0, 0, 1)
    return Vector3.new(c.X + f.X * (edge + CFG.ringMin), c.Y + 3, c.Z + f.Z * (edge + CFG.ringMin))
end

local function approachPoint(pad)
    return ringPoint(pad, -0.15)
end

local function bailPoint(pad)
    return ringPoint(pad, -0.7)
end

local function frontPoint(pad)
    local on, rally = pad.walkOn, pad.rally or pad.walkOn
    local dir = Vector3.new(rally.X - on.X, 0, rally.Z - on.Z)
    if dir.Magnitude < 1 then return approachPoint(pad) end

    local part = getPadPart(pad)
    local backoff = part and (math.max(part.Size.X, part.Size.Z) * 0.5 + 16 + CFG.padFrontExtra) or 28
    return on + dir.Unit * backoff
end

local function routeAroundObstacle(pad)
    if pad.id == 3 then
        return {
            Vector3.new(CFG.obstacleLeftX + randBetween(-7, 6), 235, -360 + randBetween(-13, 13)),
        }
    end
    if pad.id == 1 then
        return {
            Vector3.new(CFG.obstacleRightX + randBetween(-6, 7), 235, -366 + randBetween(-13, 13)),
        }
    end

    local side = getgenv().ParkourRouteSide
    if side ~= "left" and side ~= "right" then side = "left" end
    local x = (side == "left") and CFG.obstacleLeftX or CFG.obstacleRightX
    return {
        Vector3.new(x + randBetween(-6, 6), 235, -366 + randBetween(-13, 13)),
    }
end

local function buildRouteForPad(pad)
    local route = {}
    for _, p in ipairs(routeAroundObstacle(pad)) do
        table.insert(route, p)
    end
    table.insert(route, approachPoint(pad))
    return route
end

local function insideObstacleBox(pos)
    local pad = CFG.obstaclePad
    return pos.X >= OBSTACLE_BOX.minX - pad and pos.X <= OBSTACLE_BOX.maxX + pad
        and pos.Z >= OBSTACLE_BOX.minZ - pad and pos.Z <= OBSTACLE_BOX.maxZ + pad
end

local function segmentEntersObstacle(a, b)
    for i = 0, 18 do
        if insideObstacleBox(a:Lerp(b, i / 18)) then
            return true
        end
    end
    return false
end

local function obstacleBypassTarget(pos, target)
    if not segmentEntersObstacle(pos, target) then return target end

    local midX = (OBSTACLE_BOX.minX + OBSTACLE_BOX.maxX) * 0.5
    local bypassX = (target.X < midX) and CFG.obstacleLeftX or CFG.obstacleRightX
    return Vector3.new(bypassX + randBetween(-3, 3), target.Y, CFG.obstacleBypassZ + randBetween(-2, 2))
end

local RUN_BIAS = (function()
    local side = (math.random() < 0.5) and -1 or 1
    return Vector3.new(randBetween(-2, 2), 0, side * randBetween(3, CFG.pathJitter))
end)()
DBG.runBias = RUN_BIAS

local function biasedTarget(target, hdist)
    local fade = math.clamp(hdist / CFG.pathJitterFade, 0, 1)
    return target + RUN_BIAS * fade
end

local HELD = {}

local function holdKey(key)
    if HELD[key] then return end
    HELD[key] = true
    VIM:SendKeyEvent(true, key, false, game)
end

local function releaseKey(key)
    if not HELD[key] then return end
    HELD[key] = nil
    VIM:SendKeyEvent(false, key, false, game)
end

local function pulseKey(key, hold)
    task.spawn(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(hold)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local function holdForward()
    holdKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.A)
    releaseKey(Enum.KeyCode.D)
end

local function releaseForward()
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.A)
    releaseKey(Enum.KeyCode.D)
end

local function releaseAllKeys()
    if hum then hum:Move(Vector3.new(0, 0, 0), false) end
    for _, k in ipairs({ Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }) do
        releaseKey(k)
    end
    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
end

local function dash(reason)
    if hrp then
        table.insert(DBG.dashes, string.format("%d,%d,%d %s",
            hrp.Position.X, hrp.Position.Y, hrp.Position.Z, reason or "dash"))
    end
    pulseKey(Enum.KeyCode.Q, CFG.dashHold)
end

local function jump(reason)
    if hum then hum.Jump = true end
    if hrp then
        table.insert(DBG.jumps, string.format("%d,%d,%d %s",
            hrp.Position.X, hrp.Position.Y, hrp.Position.Z, reason or "jump"))
    end
    pulseKey(Enum.KeyCode.Space, CFG.jumpHold)
end

local function aimCam(pos, dir)
    if not cam or dir.Magnitude < 0.05 then return end
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 0.05 then return end
    flat = flat.Unit
    cam.CFrame = CFrame.lookAt(pos - flat * 22 + Vector3.new(0, 12, 0), pos + flat * 9)
end

local function faceDirection(pos, dir)
    if not hrp or dir.Magnitude < 0.05 then return end
    hrp.CFrame = CFrame.lookAt(pos, pos + dir)
end

local PAD_VIS_FOLDER   = "ParkourPadVis"
local ROUTE_VIS_FOLDER = "ParkourVis"

local GREEN = Color3.fromRGB(80, 255, 120)
local RED   = Color3.fromRGB(255, 70, 70)
local CYAN  = Color3.fromRGB(90, 200, 255)

local function create(class, props)
    local inst = Instance.new(class)
    local parent = props.Parent
    props.Parent = nil
    for k, v in pairs(props) do inst[k] = v end
    inst.Parent = parent
    return inst
end

local function makeLabel(parent, text, color, sizeY, offsetY)
    local bb = create("BillboardGui", { Parent = parent, AlwaysOnTop = true,
        Size = UDim2.new(0, 110, 0, sizeY or 22), StudsOffset = Vector3.new(0, offsetY or 4, 0) })
    return create("TextLabel", { Parent = bb, Size = UDim2.new(1, 0, 1, 0), Text = text,
        BackgroundTransparency = 1, TextColor3 = color or Color3.new(1, 1, 1), TextStrokeTransparency = 0,
        Font = Enum.Font.GothamBold, TextScaled = true })
end

local padVis = {}

local function buildPadVisuals()
    local old = workspace:FindFirstChild(PAD_VIS_FOLDER)
    if old then old:Destroy() end

    local folder = create("Folder", { Name = PAD_VIS_FOLDER, Parent = workspace })

    local HEIGHT = 20
    for _, pad in ipairs(PADS) do
        local part = getPadPart(pad)
        if part then
            local box = create("Part", { Parent = folder, Name = pad.name, Color = pad.color,
                Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
                Transparency = 0.6, Material = Enum.Material.Neon,
                Size = Vector3.new(part.Size.X, HEIGHT, part.Size.Z),
                CFrame = CFrame.new(part.Position + Vector3.new(0, HEIGHT / 2 - part.Size.Y / 2, 0)) })
            create("SelectionBox", { Parent = box, Adornee = box, Color3 = pad.color,
                LineThickness = 0.05, SurfaceTransparency = 1 })

            local label = makeLabel(box, pad.name:gsub("DUNGEON_TELEPORTER", "Pad "), pad.color, 26, HEIGHT / 2 + 2)
            padVis[pad.name] = { box = box, label = label }
        end
    end
end

local function refreshPadVisuals(targetName)
    local total = totalAllowed()
    for _, pad in ipairs(PADS) do
        local vis = padVis[pad.name]
        if vis and vis.box.Parent then
            local randoms = padRandomCount(pad)
            local ours = allowedOnPadCount(pad)
            local short = pad.name:gsub("DUNGEON_TELEPORTER", "Pad ")
            local color, text

            if targetName == pad.name then
                color = CYAN
                text = short .. "  TARGET\nours " .. ours .. "/" .. total
            elseif randoms > 0 then
                color = RED
                text = short .. "  BUSY (" .. randoms .. ")"
            else
                color = GREEN
                text = short .. "  EMPTY"
            end

            vis.box.Color = color
            vis.label.Text = text
            vis.label.TextColor3 = color
        end

        pcall(function()
            local obj = getPadObject(pad)
            local lbl = obj and obj.Pad.TeleporterBillboard.Status
            if lbl then
                if targetName == pad.name then
                    lbl.Text = "TARGET"; lbl.TextColor3 = GREEN
                elseif padRandomCount(pad) > 0 then
                    lbl.Text = "BUSY"; lbl.TextColor3 = RED
                else
                    lbl.Text = "free"; lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
                end
            end
        end)
    end
end

local currentMarker

local function ensureRouteFolder()
    return workspace:FindFirstChild(ROUTE_VIS_FOLDER)
        or create("Folder", { Name = ROUTE_VIS_FOLDER, Parent = workspace })
end

local function addPoint(folder, pos, text, color)
    local p = create("Part", { Parent = folder, Shape = Enum.PartType.Ball, Color = color,
        Size = Vector3.new(4, 4, 4), Anchored = true, CanCollide = false, CanQuery = false,
        CastShadow = false, Material = Enum.Material.Neon, Transparency = 0.25, CFrame = CFrame.new(pos) })
    makeLabel(p, text, color)
    return p
end

local function addLine(folder, a, b, color)
    create("Part", { Parent = folder, Color = color, Material = Enum.Material.Neon,
        Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.45,
        Size = Vector3.new(0.35, 0.35, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b) })
end

local function buildRouteVisuals(route, target)
    local old = workspace:FindFirstChild(ROUTE_VIS_FOLDER)
    if old then old:Destroy() end

    local f = ensureRouteFolder()
    if route and #route > 0 then
        local prev
        for i, point in ipairs(route) do
            local color = (i == 1) and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(0, 255, 120)
            addPoint(f, point, tostring(i), color)
            if prev then addLine(f, prev, point, Color3.fromRGB(30, 80, 160)) end
            prev = point
        end
    elseif target then
        addPoint(f, target, "TARGET", Color3.fromRGB(0, 255, 120))
    end
end

local function setMoveTarget(label, pos, color)
    DBG.moveTarget = { label = label, pos = pos }

    local f = ensureRouteFolder()
    if not currentMarker or not currentMarker.Parent then
        currentMarker = create("Part", { Parent = f, Name = "MoveTarget", Shape = Enum.PartType.Ball,
            Size = Vector3.new(5, 5, 5), Anchored = true, CanCollide = false, CanQuery = false,
            CastShadow = false, Material = Enum.Material.Neon, Transparency = 0.05 })
        makeLabel(currentMarker, "NOW", Color3.fromRGB(255, 255, 80))
    end
    currentMarker.Color = color or Color3.fromRGB(255, 255, 80)
    currentMarker.CFrame = CFrame.new(pos)
end

local hudRows = {}

local function buildHud()
    if not CFG.debugGui then return end

    local parent = lp:FindFirstChild("PlayerGui")
    if not parent then return end

    local old = parent:FindFirstChild("ParkourHud")
    if old then old:Destroy() end

    local sg = create("ScreenGui", { Parent = parent, Name = "ParkourHud",
        ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    getgenv().__pkHud = sg

    local frame = create("Frame", { Parent = sg, BorderSizePixel = 0, Active = true, Draggable = true,
        Size = UDim2.new(0, 255, 0, 142), Position = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Color3.fromRGB(8, 10, 14) })
    create("UIStroke", { Parent = frame, Color = Color3.fromRGB(70, 160, 255), Thickness = 1.3 })

    create("TextLabel", { Parent = frame, Text = "Parkour", BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 0, 4),
        TextColor3 = Color3.fromRGB(150, 210, 255), Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left })

    for i, key in ipairs({ "Phase", "Coord", "Pad", "Segment", "Pos", "Target" }) do
        hudRows[key] = create("TextLabel", { Parent = frame, Text = key .. ": -", BackgroundTransparency = 1,
            Size = UDim2.new(1, -12, 0, 17), Position = UDim2.new(0, 6, 0, 23 + (i - 1) * 18),
            TextColor3 = Color3.fromRGB(220, 230, 255), Font = Enum.Font.Code, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left })
    end
end

local function startVisualLoop()
    task.spawn(function()
        while running do
            refreshPadVisuals(DBG.pad)
            if hudRows.Phase then
                local pos = hrp and string.format("%d,%d,%d", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) or "-"
                local t = DBG.moveTarget
                local tt = t and string.format("%s %d,%d,%d", t.label or "target", t.pos.X, t.pos.Y, t.pos.Z) or "-"
                hudRows.Phase.Text   = "Phase: "   .. tostring(DBG.phase)
                hudRows.Coord.Text   = "Coord: "   .. tostring(DBG.coord)
                hudRows.Pad.Text     = "Pad: "     .. tostring(DBG.pad)
                hudRows.Segment.Text = "Segment: " .. tostring(DBG.segment)
                hudRows.Pos.Text     = "Pos: "     .. pos
                hudRows.Target.Text  = "Target: "  .. tt
            end
            task.wait(0.2)
        end
    end)
end

local function record(pos, phase, hdist)
    table.insert(DBG.traj, string.format("%d,%d,%d %s d=%d", pos.X, pos.Y, pos.Z, phase, hdist))
    if #DBG.traj > 220 then
        table.remove(DBG.traj, 1)
    end
end

local function cleanup()
    running = false
    releaseAllKeys()

    if getgenv().__pkHud then
        pcall(function() getgenv().__pkHud:Destroy() end)
        getgenv().__pkHud = nil
    end

    if hum and hrp then
        hum:Move(Vector3.new(0, 0, 0), false)
        hum.CameraOffset = Vector3.new(0, 0, 0)
        hum.AutoRotate = (oldAutoRotate ~= nil) and oldAutoRotate or true
    end

    if cam then
        cam.CameraSubject = hum
        cam.CameraType = Enum.CameraType.Custom
    end
end
getgenv().__stopP = cleanup

local function onFinalPlatform(pos, target, hdist)
    if not hum or hum.FloorMaterial == Enum.Material.Air then return false end
    return pos.Y >= CFG.finalFloorY and hdist <= CFG.finalPlatformDistance and pos.Z <= target.Z + 35
end

local function getPhase(pos, target, hdist, crossed, stopJumping, burstDone, startedAt)
    if tick() - startedAt < CFG.warmup then return "warmup" end
    if stopJumping or onFinalPlatform(pos, target, hdist) then return "walkin" end
    if not crossed then return "approach" end
    if not burstDone then return "burst" end
    if pos.Y < CFG.climbTop then return "climb" end
    return "cruise"
end

local function parkourTo(target)
    refreshCharacter()
    setMoveTarget("parkour", target, Color3.fromRGB(80, 180, 255))

    if cam then
        oldCameraType, oldCameraCFrame = cam.CameraType, cam.CFrame
        cam.CameraSubject = hum
        cam.CameraType = Enum.CameraType.Scriptable
    end
    if oldAutoRotate == nil then oldAutoRotate = hum.AutoRotate end
    hum.AutoRotate = false

    local startedAt        = tick()
    local lastDash         = 0
    local nextDashAt       = 0
    local lastJump         = 0
    local lastCheck        = tick()
    local lastProgress     = hrp.Position
    local stuckCount       = 0
    local crossed          = hrp.Position.Z <= TRIP_Z
    local stopJumping      = hrp.Position.Z <= STOP_JUMP_Z
    local jumpBurst        = 0
    local nextBurstJump    = 0
    local prevZ            = hrp.Position.Z
    local postWallDashDone = stopJumping

    while running do
        RunService.Heartbeat:Wait()
        if not char or not char.Parent or not hum or hum.Health <= 0 or not hrp or not hrp.Parent then
            refreshCharacter()
            lastProgress = hrp.Position
        end

        local now = tick()
        local pos = hrp.Position
        local baseTarget = obstacleBypassTarget(pos, target)
        local steering = biasedTarget(baseTarget, flatDist(pos, baseTarget))
        local dir, hdist = flatDir(pos, steering)
        local totalDist = (pos - target).Magnitude

        if totalDist <= CFG.reach and hum.FloorMaterial ~= Enum.Material.Air then
            DBG.phase = "done"; break
        end
        if now - startedAt > CFG.maxRunTime then
            DBG.phase = "timeout"; break
        end

        if not crossed and (pos.Z <= CFG.preJumpZ + CFG.dashDistance or pos.Z <= TRIP_Z
            or (prevZ > CFG.preJumpZ + CFG.dashDistance and pos.Z <= CFG.preJumpZ + CFG.dashDistance + 2)) then
            crossed = true; jumpBurst = 0; nextBurstJump = 0
        end
        if not stopJumping and pos.Z <= STOP_JUMP_Z then stopJumping = true end
        prevZ = pos.Z

        local burstDone = jumpBurst >= CFG.burstJumps
        local phase = getPhase(pos, target, hdist, crossed, stopJumping, burstDone, startedAt)
        DBG.phase = phase

        aimCam(pos, dir)
        if phase == "walkin" then
            releaseForward()
            hum:MoveTo(target)
        else
            faceDirection(pos, dir)
            holdForward()
            hum:Move(dir, false)
        end

        local grounded = hum.FloorMaterial ~= Enum.Material.Air

        local canDash, dashReason = false, nil
        if phase == "approach" then
            local distToJump = math.max(0, pos.Z - CFG.preJumpZ)
            canDash = distToJump > CFG.dashDistance and hdist > CFG.dashMinFlatDistance
            dashReason = "approach"
        elseif crossed and burstDone and not stopJumping and phase ~= "walkin" and pos.Y >= CFG.climbTop then
            canDash = hdist > CFG.dashMinFlatDistance
            dashReason = "cruise"
        elseif stopJumping and not postWallDashDone and grounded then
            canDash = hdist > math.max(CFG.walkInDistance, CFG.reach + 8)
            dashReason = "postwall"
        end

        if canDash and now >= nextDashAt then
            faceDirection(pos, dir)
            holdForward()
            dash(dashReason)
            lastDash = now
            nextDashAt = now + CFG.dashCooldown + randBetween(-CFG.dashCooldownJitter, CFG.dashCooldownJitter)
            if dashReason == "postwall" then
                postWallDashDone = true
                task.delay(0.18, function() if running then releaseForward() end end)
            end
        end

        if not stopJumping and crossed and jumpBurst < CFG.burstJumps then
            if now >= nextBurstJump then
                jump("burst" .. (jumpBurst + 1))
                jumpBurst += 1; lastJump = now; nextBurstJump = now + CFG.burstJumpInterval
            end
        elseif not stopJumping and crossed and phase ~= "walkin" and pos.Y < CFG.climbTop and now - lastJump >= CFG.jumpCooldown then
            jump("spam"); lastJump = now
        elseif not stopJumping and phase == "cruise" and pos.Y < CFG.cruiseFloor and now - lastJump >= CFG.jumpCooldown then
            jump("hover"); lastJump = now
        end

        if now - lastCheck >= CFG.stuckCheck then
            local moved = (pos - lastProgress).Magnitude
            if now - startedAt > 1.2 and moved < CFG.stuckMove and hdist > CFG.walkInDistance then
                stuckCount += 1
                DBG.phase = "unstick"
                if crossed and not stopJumping and now - lastJump >= CFG.jumpCooldown then
                    jump("unstick"); lastJump = now
                end
                local nudge = (dir + Vector3.new(dir.Z, 0, -dir.X) * ((stuckCount % 2 == 0) and 0.45 or -0.45)).Unit
                hum:Move(nudge, false)
                if stuckCount >= CFG.stuckLimit then DBG.phase = "stuck"; break end
            else
                stuckCount = 0
            end
            lastProgress = pos; lastCheck = now
        end

        record(pos, phase, hdist)
    end

    releaseAllKeys()
    if cam then
        cam.CameraSubject = hum
        cam.CameraType = Enum.CameraType.Custom
    end
    if hum then hum.AutoRotate = (oldAutoRotate ~= nil) and oldAutoRotate or true end
end

local function walkTo(target, label)
    refreshCharacter()
    setMoveTarget(label or "walk", target, Color3.fromRGB(255, 255, 80))
    if oldAutoRotate == nil then oldAutoRotate = hum.AutoRotate end
    hum.AutoRotate = true

    local startedAt    = tick()
    local lastCheck    = tick()
    local lastProgress = hrp.Position
    local stuckCount   = 0

    while running do
        RunService.Heartbeat:Wait()
        if not char or not char.Parent or not hum or hum.Health <= 0 or not hrp or not hrp.Parent then
            refreshCharacter()
            lastProgress = hrp.Position
        end

        local now = tick()
        local pos = hrp.Position
        local _, hdist = flatDir(pos, target)
        local totalDist = (pos - target).Magnitude
        DBG.phase = "walk"

        if totalDist <= CFG.reach and hum.FloorMaterial ~= Enum.Material.Air then DBG.phase = "done"; break end
        if now - startedAt > CFG.maxRunTime then DBG.phase = "timeout"; break end

        hum:MoveTo(target)

        if now - lastCheck >= CFG.stuckCheck then
            local moved = (pos - lastProgress).Magnitude
            if moved < CFG.stuckMove and hdist > CFG.walkInDistance then
                stuckCount += 1
                DBG.phase = "walk_unstick"
                if stuckCount >= CFG.stuckLimit then DBG.phase = "stuck"; break end
            else
                stuckCount = 0
            end
            lastProgress = pos; lastCheck = now
        end

        record(pos, DBG.phase, hdist)
    end
end

local function runRoute(points)
    for i, point in ipairs(points) do
        if not running then break end
        DBG.segment = i
        refreshCharacter()
        local useParkour = (i == 1) and hrp.Position.Y < 225 and hrp.Position.Z > STOP_JUMP_Z
        if useParkour then parkourTo(point) else walkTo(point) end
        if DBG.phase == "timeout" or DBG.phase == "stuck" then break end
    end
end

local function shortPad(pad)
    return pad.name:gsub("DUNGEON_TELEPORTER", "Pad ")
end

local function pickTarget(state, committed)
    local forced = getgenv().ParkourPad or getgenv().ForceParkourPad
    local forcedPad = forced and findPadById(forced)
    if forcedPad then return forcedPad end

    if committed and padRandomCount(committed) == 0 then return committed end

    local pad3 = PADS[1]
    if padRandomCount(pad3) == 0 then
        state.blockedSince = nil
        return pad3
    end

    state.blockedSince = state.blockedSince or tick()
    if tick() - state.blockedSince >= CFG.padWaitSecs then
        for i = 2, #PADS do
            if padRandomCount(PADS[i]) == 0 then return PADS[i] end
        end
    end
end

local function routeToFront(pad)
    for _, point in ipairs(pad.transit or {}) do
        if not running then return false end
        walkTo(point, "transit")
    end
    if not running then return false end
    walkTo(frontPoint(pad), "front")
    if not running then return false end

    local verifyUntil = tick() + CFG.padVerifySecs
    while running and tick() < verifyUntil do
        DBG.coord = "verify_" .. shortPad(pad)
        if padAnyCount(pad) > 0 then return "busy" end
        task.wait(CFG.padPoll)
    end
    return running
end

local function startDungeonIfReady(pad)
    local total = totalAllowed()
    local ours = (#ALLOWED_ACCOUNTS == 0) and (meOnPad(pad) and 1 or 0) or allowedOnPadCount(pad)
    DBG.coord = string.format("%s %d/%d", shortPad(pad), ours, total)
    if ours < total or not onlyAllowedOnPad(pad) then return false end
    if not CFG.startDungeon then DBG.coord = "ready_no_start"; return false end

    local obj = getPadObject(pad)
    local remote = obj and obj:FindFirstChild("DungeonSettingsChanged")
    if not remote then DBG.coord = "ready_no_remote"; return true end

    task.wait(2)
    remote:FireServer("Difficulty", getgenv().ParkourDifficulty or "Easy")
    task.wait(1)
    remote:FireServer("Start")
    DBG.coord = "started"
    return true
end

local function runPadCoordinator(stagePad)
    if not CFG.multiPad then return end

    local total = totalAllowed()
    local state, committed = {}, nil
    local stagePadRef = stagePad or PADS[1]
    local stagePoint = stagePadRef.walkOn
    local busySince = {}

    DBG.coord = "staging"
    while running and accsNear(stagePoint, 55) < total do
        task.wait(CFG.padPoll)
    end

    while running do
        local target = pickTarget(state, committed)
        DBG.pad = target and target.name or DBG.pad
        if not target then
            DBG.coord = "wait_free_pad"
            task.wait(CFG.padPoll)
            continue
        end
        committed = target

        if padAnyCount(target) > 0 then
            busySince[target.name] = busySince[target.name] or tick()
            DBG.coord = "wait_empty_" .. shortPad(target)
            if tick() - busySince[target.name] >= CFG.padWaitSecs then committed = nil end
            task.wait(CFG.padPoll)
            continue
        end
        busySince[target.name] = nil

        DBG.coord = "front_" .. shortPad(target)
        local frontResult = routeToFront(target)
        if frontResult == "busy" or padAnyCount(target) > 0 then
            busySince[target.name] = busySince[target.name] or tick()
            DBG.coord = "repick_busy"
            if tick() - busySince[target.name] >= CFG.padWaitSecs then committed = nil end
            task.wait(CFG.padPoll)
            continue
        end
        if not frontResult then return end
        busySince[target.name] = nil

        DBG.coord = "step_" .. shortPad(target)
        walkTo(target.walkOn, "pad")
        if not running then return end

        while running do
            if padRandomCount(target) > 0 then
                busySince[target.name] = busySince[target.name] or tick()
                DBG.coord = "bail_" .. shortPad(target)

                local exit = bailPoint(target)
                table.insert(DBG.bails, string.format("%s -> %d,%d,%d",
                    target.name, exit.X, exit.Y, exit.Z))
                walkTo(exit, "exit")

                while running and padRandomCount(target) > 0 do
                    DBG.coord = "wait_clear_" .. shortPad(target)
                    if tick() - busySince[target.name] >= CFG.padWaitSecs then committed = nil; break end
                    task.wait(CFG.padPoll)
                end
                if not committed then break end
                busySince[target.name] = nil

                if padAnyCount(target) == 0 then
                    DBG.coord = "return_" .. shortPad(target)
                    walkTo(target.walkOn, "return")
                end
            end

            if startDungeonIfReady(target) then running = false; return end
            if not meOnPad(target) then walkTo(target.walkOn, "pad") end
            task.wait(CFG.padPoll)
        end
    end
end
local TARGET_PAD = (function()
    local forced = getgenv().ParkourPad or getgenv().ForceParkourPad
    return (forced and findPadById(forced)) or PADS[1]
end)()

local TARGET = getgenv().ParkourTarget or approachPoint(TARGET_PAD)
DBG.pad, DBG.target = TARGET_PAD.name, TARGET

local route = buildRouteForPad(TARGET_PAD)

buildPadVisuals()
buildRouteVisuals(route, TARGET)
buildHud()
startVisualLoop()

task.spawn(function()
    refreshCharacter()
    print("[PK] pad " .. tostring(DBG.pad) .. " target " .. tostring(TARGET))
    print("[PK] start " .. tostring(hrp.Position))

    runRoute(route)
    if running and CFG.multiPad then
        runPadCoordinator(PADS[1])
    end

    cleanup()
    print("[PK] end " .. tostring(hrp and hrp.Position) .. " state " .. tostring(DBG.phase))
    DBG.done = true
    getgenv().__pdone = true
end)
