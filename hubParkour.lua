repeat wait() until game:IsLoaded() and game.Players and game.Players.LocalPlayer
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM        = game:GetService("VirtualInputManager")

local lp  = Players.LocalPlayer
local cam = workspace.CurrentCamera

if getgenv().__stopP then pcall(getgenv().__stopP) end
task.wait(0.1)

-- ── config ────────────────────────────────────────────
local botCfg           = getgenv().DungeonBotConfig or {}
local ALLOWED_ACCOUNTS = botCfg.allowedAccounts or { "10980599928", "10980604756" }

local CFG = {
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
    stuckCheck          = 0.55,
    stuckMove           = 2.5,
    stuckLimit          = 5,
    maxRunTime          = 35,
    padWaitSecs         = botCfg.padWaitSecs   or 20,
    rendezvousRadius    = 55,
    regroupRadius       = 40,
    padPoll             = 0.3,
    padFrontExtra       = botCfg.padFrontExtra or 18,
    padMargin           = 6,
    padProximity        = 14,
    onPadTimeout        = 50,
    maxRetries          = 4,
    startDungeon        = getgenv().ParkourStartDungeon ~= false,
    difficulty          = getgenv().ParkourDifficulty   or "Easy",
}

local TRIP_Z      = -172
local STOP_JUMP_Z = -318
local OBSTACLE_BOX = { minX=-393, maxX=-305, minZ=-357, maxZ=-246 }

-- ── pad data ──────────────────────────────────────────
local PADS = {
    { id=3, name="DUNGEON_TELEPORTER3",
      rally  = Vector3.new(-466, 235, -423),
      walkOn = Vector3.new(-487, 237, -433),
      transit = {} },
    { id=2, name="DUNGEON_TELEPORTER2",
      rally  = Vector3.new(-423.566925, 235.028915, -387.250397),
      walkOn = Vector3.new(-360.964539, 236.566925, -447.52771),
      transit = { Vector3.new(-423.566925, 235.028915, -387.250397) } },
    { id=1, name="DUNGEON_TELEPORTER1",
      rally  = Vector3.new(-294.361115, 235.028915, -387.542358),
      walkOn = Vector3.new(-231.894653, 236.566925, -432.720825),
      transit = {
          Vector3.new(-423.566925, 235.028915, -387.250397),
          Vector3.new(-294.361115, 235.028915, -387.542358) } },
}

-- ── whitelist ─────────────────────────────────────────
local allowedSet = {}
for _, n in ipairs(ALLOWED_ACCOUNTS) do allowedSet[n] = true end
local function isAllowed(name) return allowedSet[name] == true end
local function totalAllowed() return math.max(#ALLOWED_ACCOUNTS, 1) end

if not isAllowed(lp.Name) then
    warn("[PK] " .. lp.Name .. " not whitelisted"); return
end

-- ── state ─────────────────────────────────────────────
local running = true
local char, hum, hrp
local oldAutoRotate = nil

local function refreshChar()
    char = lp.Character or lp.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid")
    hrp  = char:WaitForChild("HumanoidRootPart")
    return char, hum, hrp
end

-- ── math helpers ──────────────────────────────────────
local function rand(a, b) return a + math.random()*(b-a) end
local function flatDist(a, b)
    return (Vector3.new(a.X,0,a.Z) - Vector3.new(b.X,0,b.Z)).Magnitude
end
local function flatDir(a, b)
    local d = Vector3.new(b.X-a.X, 0, b.Z-a.Z)
    local m = d.Magnitude
    return (m < 1e-4) and Vector3.new(0,0,0) or d/m, m
end

-- ── pad workspace helpers ─────────────────────────────
local function padFolder()
    local map = workspace:FindFirstChild("Map")
    local hub = map and map:FindFirstChild("Simulation Hub")
    return hub and hub:FindFirstChild("Pads")
end
local function getPadObj(pad)
    local pf = padFolder(); return pf and pf:FindFirstChild(pad.name)
end
local function getPadPart(pad)
    local o = getPadObj(pad); return o and o:FindFirstChild("Pad")
end
local function padServerCount(pad)
    local o = getPadObj(pad)
    return (o and o:GetAttribute("NumPlayersOnPad")) or 0
end

-- ── pad detection — by player NAME, dual method ───────
-- Method 1: CFrame box check against the actual Pad part
-- Method 2: flat proximity fallback if part not found
local function isOnPad(player, pad)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local part = getPadPart(pad)
    if part then
        local lp_ = part.CFrame:PointToObjectSpace(root.Position)
        local h, m = part.Size * 0.5, CFG.padMargin
        if math.abs(lp_.X) <= h.X+m and math.abs(lp_.Z) <= h.Z+m
        and root.Position.Y >= part.Position.Y - 8
        and root.Position.Y <= part.Position.Y + 25 then
            return true
        end
    end
    return flatDist(root.Position, pad.walkOn) <= CFG.padProximity
       and math.abs(root.Position.Y - pad.walkOn.Y) <= 10
end

local function allowedOnPad(pad)
    local n = 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do
        local p = Players:FindFirstChild(name)
        if p and isOnPad(p, pad) then n += 1 end
    end
    return n
end
local function anyOnPad(pad)
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if isOnPad(p, pad) then n += 1 end
    end
    return n
end
local function randomsOnPad(pad)
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if not isAllowed(p.Name) and isOnPad(p, pad) then n += 1 end
    end
    return n
end
local function onlyAllowed(pad) return randomsOnPad(pad) == 0 end
local function meOnPad(pad) return isOnPad(lp, pad) end

local function accsNear(point, radius)
    local n = 0
    for _, name in ipairs(ALLOWED_ACCOUNTS) do
        local p = Players:FindFirstChild(name)
        local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if r and flatDist(r.Position, point) <= radius then n += 1 end
    end
    return n
end

-- ── VIM input ─────────────────────────────────────────
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
    if hum then hum:Move(Vector3.new(0,0,0), false) end
    for _, k in ipairs({Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D}) do releaseKey(k) end
    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
end
local function dash()   pulseKey(Enum.KeyCode.Q,     CFG.dashHold) end
local function doJump()
    if hum then hum.Jump = true end
    pulseKey(Enum.KeyCode.Space, CFG.jumpHold)
end
local function aimCam(pos, dir)
    if not cam or dir.Magnitude < 0.05 then return end
    local flat = Vector3.new(dir.X,0,dir.Z)
    if flat.Magnitude < 0.05 then return end
    flat = flat.Unit
    cam.CFrame = CFrame.lookAt(pos - flat*22 + Vector3.new(0,12,0), pos + flat*9)
end
local function facedir(pos, dir)
    if not hrp or dir.Magnitude < 0.05 then return end
    hrp.CFrame = CFrame.lookAt(pos, pos+dir)
end

-- ── cleanup ───────────────────────────────────────────
local function cleanup()
    running = false
    releaseAll()
    if hum and hrp then
        hum:Move(Vector3.new(0,0,0), false)
        hum.CameraOffset = Vector3.new(0,0,0)
        hum.AutoRotate = (oldAutoRotate ~= nil) and oldAutoRotate or true
    end
    if cam then cam.CameraSubject=hum; cam.CameraType=Enum.CameraType.Custom end
end
getgenv().__stopP = cleanup

-- ── parkourTo ─────────────────────────────────────────
local RUN_BIAS = Vector3.new(rand(-2,2), 0, ((math.random()<0.5) and -1 or 1)*rand(3,CFG.pathJitter))

local function biasTarget(t, hdist)
    return t + RUN_BIAS * math.clamp(hdist/CFG.pathJitterFade, 0, 1)
end
local function insideObs(p)
    local pad = CFG.obstaclePad
    return p.X>=OBSTACLE_BOX.minX-pad and p.X<=OBSTACLE_BOX.maxX+pad
       and p.Z>=OBSTACLE_BOX.minZ-pad and p.Z<=OBSTACLE_BOX.maxZ+pad
end
local function segEntersObs(a, b)
    for i=0,18 do if insideObs(a:Lerp(b,i/18)) then return true end end
end
local function bypassObs(pos, target)
    if not segEntersObs(pos, target) then return target end
    local midX = (OBSTACLE_BOX.minX+OBSTACLE_BOX.maxX)*0.5
    local bx = (target.X < midX) and CFG.obstacleLeftX or CFG.obstacleRightX
    return Vector3.new(bx+rand(-3,3), target.Y, CFG.obstacleBypassZ+rand(-2,2))
end
local function onFinalPlatform(pos, target, hdist)
    if not hum or hum.FloorMaterial==Enum.Material.Air then return false end
    return pos.Y>=CFG.finalFloorY and hdist<=CFG.finalPlatformDistance and pos.Z<=target.Z+35
end
local function getPhase(pos, target, hdist, crossed, stopJump, burstDone, t0)
    if tick()-t0 < CFG.warmup then return "warmup" end
    if stopJump or onFinalPlatform(pos,target,hdist) then return "walkin" end
    if not crossed then return "approach" end
    if not burstDone then return "burst" end
    if pos.Y < CFG.climbTop then return "climb" end
    return "cruise"
end

local function parkourTo(target)
    refreshChar()
    if oldAutoRotate == nil then oldAutoRotate = hum.AutoRotate end
    hum.AutoRotate = false
    if cam then cam.CameraSubject=hum; cam.CameraType=Enum.CameraType.Scriptable end

    local t0=tick(); local nextDash=0; local lastJump=0
    local lastCheck=tick(); local lastProg=hrp.Position; local stuckCount=0
    local crossed   = hrp.Position.Z <= TRIP_Z
    local stopJump  = hrp.Position.Z <= STOP_JUMP_Z
    local burst=0; local nextBurst=0
    local postWallDone = stopJump

    while running do
        RunService.Heartbeat:Wait()
        if not char or not char.Parent or not hum or hum.Health<=0 or not hrp or not hrp.Parent then
            refreshChar(); lastProg=hrp.Position
        end
        local now=tick(); local pos=hrp.Position
        local base     = bypassObs(pos, target)
        local steering = biasTarget(base, flatDist(pos, base))
        local dir, hdist = flatDir(pos, steering)

        if (pos-target).Magnitude<=CFG.reach and hum.FloorMaterial~=Enum.Material.Air then break end
        if now-t0 > CFG.maxRunTime then break end

        if not crossed  and pos.Z <= TRIP_Z      then crossed=true; burst=0; nextBurst=0 end
        if not stopJump and pos.Z <= STOP_JUMP_Z then stopJump=true end

        local burstDone = burst >= CFG.burstJumps
        local phase = getPhase(pos, target, hdist, crossed, stopJump, burstDone, t0)
        aimCam(pos, dir)
        if phase == "walkin" then
            releaseFwd(); hum:MoveTo(target)
        else
            facedir(pos, dir); holdFwd(); hum:Move(dir, false)
        end

        local grounded = hum.FloorMaterial ~= Enum.Material.Air
        local canDash, reason = false, nil
        if phase == "approach" then
            canDash = math.max(0, pos.Z-CFG.preJumpZ) > CFG.dashDistance and hdist > CFG.dashMinFlatDistance
            reason  = "approach"
        elseif crossed and burstDone and not stopJump and phase~="walkin" and pos.Y>=CFG.climbTop then
            canDash = hdist > CFG.dashMinFlatDistance; reason = "cruise"
        elseif stopJump and not postWallDone and grounded then
            canDash = hdist > math.max(CFG.walkInDistance, CFG.reach+8); reason = "postwall"
        end
        if canDash and now >= nextDash then
            facedir(pos, dir); holdFwd(); dash()
            nextDash = now + CFG.dashCooldown + rand(-CFG.dashCooldownJitter, CFG.dashCooldownJitter)
            if reason == "postwall" then
                postWallDone = true
                task.delay(0.18, function() if running then releaseFwd() end end)
            end
        end

        if not stopJump and crossed and burst < CFG.burstJumps then
            if now >= nextBurst then doJump(); burst+=1; lastJump=now; nextBurst=now+CFG.burstJumpInterval end
        elseif not stopJump and crossed and phase~="walkin" and pos.Y<CFG.climbTop and now-lastJump>=CFG.jumpCooldown then
            doJump(); lastJump=now
        elseif not stopJump and phase=="cruise" and pos.Y<CFG.cruiseFloor and now-lastJump>=CFG.jumpCooldown then
            doJump(); lastJump=now
        end

        if now - lastCheck >= CFG.stuckCheck then
            local moved = (pos-lastProg).Magnitude
            if now-t0>1.2 and moved<CFG.stuckMove and hdist>CFG.walkInDistance then
                stuckCount += 1
                if crossed and not stopJump and now-lastJump>=CFG.jumpCooldown then doJump(); lastJump=now end
                local nudge = (dir + Vector3.new(dir.Z,0,-dir.X)*((stuckCount%2==0) and 0.45 or -0.45)).Unit
                hum:Move(nudge, false)
                if stuckCount >= CFG.stuckLimit then break end
            else stuckCount=0 end
            lastProg=pos; lastCheck=now
        end
    end

    releaseAll()
    if cam then cam.CameraSubject=hum; cam.CameraType=Enum.CameraType.Custom end
    if hum then hum.AutoRotate = (oldAutoRotate~=nil) and oldAutoRotate or true end
end

-- ── walkTo ────────────────────────────────────────────
local function walkTo(target)
    refreshChar()
    if oldAutoRotate == nil then oldAutoRotate = hum.AutoRotate end
    hum.AutoRotate = true
    local t0=tick(); local lastCheck=tick(); local lastProg=hrp.Position; local stuckCount=0
    while running do
        RunService.Heartbeat:Wait()
        if not char or not char.Parent or not hum or hum.Health<=0 or not hrp or not hrp.Parent then
            refreshChar(); lastProg=hrp.Position
        end
        local now=tick(); local pos=hrp.Position
        if (pos-target).Magnitude<=CFG.reach and hum.FloorMaterial~=Enum.Material.Air then break end
        if now-t0 > CFG.maxRunTime then break end
        hum:MoveTo(target)
        if now - lastCheck >= CFG.stuckCheck then
            local moved = (pos-lastProg).Magnitude
            local _, hdist = flatDir(pos, target)
            if moved < CFG.stuckMove and hdist > CFG.walkInDistance then
                stuckCount += 1; if stuckCount >= CFG.stuckLimit then break end
            else stuckCount=0 end
            lastProg=pos; lastCheck=now
        end
    end
end

-- ── deck raycast (for ring/bail points) ───────────────
local function deckFloorY(x, z)
    local filter = {}; if char then table.insert(filter, char) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter
    local r = workspace:Raycast(Vector3.new(x,255,z), Vector3.new(0,-45,0), params)
    return r and r.Position.Y or nil
end

local function ringPoint(pad, minZDot)
    minZDot = minZDot or -1
    local part = getPadPart(pad)
    if not part then return pad.rally or pad.walkOn end
    local c = part.Position
    local hx, hz = part.Size.X*0.5, part.Size.Z*0.5
    local edge = math.max(hx, hz)
    for _=1,20 do
        local ang = math.random()*math.pi*2
        local dx, dz = math.cos(ang), math.sin(ang)
        if dz >= minZDot then
            local rad = edge + rand(5, 18)
            local x, z = c.X+dx*rad, c.Z+dz*rad
            local fy = deckFloorY(x, z)
            if fy and math.abs(fy-c.Y) <= 2.5 then
                local off = part.CFrame:PointToObjectSpace(Vector3.new(x,c.Y,z))
                if math.abs(off.X)>hx+2 or math.abs(off.Z)>hz+2 then
                    return Vector3.new(x, fy+3, z)
                end
            end
        end
    end
    local f = pad.rally and Vector3.new(pad.rally.X-c.X, 0, pad.rally.Z-c.Z) or Vector3.new(0,0,1)
    f = (f.Magnitude > 0.1) and f.Unit or Vector3.new(0,0,1)
    return Vector3.new(c.X+f.X*(edge+5), c.Y+3, c.Z+f.Z*(edge+5))
end

local function approachPoint(pad) return ringPoint(pad, -0.15) end
local function bailPoint(pad)     return ringPoint(pad, -0.7) end
local function frontPoint(pad)
    local on, rally = pad.walkOn, pad.rally or pad.walkOn
    local dir = Vector3.new(rally.X-on.X, 0, rally.Z-on.Z)
    if dir.Magnitude < 1 then return approachPoint(pad) end
    local part = getPadPart(pad)
    local backoff = part and (math.max(part.Size.X, part.Size.Z)*0.5 + 16 + CFG.padFrontExtra) or 28
    return on + dir.Unit*backoff
end

-- ── route ─────────────────────────────────────────────
local function buildRoute()
    -- obstacle bypass → approach T3
    return {
        Vector3.new(CFG.obstacleLeftX+rand(-7,6), 235, -360+rand(-13,13)),
        approachPoint(PADS[1]),
    }
end

-- ── pad selection ─────────────────────────────────────
local function selectPad()
    for _, pad in ipairs(PADS) do
        local sv = padServerCount(pad)
        if sv == 0 and randomsOnPad(pad) == 0 then
            print("[PK] Selected " .. pad.name); return pad
        end
        print("[PK] " .. pad.name .. " busy (sv=" .. sv .. " rnd=" .. randomsOnPad(pad) .. ")")
    end
    print("[PK] All busy — T3 fallback"); return PADS[1]
end

-- ── utility: wait with timeout ────────────────────────
local function waitFor(cond, timeout)
    local deadline = tick() + timeout
    while running and not cond() do
        if tick() > deadline then return false end
        task.wait(CFG.padPoll)
    end
    return running
end

-- ── coordination (after parkour) ──────────────────────
local function doCoordination(pad)
    local total = totalAllowed()

    -- Transit waypoints (T2 / T1 only)
    if #pad.transit > 0 then
        print("[PK] Transiting to " .. pad.name)
        for _, tp in ipairs(pad.transit) do
            if not running then return false end
            walkTo(tp)
        end
        if not running then return false end
        local rp = pad.rally or pad.walkOn
        print("[PK] Regrouping near " .. pad.name)
        waitFor(function() return accsNear(rp, CFG.regroupRadius) >= total end, 60)
        if not running then return false end
    end

    -- Wait for pad to be empty
    print("[PK] Waiting " .. pad.name .. " clear...")
    waitFor(function()
        return padServerCount(pad) == 0 or onlyAllowed(pad)
    end, CFG.padWaitSecs)
    if not running then return false end

    -- Walk onto pad
    print("[PK] Stepping onto " .. pad.name)
    walkTo(pad.walkOn)
    if not running then return false end

    -- Wait for full squad on pad
    local deadline = tick() + CFG.onPadTimeout
    print("[PK] Waiting for " .. total .. " accs on pad...")

    while running do
        local ours    = allowedOnPad(pad)
        local randoms = randomsOnPad(pad)
        print(string.format("[PK] on=%d/%d  rnd=%d  sv=%d", ours, total, randoms, padServerCount(pad)))

        if randoms > 0 then
            print("[PK] Random detected — bailing")
            walkTo(bailPoint(pad))
            waitFor(function() return randomsOnPad(pad) == 0 end, CFG.padWaitSecs)
            if not running then return false end
            walkTo(frontPoint(pad))
            if not running then return false end
            walkTo(pad.walkOn)
            if not running then return false end
            deadline = tick() + CFG.onPadTimeout
            continue
        end

        if ours >= total and onlyAllowed(pad) then
            print("[PK] All " .. total .. " on pad — starting dungeon!")
            if CFG.startDungeon then
                local obj    = getPadObj(pad)
                local remote = obj and obj:FindFirstChild("DungeonSettingsChanged")
                if remote then
                    task.wait(2)
                    remote:FireServer("Difficulty", CFG.difficulty)
                    task.wait(1)
                    remote:FireServer("Start")
                    print("[PK] Dungeon started!")
                end
            end
            return true
        end

        if tick() > deadline then
            print("[PK] Squad timeout — bailing")
            walkTo(bailPoint(pad))
            return false
        end

        if not meOnPad(pad) then
            print("[PK] Slipped off — re-walking on")
            walkTo(pad.walkOn)
        end
        task.wait(CFG.padPoll)
    end
    return false
end

-- ── main ──────────────────────────────────────────────
task.spawn(function()
    refreshChar()
    print("[PK] " .. lp.Name .. " starting")

    for attempt = 1, CFG.maxRetries do
        running = true
        print("[PK] Attempt " .. attempt .. "/" .. CFG.maxRetries)

        -- Parkour route: obstacle bypass → near T3
        local route = buildRoute()
        for i, pt in ipairs(route) do
            if not running then break end
            local useParkour = i == 1 and hrp.Position.Y < 225 and hrp.Position.Z > STOP_JUMP_Z
            if useParkour then parkourTo(pt) else walkTo(pt) end
        end
        if not running then break end

        -- Rendezvous: all accs within 55 studs of T3 walkOn (fixed, deterministic)
        local total = totalAllowed()
        print("[PK] Rendezvous — waiting " .. total .. " near T3...")
        local ok = waitFor(function()
            return accsNear(PADS[1].walkOn, CFG.rendezvousRadius) >= total
        end, 120)
        if not ok then print("[PK] Rendezvous timeout — continuing") end
        if not running then break end

        -- Select pad and coordinate
        local pad     = selectPad()
        local success = doCoordination(pad)

        if success or not running then break end

        if attempt < CFG.maxRetries then
            print("[PK] Retrying in 3s — respawning")
            running = false
            task.wait(3)
            local h = char and char:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then h.Health = 0 end
            lp.CharacterAdded:Wait()
            task.wait(2)
            refreshChar()
        end
    end

    cleanup()
    getgenv().__pdone = true
    print("[PK] Done")
end)
