local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local VIM        = game:GetService("VirtualInputManager")

local cfg = getgenv().DungeonBotConfig or {}
local ALLOWED_ACCOUNTS = cfg.allowedAccounts or {
    "1",
    "2",
    "3",
    "4",
}
local NEAR_RADIUS   = cfg.nearRadius  or 50
local REACH_DIST    = cfg.reachDist   or 5
local PAD_WAIT_SECS = cfg.padWaitSecs or 20
local STUCK_CHECK   = cfg.stuckCheck  or 1
local STUCK_LIMIT   = cfg.stuckLimit  or 3
local STUCK_MOVE    = cfg.stuckMove   or 2

-- humanization tunables (used by plain walkTo for bail / final approach)
local DEVIATE_MAX = cfg.deviateMax or 4
local LOOKAHEAD   = cfg.lookahead  or 4.5

local TEST_MODE = cfg.testMode or false
local FORCE_PAD = cfg.forcePad

-- parkour movement tunables
local PK = {
    reach               = 4,
    walkInDistance      = 18,
    warmup              = 0.75,
    pathJitter          = 2,
    pathJitterFade      = 75,
    dashCooldown        = 0.28,
    dashCooldownJitter  = 0.04,
    dashDistance        = 37,
    dashHold            = 0.035,
    dashMinFlatDistance = 49,
    jumpCooldown        = 0.075,
    jumpHold            = 0.055,
    burstJumps          = 3,
    burstJumpInterval   = 0.18,
    preJumpZ            = -135,
    climbTop            = 260,
    cruiseFloor         = 252,
    finalFloorY         = 233,
    finalPlatformDistance = 24,
    obstacleBypassZ     = -336,
    obstacleRightX      = -215,
    obstacleLeftX       = -500,
    obstaclePad         = 10,
    maxRunTime          = 35,
    stuckCheck          = 0.55,
    stuckMove           = 2.5,
    stuckLimit          = 5,
}

local TRIP_Z       = -172
local STOP_JUMP_Z  = -318
local OBSTACLE_BOX = { minX=-393, maxX=-305, minZ=-357, maxZ=-246 }

local player = Players.LocalPlayer
local character, humanoid, hrp
local oldAutoRotate = nil

local function refreshCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid  = character:WaitForChild("Humanoid")
    hrp       = character:WaitForChild("HumanoidRootPart")
end
refreshCharacter()
player.CharacterAdded:Connect(refreshCharacter)

-- ── GUI ──────────────────────────────────────────────────────────────────────

for _, old in ipairs(player.PlayerGui:GetChildren()) do
    if old.Name == "DungeonBotGui" then old:Destroy() end
end

local W, PAD = 245, 10
local sg = Instance.new("ScreenGui")
sg.Name = "DungeonBotGui"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = player.PlayerGui

local win = Instance.new("Frame", sg)
win.Size = UDim2.new(0, W, 0, 370); win.Position = UDim2.new(0, 20, 0, 20)
win.BackgroundColor3 = Color3.fromRGB(11, 11, 16); win.BorderSizePixel = 0
win.Active = true; win.Draggable = true
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 9)
local winStroke = Instance.new("UIStroke", win)
winStroke.Color = Color3.fromRGB(70, 40, 160); winStroke.Thickness = 1.5

local titleBar = Instance.new("Frame", win)
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 15, 90); titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 9)
local tpatch = Instance.new("Frame", titleBar)
tpatch.Size = UDim2.new(1, 0, 0, 9); tpatch.Position = UDim2.new(0, 0, 1, -9)
tpatch.BackgroundColor3 = Color3.fromRGB(35, 15, 90); tpatch.BorderSizePixel = 0
local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -10, 1, 0); titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "DungeonBot"
titleLbl.TextColor3 = Color3.fromRGB(180, 150, 255); titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 12; titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local nextY = 34
local function sectionHeader(text)
    local lbl = Instance.new("TextLabel", win)
    lbl.Size = UDim2.new(1, -PAD*2, 0, 14); lbl.Position = UDim2.new(0, PAD, 0, nextY)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(100, 80, 180); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left
    nextY += 16
end

local function makeRow(label)
    local row = Instance.new("Frame", win)
    row.Size = UDim2.new(1, -PAD*2, 0, 15); row.Position = UDim2.new(0, PAD, 0, nextY)
    row.BackgroundTransparency = 1
    local k = Instance.new("TextLabel", row)
    k.Size = UDim2.new(0.44, 0, 1, 0); k.BackgroundTransparency = 1; k.Text = label
    k.TextColor3 = Color3.fromRGB(100, 100, 140); k.Font = Enum.Font.Gotham
    k.TextSize = 11; k.TextXAlignment = Enum.TextXAlignment.Left
    local v = Instance.new("TextLabel", row)
    v.Size = UDim2.new(0.56, 0, 1, 0); v.Position = UDim2.new(0.44, 0, 0, 0)
    v.BackgroundTransparency = 1; v.Text = "—"
    v.TextColor3 = Color3.fromRGB(215, 215, 255); v.Font = Enum.Font.GothamBold
    v.TextSize = 11; v.TextXAlignment = Enum.TextXAlignment.Left
    nextY += 17
    return v
end

local function divider()
    local d = Instance.new("Frame", win)
    d.Size = UDim2.new(1, -PAD*2, 0, 1); d.Position = UDim2.new(0, PAD, 0, nextY + 3)
    d.BackgroundColor3 = Color3.fromRGB(40, 30, 70); d.BorderSizePixel = 0
    nextY += 10
end

sectionHeader("PATH WALK")
local guiPath     = makeRow("Path")
local guiPWStatus = makeRow("Status")
local guiWaypoint = makeRow("Waypoint")
nextY += 2

local runBtn = Instance.new("TextButton", win)
runBtn.Size = UDim2.new(1, -PAD*2, 0, 22); runBtn.Position = UDim2.new(0, PAD, 0, nextY)
runBtn.BackgroundColor3 = Color3.fromRGB(35, 70, 180); runBtn.Text = "Run"
runBtn.TextColor3 = Color3.new(1,1,1); runBtn.Font = Enum.Font.GothamBold
runBtn.TextSize = 12; runBtn.BorderSizePixel = 0
Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 5)
nextY += 28

divider()
sectionHeader("PAD COORD")
local guiCoordStatus = makeRow("Status")
local guiNearby      = makeRow("Nearby")
local guiOnPad       = makeRow("On Pad")
local guiRandom      = makeRow("Randoms")
divider()

nextY += 2
local logBg = Instance.new("Frame", win)
logBg.Size = UDim2.new(1, -PAD*2, 0, 94); logBg.Position = UDim2.new(0, PAD, 0, nextY)
logBg.BackgroundColor3 = Color3.fromRGB(5, 5, 8); logBg.BorderSizePixel = 0
Instance.new("UICorner", logBg).CornerRadius = UDim.new(0, 4)

local logLbl = Instance.new("TextLabel", logBg)
logLbl.Size = UDim2.new(1, -6, 1, -4); logLbl.Position = UDim2.new(0, 3, 0, 2)
logLbl.BackgroundTransparency = 1; logLbl.Text = ""
logLbl.TextColor3 = Color3.fromRGB(130, 195, 130); logLbl.Font = Enum.Font.Code
logLbl.TextSize = 10; logLbl.TextXAlignment = Enum.TextXAlignment.Left
logLbl.TextYAlignment = Enum.TextYAlignment.Top; logLbl.TextWrapped = true

win.Size = UDim2.new(0, W, 0, nextY + 100)

local logLines = {}
local function log(msg)
    print("[DungeonBot] " .. msg)
    table.insert(logLines, msg)
    if #logLines > 8 then table.remove(logLines, 1) end
    logLbl.Text = table.concat(logLines, "\n")
end

local function setPWStatus(text, color)
    guiPWStatus.Text = text
    guiPWStatus.TextColor3 = color or Color3.fromRGB(215, 215, 255)
end

local function setCoordStatus(text, color)
    guiCoordStatus.Text = text
    guiCoordStatus.TextColor3 = color or Color3.fromRGB(215, 215, 255)
end

-- ── pad detection ────────────────────────────────────────────────────────────

local pads = {
    { path = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER1.Pad, name = "DUNGEON_TELEPORTER1" },
    { path = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER2.Pad, name = "DUNGEON_TELEPORTER2" },
    { path = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER3.Pad, name = "DUNGEON_TELEPORTER3" },
}

local HEIGHT_VIS     = 20
local VISUALIZER_TAG = "PadVisualizer_"

for _, padInfo in ipairs(pads) do
    local old = workspace:FindFirstChild(VISUALIZER_TAG .. padInfo.name)
    if old then old:Destroy() end
end

local allPlayersInside  = {}
local allPlayersNearby  = {}

local function getNearbyCount(padName)
    local nearby, count = allPlayersNearby[padName] or {}, 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do if nearby[name] then count += 1 end end
    return count
end

local function getOnPadCount(padName)
    local inside, count = allPlayersInside[padName] or {}, 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do if inside[name] then count += 1 end end
    return count
end

local function onlyOursOnPad(padName)
    for name in pairs(allPlayersInside[padName] or {}) do
        if not table.find(ALLOWED_ACCOUNTS, name) then return false end
    end
    return true
end

local function padRandomCount(padName)
    local n = 0
    for name in pairs(allPlayersInside[padName] or {}) do
        if not table.find(ALLOWED_ACCOUNTS, name) then n += 1 end
    end
    return n
end

local function meOnPad(padName)
    return (allPlayersInside[padName] or {})[player.Name] == true
end

local padColors = {
    DUNGEON_TELEPORTER1 = Color3.fromRGB(0, 255, 255),
    DUNGEON_TELEPORTER2 = Color3.fromRGB(255, 100, 0),
    DUNGEON_TELEPORTER3 = Color3.fromRGB(100, 255, 0),
}

for _, padInfo in ipairs(pads) do
    local pad = padInfo.path
    local tag = VISUALIZER_TAG .. padInfo.name
    local box = Instance.new("Part")
    box.Name = tag; box.Anchored = true; box.CanCollide = false; box.CanTouch = false
    box.Transparency = 0.6; box.Material = Enum.Material.Neon; box.CastShadow = false
    box.Size = Vector3.new(pad.Size.X, HEIGHT_VIS, pad.Size.Z)
    box.CFrame = CFrame.new(pad.Position + Vector3.new(0, HEIGHT_VIS/2 - pad.Size.Y/2, 0))
    box.Color = padColors[padInfo.name] or Color3.fromRGB(255,255,255)
    box.Parent = workspace
    local sel = Instance.new("SelectionBox")
    sel.Adornee = box; sel.Color3 = box.Color; sel.LineThickness = 0.05
    sel.SurfaceTransparency = 1; sel.Parent = workspace

    local playersInside, playersNearby = {}, {}
    allPlayersInside[padInfo.name] = playersInside
    allPlayersNearby[padInfo.name] = playersNearby
    local padCenter = pad.Position

    local function isInsideBox(pos)
        local lp_ = box.CFrame:PointToObjectSpace(pos)
        local h = box.Size / 2
        return math.abs(lp_.X) <= h.X and math.abs(lp_.Y) <= h.Y and math.abs(lp_.Z) <= h.Z
    end

    local function isNearPad(pos)
        return (Vector3.new(pos.X, padCenter.Y, pos.Z) - padCenter).Magnitude <= NEAR_RADIUS
    end

    RunService.Heartbeat:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if not root then playersInside[p.Name] = nil; playersNearby[p.Name] = nil; continue end
            local inside = isInsideBox(root.Position)
            if inside and not playersInside[p.Name] then
                playersInside[p.Name] = true
                print(("[%s] %s ENTERED"):format(padInfo.name, p.Name))
            elseif not inside and playersInside[p.Name] then
                playersInside[p.Name] = nil
                print(("[%s] %s LEFT"):format(padInfo.name, p.Name))
            end
            local near = isNearPad(root.Position)
            if near and not playersNearby[p.Name] then playersNearby[p.Name] = true
            elseif not near and playersNearby[p.Name] then playersNearby[p.Name] = nil end
        end
    end)
end

log("Pad detection active.")

-- ── paths ────────────────────────────────────────────────────────────────────

-- (legacy walking paths removed — movement now uses the parkour route in runPipeline)

local visFolder = nil

local function clearVisualizer()
    if visFolder then visFolder:Destroy(); visFolder = nil end
end

local running = false

-- ── math helpers ─────────────────────────────────────────────────────────────

local function rand(a, b) return a + math.random()*(b-a) end

local function flatDist(a, b)
    return (Vector3.new(a.X,0,a.Z) - Vector3.new(b.X,0,b.Z)).Magnitude
end

local function flatDir(a, b)
    local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
    local m = d.Magnitude
    if m < 1e-4 then return Vector3.new(0, 0, 0), 0 end
    return d / m, m
end

-- ── plain walkTo (used for bail / short final approach) ──────────────────────

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function pathClear(origin, dir, dist)
    rayParams.FilterDescendantsInstances = { character }
    local res = workspace:Raycast(origin, dir * dist, rayParams)
    if res and res.Instance and res.Instance.CanCollide then return false end
    return true
end

local function walkTo(target)
    local stuckCount, lastPos, lastCheck = 0, hrp.Position, tick()
    local devSign = (math.random() < 0.5) and 1 or -1
    while running do
        RunService.Heartbeat:Wait()
        local pos = hrp.Position
        if (pos - target).Magnitude <= REACH_DIST then break end
        local dir = flatDir(pos, target)
        if not pathClear(pos, dir, LOOKAHEAD) then humanoid.Jump = true end
        humanoid:MoveTo(target)
        local now = tick()
        if now - lastCheck >= STUCK_CHECK then
            local moved = (pos - lastPos).Magnitude
            if moved < STUCK_MOVE then
                stuckCount += 1
                setPWStatus("Stuck " .. stuckCount .. "/" .. STUCK_LIMIT, Color3.fromRGB(255, 160, 40))
                humanoid.Jump = true
                local right = Vector3.new(dir.Z, 0, -dir.X)
                humanoid:MoveTo(pos + right * devSign * 6)
                task.wait(0.3)
                devSign = -devSign
                if stuckCount >= STUCK_LIMIT then log("Stuck — skipping waypoint"); break end
            else
                stuckCount = 0
            end
            lastPos = hrp.Position; lastCheck = tick()
        end
    end
end

-- ── VIM helpers ───────────────────────────────────────────────────────────────

local HELD = {}
local function holdKey(k)
    if HELD[k] then return end; HELD[k]=true; VIM:SendKeyEvent(true,k,false,game)
end
local function releaseKey(k)
    if not HELD[k] then return end; HELD[k]=nil; VIM:SendKeyEvent(false,k,false,game)
end
local function pulseKey(k, hold)
    task.spawn(function()
        VIM:SendKeyEvent(true,k,false,game); task.wait(hold); VIM:SendKeyEvent(false,k,false,game)
    end)
end
local function holdFwd()
    holdKey(Enum.KeyCode.W); releaseKey(Enum.KeyCode.A); releaseKey(Enum.KeyCode.D)
end
local function releaseFwd()
    releaseKey(Enum.KeyCode.W); releaseKey(Enum.KeyCode.A); releaseKey(Enum.KeyCode.D)
end
local function releaseAll()
    if humanoid then humanoid:Move(Vector3.new(0,0,0), false) end
    for _, k in ipairs({Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D}) do releaseKey(k) end
    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.Q,     false, game)
end
local function pkDash()   pulseKey(Enum.KeyCode.Q,     PK.dashHold) end
local function pkJump()
    if humanoid then humanoid.Jump = true end
    pulseKey(Enum.KeyCode.Space, PK.jumpHold)
end

local cam = workspace.CurrentCamera
local function aimCam(pos, dir)
    if not cam or dir.Magnitude < 0.05 then return end
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 0.05 then return end
    flat = flat.Unit
    cam.CFrame = CFrame.lookAt(pos - flat*22 + Vector3.new(0,12,0), pos + flat*9)
end
local function facedir(pos, dir)
    if not hrp or dir.Magnitude < 0.05 then return end
    hrp.CFrame = CFrame.lookAt(pos, pos + dir)
end

-- ── obstacle bypass helpers ───────────────────────────────────────────────────

local RUN_BIAS = Vector3.new(rand(-2,2), 0, ((math.random()<0.5) and -1 or 1)*rand(3, PK.pathJitter))

local function biasTarget(t, hdist)
    return t + RUN_BIAS * math.clamp(hdist/PK.pathJitterFade, 0, 1)
end
local function insideObs(p)
    local pad = PK.obstaclePad
    return p.X>=OBSTACLE_BOX.minX-pad and p.X<=OBSTACLE_BOX.maxX+pad
       and p.Z>=OBSTACLE_BOX.minZ-pad and p.Z<=OBSTACLE_BOX.maxZ+pad
end
local function segEntersObs(a, b)
    for i=0,18 do if insideObs(a:Lerp(b,i/18)) then return true end end
end
local function bypassObs(pos, target)
    if not segEntersObs(pos, target) then return target end
    local midX = (OBSTACLE_BOX.minX+OBSTACLE_BOX.maxX)*0.5
    local bx = (target.X < midX) and PK.obstacleLeftX or PK.obstacleRightX
    return Vector3.new(bx+rand(-3,3), target.Y, PK.obstacleBypassZ+rand(-2,2))
end
local function onFinalPlatform(pos, target, hdist)
    if not humanoid or humanoid.FloorMaterial==Enum.Material.Air then return false end
    return pos.Y>=PK.finalFloorY and hdist<=PK.finalPlatformDistance and pos.Z<=target.Z+35
end
local function getPhase(pos, target, hdist, crossed, stopJump, burstDone, t0)
    if tick()-t0 < PK.warmup then return "warmup" end
    if stopJump or onFinalPlatform(pos,target,hdist) then return "walkin" end
    if not crossed then return "approach" end
    if not burstDone then return "burst" end
    if pos.Y < PK.climbTop then return "climb" end
    return "cruise"
end

-- ── parkourTo — VIM key movement used for path waypoints ─────────────────────

local function parkourTo(target)
    refreshCharacter()
    if oldAutoRotate == nil then oldAutoRotate = humanoid.AutoRotate end
    humanoid.AutoRotate = false
    if cam then cam.CameraSubject=humanoid; cam.CameraType=Enum.CameraType.Scriptable end

    local t0=tick(); local nextDash=0; local lastJump=0
    local lastCheck=tick(); local lastProg=hrp.Position; local stuckCount=0
    local crossed  = hrp.Position.Z <= TRIP_Z
    local stopJump = hrp.Position.Z <= STOP_JUMP_Z
    local burst=0; local nextBurst=0
    local postWallDone = stopJump

    while running do
        RunService.Heartbeat:Wait()
        if not character or not character.Parent or not humanoid
        or humanoid.Health<=0 or not hrp or not hrp.Parent then
            refreshCharacter(); lastProg=hrp.Position
        end
        local now=tick(); local pos=hrp.Position
        local base     = bypassObs(pos, target)
        local steering = biasTarget(base, flatDist(pos, base))
        local dir, hdist = flatDir(pos, steering)

        if (pos-target).Magnitude<=PK.reach and humanoid.FloorMaterial~=Enum.Material.Air then break end
        if now-t0 > PK.maxRunTime then break end

        if not crossed  and pos.Z <= TRIP_Z      then crossed=true; burst=0; nextBurst=0 end
        if not stopJump and pos.Z <= STOP_JUMP_Z then stopJump=true end

        local burstDone = burst >= PK.burstJumps
        local phase = getPhase(pos, target, hdist, crossed, stopJump, burstDone, t0)
        aimCam(pos, dir)
        if phase == "walkin" then
            releaseFwd(); humanoid:MoveTo(target)
        else
            facedir(pos, dir); holdFwd(); humanoid:Move(dir, false)
        end

        local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
        local canDash, reason = false, nil
        if phase == "approach" then
            canDash = math.max(0, pos.Z-PK.preJumpZ) > PK.dashDistance and hdist > PK.dashMinFlatDistance
            reason  = "approach"
        elseif crossed and burstDone and not stopJump and phase~="walkin" and pos.Y>=PK.climbTop then
            canDash = hdist > PK.dashMinFlatDistance; reason = "cruise"
        elseif stopJump and not postWallDone and grounded then
            canDash = hdist > math.max(PK.walkInDistance, PK.reach+8); reason = "postwall"
        end
        if canDash and now >= nextDash then
            facedir(pos, dir); holdFwd(); pkDash()
            nextDash = now + PK.dashCooldown + rand(-PK.dashCooldownJitter, PK.dashCooldownJitter)
            if reason == "postwall" then
                postWallDone = true
                task.delay(0.18, function() if running then releaseFwd() end end)
            end
        end

        if not stopJump and crossed and burst < PK.burstJumps then
            if now >= nextBurst then pkJump(); burst+=1; lastJump=now; nextBurst=now+PK.burstJumpInterval end
        elseif not stopJump and crossed and phase~="walkin" and pos.Y<PK.climbTop and now-lastJump>=PK.jumpCooldown then
            pkJump(); lastJump=now
        elseif not stopJump and phase=="cruise" and pos.Y<PK.cruiseFloor and now-lastJump>=PK.jumpCooldown then
            pkJump(); lastJump=now
        end

        if now - lastCheck >= PK.stuckCheck then
            local moved = (pos-lastProg).Magnitude
            if now-t0>1.2 and moved<PK.stuckMove and hdist>PK.walkInDistance then
                stuckCount += 1
                if crossed and not stopJump and now-lastJump>=PK.jumpCooldown then pkJump(); lastJump=now end
                local nudge = (dir + Vector3.new(dir.Z,0,-dir.X)*((stuckCount%2==0) and 0.45 or -0.45)).Unit
                humanoid:Move(nudge, false)
                if stuckCount >= PK.stuckLimit then break end
            else stuckCount=0 end
            lastProg=pos; lastCheck=now
        end
    end

    releaseAll()
    if cam then cam.CameraSubject=humanoid; cam.CameraType=Enum.CameraType.Custom end
    if humanoid then humanoid.AutoRotate = (oldAutoRotate~=nil) and oldAutoRotate or true end
end

-- ── pad configs (used for coordination after path walk) ──────────────────────

local PAD_CONFIGS = {
    {
        name = "DUNGEON_TELEPORTER3",
        object = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER3,
        transit = {},
        walkOnPositions = {
            Vector3.new(-487, 237, -433),
        },
        bailPositions = {
            Vector3.new(-508.626709, 235.646713, -436.346497),
            Vector3.new(-515.421509, 235.646713, -434.579803),
            Vector3.new(-513.527405, 235.646713, -427.260162),
            Vector3.new(-516.881897, 235.646713, -423.513794),
            Vector3.new(-508.32373,  234.985916, -417.227325),
            Vector3.new(-512.829712, 234.987854, -414.454559),
            Vector3.new(-504.258636, 234.987854, -408.89621),
            Vector3.new(-505.871063, 234.987854, -415.172638),
            Vector3.new(-496.08252,  234.987854, -408.193054),
            Vector3.new(-498.434662, 234.987854, -417.346832),
            Vector3.new(-487.969696, 234.987854, -408.203339),
            Vector3.new(-486.289429, 234.987854, -401.665558),
            Vector3.new(-478.182281, 234.987854, -403.749207),
            Vector3.new(-481.925354, 234.987854, -418.313873),
            Vector3.new(-471.26949,  234.987854, -412.446503),
            Vector3.new(-464.47052,  234.987854, -414.19397),
            Vector3.new(-466.859894, 235.611801, -423.49173),
            Vector3.new(-458.496063, 235.646713, -425.633789),
            Vector3.new(-461.79422,  235.646713, -438.543457),
            Vector3.new(-467.256989, 235.646713, -439.43158),
            Vector3.new(-466.055939, 235.646713, -451.793457),
            Vector3.new(-458.946136, 235.646713, -438.547516),
        },
    },
    {
        name = "DUNGEON_TELEPORTER2",
        object = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER2,
        transit = {
            CFrame.new(-423.566925, 235.028915, -387.250397, 0.0170264486, 1.28300828e-08, -0.999855042, -1.71209236e-09, 1, 1.28027882e-08, 0.999855042, 1.49385815e-09, 0.0170264486).Position,
        },
        walkOnPositions = {
            CFrame.new(-360.964539, 236.566925, -447.52771, 0.999974191, -4.3008999e-08, -0.00718283793, 4.25918856e-08, 1, -5.82239181e-08, 0.00718283793, 5.79164841e-08, 0.999974191).Position,
        },
        bailPositions = {
            CFrame.new(-374.713837, 235.687744, -457.07135, 0.995771885, 1.79865722e-08, -0.0918602124, -1.99938199e-08, 1, -2.09308428e-08, 0.0918602124, 2.26789822e-08, 0.995771885).Position,
            CFrame.new(-379.594849, 235.687744, -452.572937, 0.996111572, 4.86530958e-08, -0.0881008506, -5.36876321e-08, 1, -5.47755903e-08, 0.0881008506, 5.92925247e-08, 0.996111572).Position,
            CFrame.new(-373.997559, 235.687744, -452.07605, 0.996194243, 7.354791e-09, -0.0871608853, -8.10329936e-09, 1, -8.23384383e-09, 0.0871608853, 8.90879814e-09, 0.996194243).Position,
            CFrame.new(-380.471252, 235.687744, -446.629486, 0.995684743, -4.79703814e-08, -0.092800349, 5.31835482e-08, 1, 5.37030651e-08, 0.092800349, -5.84067728e-08, 0.995684743).Position,
            CFrame.new(-385.676117, 235.687744, -442.495453, 0.995508015, 7.88013708e-08, -0.0946772322, -8.7520462e-08, 1, -8.7940407e-08, 0.0946772322, 9.58315738e-08, 0.995508015).Position,
            CFrame.new(-379.637573, 235.687744, -437.749908, 0.995508015, 6.86479851e-08, -0.0946772322, -7.62476589e-08, 1, -7.66517019e-08, 0.0946772322, 8.35262952e-08, 0.995508015).Position,
            CFrame.new(-374.394958, 235.687744, -442.4729, 0.995508015, 6.7559732e-08, -0.0946772322, -7.50394307e-08, 1, -7.54418323e-08, 0.0946772322, 8.22074711e-08, 0.995508015).Position,
            CFrame.new(-375.385162, 235.687744, -432.261353, 0.995328069, -3.55462468e-08, -0.0965506062, 3.95741537e-08, 1, 3.98031936e-08, 0.0965506062, -4.34381455e-08, 0.995328069).Position,
            CFrame.new(-368.668884, 235.687744, -431.596466, 0.995144367, -4.20148076e-08, -0.0984260514, 4.68702126e-08, 1, 4.70182364e-08, 0.0984260514, -5.14031839e-08, 0.995144367).Position,
            CFrame.new(-372.615509, 235.687744, -423.128296, 0.994956791, 5.57439712e-08, -0.100304484, -6.23037835e-08, 1, -6.22664373e-08, 0.100304484, 6.82017642e-08, 0.994956791).Position,
            CFrame.new(-366.895905, 235.687744, -422.551666, 0.994956851, -2.60399133e-08, -0.100303896, 2.91044309e-08, 1, 2.90890068e-08, 0.100303896, -3.18615925e-08, 0.994956851).Position,
            CFrame.new(-361.603973, 235.687744, -432.761902, 0.994956851, 9.49168744e-09, -0.100303896, -1.0608721e-08, 1, -1.06030988e-08, 0.100303896, 1.16137224e-08, 0.994956851).Position,
            CFrame.new(-354.045685, 235.687744, -432.653931, 0.994956851, 1.78882793e-08, -0.100303896, -1.99934647e-08, 1, -1.99828296e-08, 0.100303896, 2.18874749e-08, 0.994956851).Position,
            CFrame.new(-344.701538, 235.687744, -432.833923, 0.994956851, -3.85717165e-08, -0.100303896, 4.31109903e-08, 1, 4.30876277e-08, 0.100303896, -4.71945292e-08, 0.994956851).Position,
            CFrame.new(-338.152374, 235.687744, -439.496582, 0.994956851, -4.58454608e-08, -0.100303896, 5.12406935e-08, 1, 5.12125524e-08, 0.100303896, -5.60939206e-08, 0.994956851).Position,
            CFrame.new(-344.324219, 235.687744, -440.118744, 0.994956851, 5.80069504e-09, -0.100303896, -6.48333476e-09, 1, -6.47973897e-09, 0.100303896, 7.09736403e-09, 0.994956851).Position,
            CFrame.new(-346.58371,  235.687744, -448.802917, 0.994956851, -4.60992062e-08, -0.100303896, 5.1524232e-08, 1, 5.14952951e-08, 0.100303896, -5.64036746e-08, 0.994956851).Position,
            CFrame.new(-346.58371,  235.687744, -448.802917, 0.99486196, -2.78157462e-08, -0.101240732, 3.11197859e-08, 1, 3.10561425e-08, 0.101240732, -3.40471651e-08, 0.99486196).Position,
            CFrame.new(-335.408722, 235.687744, -447.665527, 0.99486196, -3.22656284e-08, -0.101240732, 3.61005554e-08, 1, 3.60471581e-08, 0.101240732, -3.95167916e-08, 0.99486196).Position,
            CFrame.new(-334.315063, 235.687744, -458.409912, 0.99486196, 2.95447169e-08, -0.101240732, -3.30562244e-08, 1, -3.30071153e-08, 0.101240732, 3.61841614e-08, 0.99486196).Position,
            CFrame.new(-342.366455, 235.687744, -453.520752, 0.99486196, 2.96149612e-08, -0.101240732, -3.31347074e-08, 1, -3.30845218e-08, 0.101240732, 3.62691139e-08, 0.99486196).Position,
            CFrame.new(-345.450897, 235.687515, -455.991486, 0.99486196, 4.88422067e-08, -0.101240732, -5.46467298e-08, 1, -5.45605197e-08, 0.101240732, 5.98126633e-08, 0.99486196).Position,
        },
    },
    {
        name = "DUNGEON_TELEPORTER1",
        object = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER1,
        transit = {
            CFrame.new(-423.566925, 235.028915, -387.250397, 0.0170264486, 1.28300828e-08, -0.999855042, -1.71209236e-09, 1, 1.28027882e-08, 0.999855042, 1.49385815e-09, 0.0170264486).Position,
            CFrame.new(-294.361115, 235.028915, -387.542358, 0.0022615206, -1.18394601e-08, -0.999997437, -3.92925026e-09, 1, -1.18483765e-08, 0.999997437, 3.9560355e-09, 0.0022615206).Position,
        },
        walkOnPositions = {
            CFrame.new(-231.894653, 236.566925, -432.720825, 0.972452581, 3.80550418e-08, -0.233100772, -3.0415432e-08, 1, 3.63682986e-08, 0.233100772, -2.82765846e-08, 0.972452581).Position,
        },
        bailPositions = {
            CFrame.new(-245.790436, 235.687744, -443.823242, -0.205796242, 1.55528357e-09, -0.97859484, -3.52574894e-08, 1, 9.00387143e-09, 0.97859484, 3.63557611e-08, -0.205796242).Position,
            CFrame.new(-248.716827, 235.687744, -444.444397, -0.203948289, 4.40053149e-09, -0.978981674, -8.51294359e-08, 1, 2.22297665e-08, 0.978981674, 8.78738788e-08, -0.203948289).Position,
            CFrame.new(-249.487289, 235.687744, -437.470001, -0.0272565633, -6.70868605e-09, -0.999628484, 1.07080865e-07, 1, -9.63092095e-09, 0.999628484, -1.07303592e-07, -0.0272565633).Position,
            CFrame.new(-246.084824, 235.687744, -437.446869, -0.00369439996, -9.56867585e-10, -0.999993205, 1.63147895e-08, 1, -1.01714792e-09, 0.999993205, -1.63184364e-08, -0.00369439996).Position,
            CFrame.new(-251.402054, 235.687744, -432.076935, 0.0518860184, 2.06572537e-09, -0.998652995, -3.70953437e-08, 1, 1.41185744e-10, 0.998652995, 3.70380526e-08, 0.0518860184).Position,
            CFrame.new(-251.110397, 235.687744, -426.462738, 0.0518858992, 2.36018471e-09, -0.998652995, -5.36207807e-08, 1, -4.22546886e-10, 0.998652995, 5.35704778e-08, 0.0518858992).Position,
            CFrame.new(-250.620102, 234.9758,   -417.025757, 0.0518858992, 9.06127062e-10, -0.998652995, -2.12126974e-08, 1, -1.94775224e-10, 0.998652995, 2.11942304e-08, 0.0518858992).Position,
            CFrame.new(-251.432648, 235.028885, -411.177612, -0.170616224, 3.55933572e-09, -0.985337555, -2.42423948e-08, 1, 7.80999532e-09, 0.985337555, 2.52194532e-08, -0.170616224).Position,
            CFrame.new(-242.641754, 235.028885, -409.728943, -0.1641123, -1.59324589e-08, -0.986441672, 1.14693265e-07, 1, -3.52327305e-08, 0.986441672, -1.1892034e-07, -0.1641123).Position,
            CFrame.new(-241.62027,  235.028885, -415.847473, -0.16875878, -7.18649851e-09, -0.985657394, 4.88479515e-08, 1, -1.56545461e-08, 0.985657394, -5.07891862e-08, -0.16875878).Position,
            CFrame.new(-236.033203, 235.028885, -415.013062, -0.0724326521, -8.46986203e-10, -0.997373283, 3.61177044e-09, 1, -1.11151599e-09, 0.997373283, -3.6827934e-09, -0.0724326521).Position,
            CFrame.new(-238.738724, 235.536224, -419.776947, -0.123079106, -1.72302208e-08, -0.992396891, 1.04802758e-07, 1, -3.03600842e-08, 0.992396891, -1.07742622e-07, -0.123079106).Position,
            CFrame.new(-229.121872, 235.028885, -418.370361, -0.159468517, -9.97663396e-10, -0.987203002, 5.61183899e-09, 1, -1.91710825e-09, 0.987203002, -5.84574256e-09, -0.159468517).Position,
            CFrame.new(-230.198135, 235.028885, -411.70752,  -0.158538401, 3.05768055e-09, -0.987352788, -1.93251264e-08, 1, 6.1998664e-09, 0.987352788, 2.00636361e-08, -0.158538401).Position,
            CFrame.new(-219.527756, 235.028885, -410.041046, -0.13149412, -1.45050567e-08, -0.991316974, 8.86244393e-08, 1, -2.63877755e-08, 0.991316974, -9.13247504e-08, -0.13149412).Position,
            CFrame.new(-218.356186, 235.028885, -419.13504,  -0.127756983, 4.72011719e-09, -0.991805494, -2.84962454e-08, 1, 8.42978931e-09, 0.991805494, 2.93396969e-08, -0.127756983).Position,
            CFrame.new(-216.975082, 235.687469, -429.857086, -0.127756983, 1.0203701e-08, -0.991805494, -6.15619058e-08, 1, 1.82179516e-08, 0.991805494, 6.33849098e-08, -0.127756983).Position,
            CFrame.new(-215.865295, 235.687698, -435.960388, -0.182680368, 1.05530846e-08, -0.983172357, -6.04063217e-08, 1, 2.19576304e-08, 0.983172357, 6.34010533e-08, -0.182680368).Position,
            CFrame.new(-207.901596, 235.687698, -434.480713, -0.182680368, -1.51661848e-08, -0.983172357, 8.51362145e-08, 1, -3.12446744e-08, 0.983172357, -8.94113583e-08, -0.182680368).Position,
            CFrame.new(-209.282623, 235.687698, -427.048004, -0.182680368, -1.40988039e-08, -0.983172357, 7.86268615e-08, 1, -2.89495414e-08, 0.983172357, -8.25922726e-08, -0.182680368).Position,
            CFrame.new(-214.615921, 235.687698, -421.468475, -0.182680368, -1.81170687e-08, -0.983172357, 1.00980685e-07, 1, -3.71900768e-08, 0.983172357, -1.06075312e-07, -0.182680368).Position,
            CFrame.new(-213.234924, 235.687698, -428.90097,  -0.182680368, 8.57435811e-09, -0.983172357, -4.77881805e-08, 1, 1.76004953e-08, 0.983172357, 5.0199283e-08, -0.182680368).Position,
        },
    },
}

local function shortName(n) return (n:gsub("DUNGEON_TELEPORTER", "Pad ")) end

local function setPadText(padObj, txt, color)
    pcall(function()
        local lbl = padObj.Pad.TeleporterBillboard.Status
        lbl.Text = txt
        if color then lbl.TextColor3 = color end
    end)
end

local function updatePadLabels(target)
    for _, p in ipairs(PAD_CONFIGS) do
        if target and p.name == target.name then
            setPadText(p.object, "TARGET", Color3.fromRGB(80, 255, 120))
        elseif padRandomCount(p.name) > 0 then
            setPadText(p.object, "BUSY", Color3.fromRGB(255, 120, 80))
        else
            setPadText(p.object, "free", Color3.fromRGB(190, 190, 190))
        end
    end
end

local REGROUP_RADIUS = cfg.regroupRadius or 15

local function accsNear(point, radius)
    local n = 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do
        local pl = Players:FindFirstChild(name)
        local root = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local flat = Vector3.new(root.Position.X, point.Y, root.Position.Z)
            if (flat - point).Magnitude <= radius then n += 1 end
        end
    end
    return n
end

local function pickTarget(state)
    local pad3 = PAD_CONFIGS[1]
    if padRandomCount(pad3.name) == 0 then
        state.blockedSince = nil
        return pad3
    end
    state.blockedSince = state.blockedSince or tick()
    if tick() - state.blockedSince >= PAD_WAIT_SECS then
        for i = 2, #PAD_CONFIGS do
            if padRandomCount(PAD_CONFIGS[i].name) == 0 then return PAD_CONFIGS[i] end
        end
    end
    return nil
end

local function approachPoint(pad)
    local on = pad.walkOnPositions[1]
    local rally = (#pad.transit > 0) and pad.transit[#pad.transit] or on
    local dir = Vector3.new(rally.X - on.X, 0, rally.Z - on.Z)
    if dir.Magnitude < 1 then return on end
    local sz = pad.object.Pad.Size
    local backoff = math.max(sz.X, sz.Z) * 0.5 + 5
    return on + dir.Unit * backoff
end

local function bailOff(pad)
    local target = pad.bailPositions[math.random(#pad.bailPositions)]
    walkTo(target)
end

local currentTask = nil
local runPipeline

local function stopPipeline()
    running = false
    releaseAll()
    if humanoid and hrp then humanoid:MoveTo(hrp.Position) end
    if cam then cam.CameraSubject=humanoid; cam.CameraType=Enum.CameraType.Custom end
    if humanoid then humanoid.AutoRotate = (oldAutoRotate~=nil) and oldAutoRotate or true end
    clearVisualizer()
    runBtn.Text = "Run"; runBtn.BackgroundColor3 = Color3.fromRGB(35, 70, 180)
    setPWStatus("Stopped", Color3.fromRGB(200, 80, 80))
    setCoordStatus("—")
    log("Stopped.")
end

local function restartRound()
    task.wait(0.3)
    if humanoid then humanoid.Health = 0 end
    player.CharacterAdded:Wait()
    refreshCharacter()
    task.wait(2.5)
    log("TEST: new round")
    currentTask = task.spawn(runPipeline)
end

function runPipeline()
    running = true
    runBtn.Text = "Stop"; runBtn.BackgroundColor3 = Color3.fromRGB(150, 35, 35)

    -- Reach the pad3 staging area using hubParkour's MOVEMENT (jump + dash), not a
    -- walked waypoint path. This is a single continuous parkour run from spawn onto
    -- the deck (route[1]), then a short plain walk to a point just OFF pad3 (route[2])
    -- where the squad regroups before the coordination loop below takes over.
    -- The parkour phase logic (burst/climb/cruise) is keyed off the spawn->pad geometry,
    -- so it must run as one leg — NOT segmented across hubWalk's old PATHS waypoints.
    local stage = PAD_CONFIGS[1]   -- pad3 region is the staging area
    local route = {
        Vector3.new(PK.obstacleLeftX + rand(-7, 6), 235, -360 + rand(-13, 13)),
        Vector3.new(-466 + rand(-4, 4), 235, -423 + rand(-4, 4)),   -- off-pad staging by pad3
    }

    guiPath.Text = "Parkour"
    setPWStatus("Parkour", Color3.fromRGB(80, 220, 120))
    guiWaypoint.Text = "0 / " .. #route

    for i, pt in ipairs(route) do
        if not running then break end
        guiWaypoint.Text = i .. " / " .. #route
        log("Route " .. i .. "/" .. #route)
        -- parkour (jump/dash) for the spawn -> deck leg; plain walk once on the deck
        local useParkour = i == 1 and hrp.Position.Y < 225 and hrp.Position.Z > STOP_JUMP_Z
        if useParkour then parkourTo(pt) else walkTo(pt) end
    end

    if not running then stopPipeline(); return end

    setPWStatus("Done", Color3.fromRGB(80, 220, 120))
    guiWaypoint.Text = #route .. " / " .. #route

    local total = #ALLOWED_ACCOUNTS
    local state = {}
    local committed = nil

    -- wait for all accounts near the staging area before picking a pad
    setCoordStatus("Gathering", Color3.fromRGB(200, 160, 50))
    log("Waiting for " .. total .. " accs near staging...")
    while running do
        local n = getNearbyCount(stage.name)
        guiNearby.Text = n .. "/" .. total
        if n >= total then break end
        task.wait(0.4)
    end
    if not running then stopPipeline(); return end
    log("Squad gathered at staging.")

    while running do
        local target
        if FORCE_PAD then
            for _, p in ipairs(PAD_CONFIGS) do if p.name == FORCE_PAD then target = p end end
        elseif committed and padRandomCount(committed.name) == 0 then
            target = committed
        else
            committed = nil
            target = pickTarget(state)
        end
        updatePadLabels(target)

        if not target then
            setCoordStatus("Pad3 busy — waiting", Color3.fromRGB(255, 140, 40))
            guiRandom.Text = "wait free pad"
            guiRandom.TextColor3 = Color3.fromRGB(255, 140, 40)
            task.wait(0.5)
            continue
        end

        if #target.transit > 0 then
            log("Routing to " .. shortName(target.name) .. " rally")
            setCoordStatus("-> " .. shortName(target.name), Color3.fromRGB(100, 180, 255))
            for _, tp in ipairs(target.transit) do
                if not running then break end
                walkTo(tp)
            end
            if not running then break end

            local rally = target.transit[#target.transit]
            setCoordStatus("Regroup " .. shortName(target.name), Color3.fromRGB(200, 160, 50))
            log("Regrouping at " .. shortName(target.name) .. " rally")
            while running do
                local n = accsNear(rally, REGROUP_RADIUS)
                guiNearby.Text = n .. "/" .. total
                if padRandomCount(target.name) > 0 then break end
                if n >= total then break end
                task.wait(0.3)
            end
            if not running then break end
            if padRandomCount(target.name) > 0 then
                committed = nil
                continue
            end

            log("Approaching " .. shortName(target.name))
            walkTo(approachPoint(target))
            if not running then break end
            if padRandomCount(target.name) > 0 then
                log(shortName(target.name) .. " no longer empty — re-picking")
                committed = nil
                continue
            end
        end

        committed = target
        setCoordStatus("On " .. shortName(target.name), Color3.fromRGB(80, 220, 120))
        walkTo(target.walkOnPositions[1])
        if not running then break end

        local leftForRandom = false
        while running do
            local randoms = padRandomCount(target.name)
            local oursOn  = getOnPadCount(target.name)
            guiOnPad.Text = oursOn .. "/" .. total
            guiRandom.Text = randoms > 0 and ("YES(" .. randoms .. ")") or "none"
            guiRandom.TextColor3 = randoms > 0 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 220, 120)

            if TEST_MODE then
                if meOnPad(target.name) then
                    log("TEST: reached " .. shortName(target.name) .. " — resetting")
                    setPadText(target.object, "REACHED", Color3.fromRGB(80, 255, 120))
                    running = false
                    clearVisualizer()
                    restartRound()
                    return
                end
                walkTo(target.walkOnPositions[1])
                task.wait(0.25)
                continue
            end

            if randoms > 0 then
                log("Random on " .. shortName(target.name) .. " — bailing")
                setCoordStatus("Bailing", Color3.fromRGB(255, 80, 80))
                bailOff(target)
                leftForRandom = true
                committed = nil
                break
            end

            if oursOn >= total and onlyOursOnPad(target.name) then
                log("All " .. total .. " on " .. shortName(target.name) .. "!")
                setCoordStatus("All on pad!", Color3.fromRGB(80, 255, 120))
                local remote = target.object:WaitForChild("DungeonSettingsChanged")
                task.wait(2)
                log("Setting difficulty: Easy")
                remote:FireServer("Difficulty", "Easy")
                task.wait(1)
                log("Starting dungeon...")
                remote:FireServer("Start")
                running = false
                runBtn.Text = "Run"; runBtn.BackgroundColor3 = Color3.fromRGB(35, 70, 180)
                return
            end

            if not meOnPad(target.name) then walkTo(target.walkOnPositions[1]) end
            task.wait(0.25)
        end

        if leftForRandom then task.wait(1.0) end
    end

    stopPipeline()
end

runBtn.MouseButton1Click:Connect(function()
    if running then
        stopPipeline()
    else
        if currentTask then task.cancel(currentTask) end
        currentTask = task.spawn(runPipeline)
    end
end)

if not table.find(ALLOWED_ACCOUNTS, player.Name) then
    setPWStatus("Not whitelisted", Color3.fromRGB(255, 80, 80))
    setCoordStatus("—")
    runBtn.Active = false; runBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    runBtn.Text = "Not allowed"
    log("ERROR: " .. player.Name .. " not in ALLOWED_ACCOUNTS")
else
    setPWStatus("Idle", Color3.fromRGB(140, 140, 170))
    setCoordStatus("Waiting for run", Color3.fromRGB(140, 140, 170))
    log("Ready. Press Run or set _G.runBot().")
    currentTask = task.spawn(runPipeline)
end

_G.runBot  = function() if not running then currentTask = task.spawn(runPipeline) end end
_G.stopBot = stopPipeline
