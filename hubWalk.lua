local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

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

local function onlyOursOnPad(padName)
    for name in pairs(allPlayersInside[padName] or {}) do
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

local PAD_CONFIGS = {
    {
        name   = "DUNGEON_TELEPORTER3",
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
        name   = "DUNGEON_TELEPORTER2",
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
        name   = "DUNGEON_TELEPORTER1",
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

local function bailOff(pad)
    local target = pad.bailPositions[math.random(#pad.bailPositions)]
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

    local PAD_SYNC_FILE = "DungeonBotPad.txt"
    if isfile(PAD_SYNC_FILE) then delfile(PAD_SYNC_FILE) end
    local function readPadTarget()
        if isfile(PAD_SYNC_FILE) then return tonumber(readfile(PAD_SYNC_FILE)) or 1 end
        return 1
    end
    local function writePadTarget(idx) writefile(PAD_SYNC_FILE, tostring(idx)) end

    local total        = #ALLOWED_ACCOUNTS
    local padIdx       = readPadTarget()
    local pad          = PAD_CONFIGS[padIdx]
    local padBlacklist = {}
    local needsTravel  = (padIdx ~= 1)

    setCoordStatus("Waiting nearby", Color3.fromRGB(200, 160, 50))
    log("Waiting for all " .. total .. " accs nearby...")
    while running do
        local n = getNearbyCount(PAD_CONFIGS[1].name)
        guiNearby.Text = n .. "/" .. total
        guiOnPad.Text  = PAD_CONFIGS[1].object:GetAttribute("NumPlayersOnPad") or "?"
        if n >= total then break end
        task.wait(0.5)
    end
    if not running then stopPipeline(); return end
    log("All accounts nearby!")

    while running do
        -- sync to whichever pad another account may have already switched to
        local targetIdx = readPadTarget()
        if targetIdx ~= padIdx then
            padIdx       = targetIdx
            padBlacklist = {}
            needsTravel  = true
        end
        pad = PAD_CONFIGS[padIdx]

        if needsTravel then
            needsTravel = false
            log("Travelling to " .. pad.name)
            setCoordStatus("Travelling to " .. pad.name, Color3.fromRGB(100, 180, 255))
            for _, wp in ipairs(pad.transit) do
                walkTo(wp); if not running then break end
            end
            if not running then break end
            local loiterPos = pad.walkOnPositions[math.random(#pad.walkOnPositions)]
            walkTo(loiterPos)
            if not running then break end
            setCoordStatus("Waiting nearby " .. pad.name, Color3.fromRGB(200, 160, 50))
            while running do
                local n = getNearbyCount(pad.name)
                guiNearby.Text = n .. "/" .. total
                if n >= total then break end
                task.wait(0.5)
            end
            if not running then break end
            log("All accounts nearby " .. pad.name)
        end

        setCoordStatus("Waiting " .. pad.name .. "=0", Color3.fromRGB(200, 160, 50))
        local waitStart = tick()
        local switched = false
        while running do
            local syncIdx = readPadTarget()
            if syncIdx ~= padIdx then
                padIdx = syncIdx; pad = PAD_CONFIGS[padIdx]; padBlacklist = {}
                needsTravel = true; switched = true
                log("Pad sync — following to " .. pad.name)
                break
            end
            local c = pad.object:GetAttribute("NumPlayersOnPad") or 0
            guiOnPad.Text = c .. "/" .. total
            if c == 0 then
                local t = allPlayersInside[pad.name]
                if t then for k in pairs(t) do t[k] = nil end end
                break
            end
            if tick() - waitStart >= PAD_WAIT_SECS then
                for i, alt in ipairs(PAD_CONFIGS) do
                    if i ~= padIdx and (alt.object:GetAttribute("NumPlayersOnPad") or 0) == 0 then
                        writePadTarget(i)
                        padIdx = i; pad = alt; padBlacklist = {}
                        needsTravel = true; switched = true
                        log("Pad busy — switching to " .. pad.name)
                        break
                    end
                end
                if switched then break end
                waitStart = tick()
            end
            task.wait(0.3)
        end
        if not running then break end

        if not switched then
            log("Pad empty — walking on " .. pad.name)
            setCoordStatus("Walking on", Color3.fromRGB(100, 180, 255))
            local walkOnPos = pad.walkOnPositions[math.random(#pad.walkOnPositions)]
            walkTo(walkOnPos)
            if not running then break end

            setCoordStatus("On pad", Color3.fromRGB(80, 220, 120))
            local bailed = false
            local bailTriggers = nil
            while running do
                local syncIdx = readPadTarget()
                if syncIdx ~= padIdx then
                    padIdx = syncIdx; pad = PAD_CONFIGS[padIdx]; padBlacklist = {}
                    needsTravel = true; switched = true
                    log("Pad sync — following to " .. pad.name)
                    break
                end
                local oursOnPad = getOnPadCount(pad.name)
                local oursOnly  = onlyOursOnPad(pad.name)
                local randomNames = {}
                for name in pairs(allPlayersInside[pad.name] or {}) do
                    if not table.find(ALLOWED_ACCOUNTS, name) and not padBlacklist[name] then
                        randomNames[name] = true
                    end
                end
                local hasRandom = next(randomNames) ~= nil and not oursOnly
                guiOnPad.Text        = oursOnPad .. "/" .. total
                guiRandom.Text       = hasRandom and "YES - bail!" or "none"
                guiRandom.TextColor3 = hasRandom and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 220, 120)

                if hasRandom then
                    log("Random detected! Bailing...")
                    setCoordStatus("Bailing", Color3.fromRGB(255, 80, 80))
                    bailTriggers = randomNames
                    bailOff(pad); bailed = true; break
                end

                if oursOnPad >= total and oursOnly then
                    log("All " .. total .. " accs on pad!")
                    setCoordStatus("All on pad!", Color3.fromRGB(80, 255, 120))
                    local remote = workspace.Map["Simulation Hub"].Pads[pad.name]:WaitForChild("DungeonSettingsChanged")
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

                task.wait(0.25)
            end

            if bailed then
                log("Waiting for pad to clear...")
                task.wait(3)
                local c = pad.object:GetAttribute("NumPlayersOnPad") or 0
                if c == 0 then
                    local insideNow = allPlayersInside[pad.name] or {}
                    for name in pairs(bailTriggers or {}) do
                        if insideNow[name] and not padBlacklist[name] then
                            padBlacklist[name] = true
                            log("Blacklisted " .. name .. " (still on pad, no energy)")
                        end
                    end
                end
            end
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
