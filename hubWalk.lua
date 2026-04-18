local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local cfg = getgenv().DungeonBotConfig or {}
local ALLOWED_ACCOUNTS = cfg.allowedAccounts or {
    "1",
    "2",
    "3",
    "4",
}
local PAD_NAME    = cfg.padName    or "DUNGEON_TELEPORTER3"
local PAD_OBJECT  = workspace.Map["Simulation Hub"].Pads[PAD_NAME]
local NEAR_RADIUS = cfg.nearRadius or 50
local WALK_ON_POS = cfg.walkOnPos  or Vector3.new(-487, 237, -433)
local REACH_DIST  = cfg.reachDist  or 5
local STUCK_CHECK = cfg.stuckCheck or 1
local STUCK_LIMIT = cfg.stuckLimit or 3
local STUCK_MOVE  = cfg.stuckMove  or 2

local player = Players.LocalPlayer
local character, humanoid, hrp

local function refreshCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid  = character:WaitForChild("Humanoid")
    hrp       = character:WaitForChild("HumanoidRootPart")
end
refreshCharacter()
player.CharacterAdded:Connect(refreshCharacter)

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

local allPlayersInside = {}
local allPlayersNearby = {}

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

local function onlyOursOnPad()
    for name in pairs(allPlayersInside[PAD_NAME] or {}) do
        if not table.find(ALLOWED_ACCOUNTS, name) then return false end
    end
    return true
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
        local lp = box.CFrame:PointToObjectSpace(pos)
        local h = box.Size / 2
        return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
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

local PATHS = {
    { spawn = Vector3.new(-399.904633, 201.054138, 222.452164), waypoints = {
        Vector3.new(-639.601318, 202.772675, -162.464706),
        Vector3.new(-634.090576, 222.132507, -276.580444),
        Vector3.new(-503.341797, 235.691422, -428.687073) } },
    { spawn = Vector3.new(-390.904633, 201.054138, 222.452133), waypoints = {
        Vector3.new(-428.296417, 202.08783,   94.0205841),
        Vector3.new(-645.095703, 202.772644, -170.690552),
        Vector3.new(-563.540039, 235.691437, -335.366364),
        Vector3.new(-459.487671, 235.691422, -444.92865) } },
    { spawn = Vector3.new(-381.904724, 201.054138, 222.452148), waypoints = {
        Vector3.new(-392.445984, 202.771042,  146.77565),
        Vector3.new(-653.576294, 202.772675, -154.134781),
        Vector3.new(-628.130249, 223.73999,  -281.792725),
        Vector3.new(-454.053619, 235.691437, -336.898895),
        Vector3.new(-483.50885,  235.559174, -420.197113) } },
    { spawn = Vector3.new(-372.904755, 201.054138, 222.452148), waypoints = {
        Vector3.new(-373.152374, 202.285431,  107.500404),
        Vector3.new(-640.437256, 202.772675, -161.328339),
        Vector3.new(-633.154175, 222.055267, -275.587616),
        Vector3.new(-479.357056, 235.032562, -385.325714),
        Vector3.new(-484.863678, 235.032562, -418.686859) } },
    { spawn = Vector3.new(-363.904785, 201.054138, 222.452164), waypoints = {
        Vector3.new(-365.14801,  202.314255,  109.171097),
        Vector3.new(-69.7169952, 203.480347, -179.378128),
        Vector3.new(-98.7861023, 225.324509, -290.760193),
        Vector3.new(-261.457153, 235.691376, -379.734283),
        Vector3.new(-480.321564, 235.691376, -377.664886),
        Vector3.new(-482.86322,  235.032562, -417.540985) } },
    { spawn = Vector3.new(-354.904816, 201.054138, 222.452164), waypoints = {
        Vector3.new(-543.7146,   202.772614, -100.072098),
        Vector3.new(-654.584717, 202.772675, -164.247482),
        Vector3.new(-632.112244, 222.921661, -279.81485),
        Vector3.new(-503.563507, 235.032562, -417.818268) } },
    { spawn = Vector3.new(-345.904877, 201.054138, 222.452148), waypoints = {
        Vector3.new(-334.919098, 202.097382,  108.860878),
        Vector3.new(-89.5553284, 202.772552, -107.929153),
        Vector3.new(-69.5169144, 210.797684, -223.427094),
        Vector3.new(-135.847977, 231.958374, -305.476074),
        Vector3.new(-237.792786, 235.691345, -334.190308),
        Vector3.new(-417.891205, 235.691391, -370.264954),
        Vector3.new(-487.402588, 235.032562, -417.892487) } },
    { spawn = Vector3.new(-336.904877, 201.054138, 222.452148), waypoints = {
        Vector3.new(-234.089828, 202.772614,  140.891373),
        Vector3.new(-135.388672, 202.772324,    6.61019373),
        Vector3.new(-71.7440491, 202.772552, -166.312393),
        Vector3.new(-106.690437, 227.004623, -295.105225),
        Vector3.new(-251.830276, 234.979065, -389.427338),
        Vector3.new(-463.136261, 235.691422, -422.388824) } },
    { spawn = Vector3.new(-327.904907, 201.054138, 222.452148), waypoints = {
        Vector3.new(-76.0165176, 202.772552, -173.222076),
        Vector3.new(-91.680275,  224.412064, -291.036835),
        Vector3.new(-307.729736, 235.62616,  -423.253998),
        Vector3.new(-470.264465, 235.691422, -438.771393) } },
}

local visFolder = nil

local function clearVisualizer()
    if visFolder then visFolder:Destroy(); visFolder = nil end
end

local function buildVisualizer(pathData)
    clearVisualizer()
    visFolder = Instance.new("Folder")
    visFolder.Name = "PathVisualizer"; visFolder.Parent = workspace
    local wps, spheres = pathData.waypoints, {}
    for i, pos in ipairs(wps) do
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(3,3,3); p.CFrame = CFrame.new(pos)
        p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(0, 180, 255); p.CastShadow = false; p.Parent = visFolder
        local bill = Instance.new("BillboardGui", p)
        bill.Size = UDim2.new(0, 28, 0, 16); bill.StudsOffset = Vector3.new(0, 3, 0)
        bill.AlwaysOnTop = true
        local lbl2 = Instance.new("TextLabel", bill)
        lbl2.Size = UDim2.new(1, 0, 1, 0); lbl2.BackgroundTransparency = 1
        lbl2.TextColor3 = Color3.new(1,1,1); lbl2.TextStrokeTransparency = 0
        lbl2.Font = Enum.Font.GothamBold; lbl2.TextScaled = true; lbl2.Text = tostring(i)
        spheres[i] = p
        if i > 1 then
            local a, b = wps[i-1], pos
            local line = Instance.new("Part")
            line.Size = Vector3.new(0.2, 0.2, (b-a).Magnitude)
            line.CFrame = CFrame.lookAt((a+b)/2, b)
            line.Anchored = true; line.CanCollide = false; line.Material = Enum.Material.Neon
            line.Color = Color3.fromRGB(30, 80, 160); line.Transparency = 0.5
            line.CastShadow = false; line.Parent = visFolder
        end
    end
    return spheres
end

local function selectPath()
    local pos, best, bestDist = hrp.Position, nil, math.huge
    for i, data in ipairs(PATHS) do
        local d = (pos - data.spawn).Magnitude
        if d < bestDist then bestDist = d; best = i end
    end
    log("Matched path " .. best)
    return best
end

local running = false

local function walkTo(target)
    local stuckCount, lastPos, lastCheck = 0, hrp.Position, tick()
    humanoid:MoveTo(target)
    while running do
        if (hrp.Position - target).Magnitude <= REACH_DIST then break end
        local now = tick()
        if now - lastCheck >= STUCK_CHECK then
            humanoid:MoveTo(target)
            local moved = (hrp.Position - lastPos).Magnitude
            if moved < STUCK_MOVE then
                stuckCount += 1
                setPWStatus("Stuck " .. stuckCount .. "/" .. STUCK_LIMIT, Color3.fromRGB(255, 160, 40))
                if stuckCount == 1 then humanoid.Jump = true end
                if stuckCount >= STUCK_LIMIT then log("Stuck — skipping waypoint"); break end
            else
                stuckCount = 0
            end
            lastPos = hrp.Position; lastCheck = now
        end
        task.wait(0.1)
    end
end

local BAIL_POSITIONS = {
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
}

local function bailOff()
    local target = BAIL_POSITIONS[math.random(#BAIL_POSITIONS)]
    walkTo(target)
end

local currentTask = nil

local function stopPipeline()
    running = false
    humanoid:MoveTo(hrp.Position)
    clearVisualizer()
    runBtn.Text = "Run"; runBtn.BackgroundColor3 = Color3.fromRGB(35, 70, 180)
    setPWStatus("Stopped", Color3.fromRGB(200, 80, 80))
    setCoordStatus("—")
    log("Stopped.")
end

local function runPipeline()
    running = true
    runBtn.Text = "Stop"; runBtn.BackgroundColor3 = Color3.fromRGB(150, 35, 35)

    local pathIdx  = selectPath()
    local pathData = PATHS[pathIdx]
    local wps      = pathData.waypoints
    local spheres  = buildVisualizer(pathData)

    guiPath.Text = "Path " .. pathIdx
    setPWStatus("Walking", Color3.fromRGB(80, 220, 120))
    guiWaypoint.Text = "0 / " .. #wps

    for i, pos in ipairs(wps) do
        if not running then break end
        spheres[i].Color = Color3.fromRGB(255, 200, 0)
        guiWaypoint.Text = i .. " / " .. #wps
        log("WP " .. i .. "/" .. #wps)
        walkTo(pos)
        if not running then break end
        spheres[i].Color = Color3.fromRGB(0, 255, 80)
    end

    clearVisualizer()
    if not running then stopPipeline(); return end

    setPWStatus("Done", Color3.fromRGB(80, 220, 120))
    guiWaypoint.Text = #wps .. " / " .. #wps

    local total = #ALLOWED_ACCOUNTS
    setCoordStatus("Waiting nearby", Color3.fromRGB(200, 160, 50))
    log("Waiting for all " .. total .. " accs nearby...")

    while running do
        local n = getNearbyCount(PAD_NAME)
        guiNearby.Text = n .. "/" .. total
        guiOnPad.Text  = PAD_OBJECT:GetAttribute("NumPlayersOnPad") or "?"
        if n >= total then break end
        task.wait(0.5)
    end

    if not running then stopPipeline(); return end
    log("All accounts nearby!")

    while running do
        setCoordStatus("Waiting pad=0", Color3.fromRGB(200, 160, 50))
        while running do
            local c = PAD_OBJECT:GetAttribute("NumPlayersOnPad") or 0
            guiOnPad.Text = c .. "/" .. total
            if c == 0 then
                local t = allPlayersInside[PAD_NAME]
                if t then for k in pairs(t) do t[k] = nil end end
                break
            end
            task.wait(0.3)
        end
        if not running then break end

        log("Pad empty — walking on")
        setCoordStatus("Walking on", Color3.fromRGB(100, 180, 255))
        walkTo(WALK_ON_POS)
        if not running then break end

        setCoordStatus("On pad", Color3.fromRGB(80, 220, 120))
        local bailed = false
        local allOursConfirmed = false

        while running do
            local padCount  = PAD_OBJECT:GetAttribute("NumPlayersOnPad") or 0
            local oursOnly  = onlyOursOnPad()
            local hasRandom = padCount > 0 and not oursOnly
            guiOnPad.Text        = padCount .. "/" .. total
            guiRandom.Text       = hasRandom and "YES - bail!" or "none"
            guiRandom.TextColor3 = hasRandom and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 220, 120)

            if not allOursConfirmed and padCount >= total and oursOnly then
                allOursConfirmed = true
            end

            if hasRandom and not allOursConfirmed then
                log("Random detected! Bailing...")
                setCoordStatus("Bailing", Color3.fromRGB(255, 80, 80))
                bailOff(); bailed = true; break
            end

            if allOursConfirmed then
                log("All " .. total .. " accs on pad!")
                setCoordStatus("All on pad!", Color3.fromRGB(80, 255, 120))
                guiRandom.Text = "none"; guiRandom.TextColor3 = Color3.fromRGB(80, 220, 120)
                local remote = workspace:WaitForChild("Map"):WaitForChild("Simulation Hub"):WaitForChild("Pads"):WaitForChild("DUNGEON_TELEPORTER3"):WaitForChild("DungeonSettingsChanged")
                task.wait(2)
                log("Setting difficulty: Hard")
                remote:FireServer("Difficulty", "Easy")
                task.wait(1)
                log("Starting dungeon...")
                remote:FireServer("Start")
                running = false
                runBtn.Text = "Run"; runBtn.BackgroundColor3 = Color3.fromRGB(35, 70, 180)
                return
            end

            task.wait(0.25)
        end

        if bailed then
            log("Waiting for pad to clear...")
            task.wait(3)
        end
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
