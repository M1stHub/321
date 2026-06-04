repeat task.wait() until game:IsLoaded() and game.Players and game.Players.LocalPlayer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local hubConfig = getgenv().hubconfig
if type(hubConfig) ~= "table" then
    hubConfig = {}
    getgenv().hubconfig = hubConfig
end

local DEFAULT_CONFIG = {
    accounts = {
        "1",
        "2",
        "3",
        "4",
    },
    initialPadPointIndex = nil,
    movement = {
        reach = 4,
        walkInDistance = 18,
        warmup = 0.75,
        pathJitter = 2,
        pathJitterFade = 75,
        dashCooldown = 0.28,
        dashCooldownJitter = 0.04,
        dashDistance = 37,
        dashHold = 0.035,
        dashMinFlatDistance = 49,
        jumpCooldown = 0.075,
        jumpHold = 0.055,
        burstJumps = 3,
        burstJumpInterval = 0.18,
        preJumpZ = -135,
        climbTopY = 260,
        cruiseFloorY = 252,
        finalFloorY = 233,
        finalPlatformDistance = 24,
        obstacleBypassZ = -336,
        obstacleLeftX = -500,
        obstaclePad = 10,
        obstacleSamples = 18,
        stuckCheckInterval = 0.55,
        stuckMoveDistance = 2.5,
        stuckLimit = 5,
        maxRunTime = 35,
        unstickStartTime = 1.2,
        unstickSideForce = 0.45,
        postWallReleaseDelay = 0.18,
        cameraBackDistance = 22,
        cameraHeight = 12,
        cameraLookAhead = 9,
        minDirection = 0.05,
        minFlatDirection = 0.0001,
        padTargetYOffset = 3,
        padNearYRange = 12,
        initialBypassY = 235,
        initialBypassZ = -360,
        initialBypassXJitterMin = -7,
        initialBypassXJitterMax = 6,
        initialBypassZJitter = 13,
    },
    monitor = {
        enabled = true,
        pollInterval = 0.1,
        boxExtraSize = Vector3.new(-2, 20, -2),
        guiPosition = UDim2.new(0, 24, 0, 180),
        guiSize = UDim2.new(0, 330, 0, 232),
    },
    coordination = {
        startEnabled = true,
        waitPoll = 0.25,
        teamStageRadius = 65,
        onPadRadius = 18,
        teamOnPadTimeout = 20,
        padClearStableTime = 2.5,
        padBusySwitchTime = 5,
        lookTurnTime = 0.35,
    },
    dungeon = {
        difficulty = "Normal",
        startWhenTeamReady = true,
        leaderOnly = true,
        leaderName = nil,
        startDelay = 0.25,
    },
    visualizer = {
        enabled = true,
        folderName = "HubParkourVis",
        currentMarkerName = "CurrentMoveTarget",
    },
    runtime = {},
}

local STRINGS = {
    logPrefix = "[Hub]",
    propPrefix = "[HubMonitor]",
    map = "Map",
    hub = "Simulation Hub",
    props = "Props",
    pads = "Pads",
    pad = "Pad",
    propTeleporters = "PropTeleporters",
    teleporterPrefix = "DUNGEON_TELEPORTER",
    settingsRemote = "DungeonSettingsChanged",
    difficultySetting = "Difficulty",
    startSetting = "Start",
    billboard = "TeleporterBillboard",
    status = "Status",
    monitorFolder = "PropPadBoxes",
    monitorGui = "PropPadBoxesGui",
    guiTitle = "Prop Pad Monitor",
    coordOn = "Coord: ON",
    coordOff = "Coord: OFF",
    emptyNames = "none",
    unknownStatus = "?/4",
    noEnergySuffix = " (no energy)",
}

local COLORS = {
    white = Color3.fromRGB(255, 255, 255),
    panel = Color3.fromRGB(18, 20, 26),
    header = Color3.fromRGB(28, 32, 42),
    row = Color3.fromRGB(24, 27, 35),
    countBg = Color3.fromRGB(34, 39, 52),
    title = Color3.fromRGB(235, 240, 255),
    muted = Color3.fromRGB(165, 176, 198),
    status = Color3.fromRGB(185, 196, 220),
    stroke = Color3.fromRGB(82, 96, 122),
    start = Color3.fromRGB(45, 135, 78),
    stop = Color3.fromRGB(160, 62, 62),
    current = Color3.fromRGB(255, 255, 80),
    route = Color3.fromRGB(30, 80, 160),
    routePoint = Color3.fromRGB(0, 180, 255),
    routeEnd = Color3.fromRGB(0, 255, 120),
    jumpWall = Color3.fromRGB(255, 70, 70),
    stopWall = Color3.fromRGB(70, 170, 255),
    pads = {
        Color3.fromRGB(0, 190, 255),
        Color3.fromRGB(80, 255, 120),
        Color3.fromRGB(255, 210, 70),
    },
}

local TRIP_Z = -172
local STOP_JUMP_Z = -318
local TRIP_A = Vector3.new(-560, 235, TRIP_Z)
local TRIP_B = Vector3.new(-160, 235, TRIP_Z)
local STOP_A = Vector3.new(-560, 235, STOP_JUMP_Z)
local STOP_B = Vector3.new(-160, 235, STOP_JUMP_Z)
local OBSTACLE = { minX = -393, maxX = -305, minZ = -357, maxZ = -246 }
local PAD_STATUS_INDEX = { [1] = 3, [2] = 2, [3] = 1 }
local ALTERNATE_ORDER = { [1] = { 2, 3 }, [2] = { 3, 1 }, [3] = { 2, 1 } }
local VALID_DIFFICULTIES = {
    Normal = true,
    Hard = true,
    Challenge = true,
}

local PAD_POINTS = {
    [1] = {
        Vector3.new(-468.363, 234.973, -423.283), Vector3.new(-476.416, 234.314, -415.23),
        Vector3.new(-487.416, 234.314, -412.283), Vector3.new(-498.416, 234.314, -415.23),
        Vector3.new(-506.468, 234.973, -423.283), Vector3.new(-458.414, 234.973, -420.759),
        Vector3.new(-469.061, 234.314, -408.07), Vector3.new(-484.627, 234.314, -402.405),
        Vector3.new(-500.939, 234.314, -405.281), Vector3.new(-513.628, 234.314, -415.928),
        Vector3.new(-463.78, 234.973, -430.115), Vector3.new(-511.051, 234.973, -430.115),
        Vector3.new(-459.841, 234.973, -429.421), Vector3.new(-514.462, 234.973, -427.036),
        Vector3.new(-468.097, 234.973, -429.107), Vector3.new(-473.273, 234.973, -420.141),
        Vector3.new(-482.239, 234.314, -414.964), Vector3.new(-492.592, 234.314, -414.964),
        Vector3.new(-501.558, 234.973, -420.141), Vector3.new(-506.734, 234.973, -429.107),
    },
    [2] = {
        Vector3.new(-349.378, 234.973, -428.623), Vector3.new(-360.378, 234.973, -425.676),
        Vector3.new(-371.378, 234.973, -428.623), Vector3.new(-342.024, 234.973, -421.463),
        Vector3.new(-357.589, 234.314, -415.797), Vector3.new(-373.902, 234.314, -418.674),
        Vector3.new(-386.591, 234.973, -429.321), Vector3.new(-322.697, 234.973, -421.291),
        Vector3.new(-344.645, 234.314, -404.45), Vector3.new(-376.111, 234.314, -404.45),
        Vector3.new(-341.993, 234.973, -429.291), Vector3.new(-378.763, 234.973, -429.291),
        Vector3.new(-337.751, 234.973, -425.048), Vector3.new(-383.006, 234.973, -425.048),
        Vector3.new(-377.349, 234.973, -430.705), Vector3.new(-353.131, 234.973, -420.63),
        Vector3.new(-367.625, 234.973, -420.63), Vector3.new(-330.933, 234.973, -430.676),
        Vector3.new(-336.337, 234.973, -423.634), Vector3.new(-351.578, 234.314, -414.834),
    },
    [3] = {
        Vector3.new(-213.197, 234.973, -422.153), Vector3.new(-221.25, 234.314, -414.1),
        Vector3.new(-232.25, 234.314, -411.153), Vector3.new(-243.25, 234.314, -414.1),
        Vector3.new(-251.302, 234.973, -422.153), Vector3.new(-203.248, 234.314, -419.629),
        Vector3.new(-213.895, 234.314, -406.94), Vector3.new(-229.461, 234.314, -401.275),
        Vector3.new(-245.774, 234.314, -404.151), Vector3.new(-258.463, 234.314, -414.799),
        Vector3.new(-208.615, 234.973, -428.985), Vector3.new(-255.885, 234.973, -428.985),
        Vector3.new(-204.356, 234.973, -430.713), Vector3.new(-259.825, 234.973, -428.291),
        Vector3.new(-212.931, 234.973, -427.977), Vector3.new(-218.108, 234.314, -419.011),
        Vector3.new(-227.074, 234.314, -413.834), Vector3.new(-237.426, 234.314, -413.834),
        Vector3.new(-246.392, 234.314, -419.011), Vector3.new(-251.568, 234.973, -427.977),
    },
}

local state = {
    running = true,
    character = nil,
    humanoid = nil,
    root = nil,
    oldAutoRotate = nil,
    heldKeys = {},
    propBoxes = {},
    propInside = {},
    propRows = {},
    propFolder = nil,
    propGui = nil,
    propStatusLabel = nil,
    propRunning = false,
    coordStatus = nil,
    coordEnabled = true,
    noEnergyIgnored = {},
}

local function isArray(tableValue)
    return type(next(tableValue)) == "number" or #tableValue > 0
end

local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        elseif type(value) == "table" and type(target[key]) == "table" and not isArray(value) then
            applyDefaults(target[key], value)
        end
    end
end

applyDefaults(hubConfig, DEFAULT_CONFIG)
state.coordEnabled = hubConfig.coordination.startEnabled
hubConfig.runtime.padCoordEnabled = state.coordEnabled

local movement = hubConfig.movement
local monitor = hubConfig.monitor
local coordination = hubConfig.coordination
local dungeon = hubConfig.dungeon
local runtime = hubConfig.runtime
runtime.done = false
runtime.startedDungeon = false

local teamSet = {}
for _, name in ipairs(hubConfig.accounts) do
    teamSet[tostring(name)] = true
end

local function log(message)
    print(STRINGS.logPrefix .. " " .. tostring(message))
end

local function warnHub(message)
    warn(STRINGS.logPrefix .. " " .. tostring(message))
end

local function logProp(message)
    print(STRINGS.propPrefix .. " " .. tostring(message))
end

local function destroy(instance)
    if instance then
        local ok, err = pcall(function()
            instance:Destroy()
        end)
        if not ok then
            warnHub("Destroy failed: " .. tostring(err))
        end
    end
end

local function randomBetween(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function flatVector(a, b)
    return Vector3.new(b.X - a.X, 0, b.Z - a.Z)
end

local function flatDistance(a, b)
    return flatVector(a, b).Magnitude
end

local function flatDirection(a, b)
    local delta = flatVector(a, b)
    local distance = delta.Magnitude
    if distance < movement.minFlatDirection then
        return Vector3.new(0, 0, 0), 0
    end
    return delta / distance, distance
end

local function getChild(root, path)
    local current = root
    for _, name in ipairs(path) do
        current = current and current:FindFirstChild(name)
    end
    return current
end

local function getHub()
    return getChild(workspace, { STRINGS.map, STRINGS.hub })
end

local function getProps()
    local hub = getHub()
    return hub and hub:FindFirstChild(STRINGS.props)
end

local function getPads()
    local hub = getHub()
    return hub and hub:FindFirstChild(STRINGS.pads)
end

local function getTeleporter(padIndex)
    local pads = getPads()
    local statusIndex = PAD_STATUS_INDEX[padIndex] or padIndex
    return pads and pads:FindFirstChild(STRINGS.teleporterPrefix .. tostring(statusIndex))
end

local function getStatusText(padIndex)
    local teleporter = getTeleporter(padIndex)
    local label = teleporter and getChild(teleporter, { STRINGS.pad, STRINGS.billboard, STRINGS.status })
    return label and label.Text or STRINGS.unknownStatus
end

local function getStatusCount(padIndex)
    return tonumber(string.match(getStatusText(padIndex), "(%d+)%s*/"))
end

local function getDungeonSettingsRemote(padIndex)
    local teleporter = getTeleporter(padIndex)
    return teleporter and teleporter:FindFirstChild(STRINGS.settingsRemote)
end

local function refreshCharacter()
    state.character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    state.humanoid = state.character:WaitForChild("Humanoid")
    state.root = state.character:WaitForChild("HumanoidRootPart")
    return state.character, state.humanoid, state.root
end

local function ensureCharacter()
    if not state.character or not state.character.Parent or not state.humanoid or state.humanoid.Health <= 0 or not state.root or not state.root.Parent then
        refreshCharacter()
    end
end

local function setAutoRotate(enabled)
    if state.oldAutoRotate == nil and state.humanoid then
        state.oldAutoRotate = state.humanoid.AutoRotate
    end
    if state.humanoid then
        state.humanoid.AutoRotate = enabled
    end
end

local function restoreAutoRotate()
    if state.humanoid then
        state.humanoid.AutoRotate = state.oldAutoRotate ~= nil and state.oldAutoRotate or true
    end
end

local function sendKey(keyCode, isDown)
    VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
end

local function holdKey(keyCode)
    if state.heldKeys[keyCode] then
        return
    end
    state.heldKeys[keyCode] = true
    sendKey(keyCode, true)
end

local function releaseKey(keyCode)
    if not state.heldKeys[keyCode] then
        return
    end
    state.heldKeys[keyCode] = nil
    sendKey(keyCode, false)
end

local function pulseKey(keyCode, holdTime)
    task.spawn(function()
        sendKey(keyCode, true)
        task.wait(holdTime)
        sendKey(keyCode, false)
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

local function releaseMovement()
    if state.humanoid then
        state.humanoid:Move(Vector3.new(0, 0, 0), false)
    end
    for _, keyCode in ipairs({ Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }) do
        releaseKey(keyCode)
    end
    sendKey(Enum.KeyCode.Space, false)
    sendKey(Enum.KeyCode.Q, false)
end

local function dash()
    pulseKey(Enum.KeyCode.Q, movement.dashHold)
end

local function jump()
    if state.humanoid then
        state.humanoid.Jump = true
    end
    pulseKey(Enum.KeyCode.Space, movement.jumpHold)
end

local function face(position, direction)
    if state.root and direction.Magnitude >= movement.minDirection then
        state.root.CFrame = CFrame.lookAt(position, position + direction)
    end
end

local function aimCamera(position, direction)
    if not camera or direction.Magnitude < movement.minDirection then
        return
    end
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude < movement.minDirection then
        return
    end
    local unit = flat.Unit
    camera.CFrame = CFrame.lookAt(
        position - unit * movement.cameraBackDistance + Vector3.new(0, movement.cameraHeight, 0),
        position + unit * movement.cameraLookAhead
    )
end

local function lookAtPoint(target)
    refreshCharacter()
    local startPosition = state.root.Position
    local direction = flatVector(startPosition, target)
    if direction.Magnitude < movement.minDirection then
        return
    end

    local unit = direction.Unit
    local startRoot = state.root.CFrame
    local goalRoot = CFrame.lookAt(startPosition, startPosition + unit)
    local startCamera = camera and camera.CFrame
    local goalCamera = camera and CFrame.lookAt(
        startPosition - unit * movement.cameraBackDistance + Vector3.new(0, movement.cameraHeight, 0),
        startPosition + unit * movement.cameraLookAhead
    )

    releaseMovement()
    local startedAt = tick()
    while state.running and tick() - startedAt < coordination.lookTurnTime do
        local alpha = math.clamp((tick() - startedAt) / coordination.lookTurnTime, 0, 1)
        local eased = alpha * alpha * (3 - 2 * alpha)
        state.root.CFrame = startRoot:Lerp(goalRoot, eased)
        if camera and startCamera and goalCamera then
            camera.CFrame = startCamera:Lerp(goalCamera, eased)
        end
        RunService.Heartbeat:Wait()
    end
    state.root.CFrame = goalRoot
    if camera and goalCamera then
        camera.CFrame = goalCamera
    end
end

local function makeBillboard(parent, text, color)
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextColor3 = color or COLORS.white
    label.TextScaled = true
    label.TextStrokeTransparency = 0
    label.Parent = billboard
    return label
end

local function makePart(name, size, cframe, color, transparency, parent)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = transparency
    part.Parent = parent
    return part
end

local function clearVisualizer()
    destroy(runtime.visualizer)
    runtime.visualizer = nil
    runtime.currentMarker = nil
end

local function getVisualizer()
    if not hubConfig.visualizer.enabled then
        return nil
    end
    if runtime.visualizer and runtime.visualizer.Parent then
        return runtime.visualizer
    end
    local folder = Instance.new("Folder")
    folder.Name = hubConfig.visualizer.folderName
    folder.Parent = workspace
    runtime.visualizer = folder
    return folder
end

local function addVisualPoint(folder, position, label, color)
    local point = makePart(label, Vector3.new(4, 4, 4), CFrame.new(position), color, 0.25, folder)
    point.Shape = Enum.PartType.Ball
    makeBillboard(point, label, color)
end

local function addVisualLine(folder, a, b, color)
    makePart("RouteLine", Vector3.new(0.35, 0.35, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, 0.45, folder)
end

local function addVisualWall(folder, a, b, label, color)
    local wall = makePart(label, Vector3.new(1, 35, (b - a).Magnitude), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 17, 0), b), color, 0.5, folder)
    makeBillboard(wall, label, color)
end

local function setMoveTarget(label, position)
    runtime.moveTarget = { label = label, position = position }
    local folder = getVisualizer()
    if not folder then
        return
    end

    local marker = runtime.currentMarker
    if not marker or not marker.Parent then
        marker = makePart(hubConfig.visualizer.currentMarkerName, Vector3.new(5, 5, 5), CFrame.new(position), COLORS.current, 0.05, folder)
        marker.Shape = Enum.PartType.Ball
        makeBillboard(marker, label, COLORS.current)
        runtime.currentMarker = marker
    end
    marker.CFrame = CFrame.new(position)

    local labelGui = marker:FindFirstChildOfClass("BillboardGui")
    local textLabel = labelGui and labelGui:FindFirstChildOfClass("TextLabel")
    if textLabel then
        textLabel.Text = label
    end
end

local function buildVisualizer(route, labels)
    clearVisualizer()
    local folder = getVisualizer()
    if not folder then
        return
    end

    addVisualWall(folder, TRIP_A, TRIP_B, "JUMP", COLORS.jumpWall)
    addVisualWall(folder, STOP_A, STOP_B, "STOP JUMP", COLORS.stopWall)

    local previous = state.root and state.root.Position
    if previous then
        addVisualPoint(folder, previous, "SPAWN", COLORS.current)
    end

    for index, point in ipairs(route) do
        local color = index == #route and COLORS.routeEnd or COLORS.routePoint
        addVisualPoint(folder, point, labels[index] or tostring(index), color)
        if previous then
            addVisualLine(folder, previous, point, COLORS.route)
        end
        previous = point
    end
end

local function makeCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function makeLabel(parent, options)
    local label = Instance.new("TextLabel")
    label.Size = options.size
    label.Position = options.position or UDim2.new()
    label.BackgroundTransparency = options.backgroundTransparency or 1
    label.BackgroundColor3 = options.backgroundColor or COLORS.panel
    label.BorderSizePixel = 0
    label.Font = options.font or Enum.Font.Gotham
    label.Text = options.text or ""
    label.TextColor3 = options.color or COLORS.title
    label.TextSize = options.textSize or 12
    label.TextXAlignment = options.align or Enum.TextXAlignment.Center
    label.TextTruncate = options.truncate or Enum.TextTruncate.None
    label.Parent = parent
    return label
end

local function makeButton(parent, text, xOffset, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 56, 0, 24)
    button.Position = UDim2.new(1, xOffset, 0, 7)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = COLORS.white
    button.TextSize = 12
    button.Parent = parent
    makeCorner(button, 5)
    return button
end

local function setCoordEnabled(enabled)
    state.coordEnabled = enabled
    runtime.padCoordEnabled = enabled
    if state.propStatusLabel then
        state.propStatusLabel.Text = enabled and STRINGS.coordOn or STRINGS.coordOff
    end
end

local function attachDrag(handle, frame)
    local dragging = false
    local dragStart = nil
    local startPosition = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end)
end

local function rootInsideBox(root, box)
    local localPosition = box.cframe:PointToObjectSpace(root.Position)
    local half = box.size * 0.5
    return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Y) <= half.Y and math.abs(localPosition.Z) <= half.Z
end

local function namesInBox(box)
    local names = {}
    for _, player in pairs(state.propInside[box.name] or {}) do
        local suffix = state.noEnergyIgnored[player.UserId] and STRINGS.noEnergySuffix or ""
        table.insert(names, player.Name .. suffix)
    end
    table.sort(names)
    return #names > 0 and table.concat(names, ", ") or STRINGS.emptyNames
end

local function updateMonitorGui()
    if not state.propGui then
        return
    end
    for padIndex = 1, 3 do
        local row = state.propRows[padIndex]
        if row then
            row.count.Text = getStatusText(padIndex)
            row.names.Text = state.propBoxes[padIndex] and namesInBox(state.propBoxes[padIndex]) or "missing box"
        end
    end
    if state.propStatusLabel then
        local coordText = state.coordEnabled and STRINGS.coordOn or STRINGS.coordOff
        state.propStatusLabel.Text = coordText .. " | " .. (state.coordStatus or "ready")
    end
end

local function setCoordStatus(text)
    state.coordStatus = text
    updateMonitorGui()
end

local function clearMonitor()
    state.propRunning = false
    runtime.propBoxActive = false
    destroy(state.propFolder)
    destroy(state.propGui)
    destroy(workspace:FindFirstChild(STRINGS.monitorFolder))

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    destroy(playerGui and playerGui:FindFirstChild(STRINGS.monitorGui))

    state.propBoxes = {}
    state.propInside = {}
    state.propRows = {}
    state.propFolder = nil
    state.propGui = nil
    state.propStatusLabel = nil
end

local function createMonitorRow(parent, padIndex)
    local color = COLORS.pads[padIndex]
    local row = Instance.new("Frame")
    row.Name = "Pad" .. padIndex
    row.Size = UDim2.new(1, 0, 0, 54)
    row.BackgroundColor3 = COLORS.row
    row.BorderSizePixel = 0
    row.LayoutOrder = padIndex
    row.Parent = parent
    makeCorner(row, 6)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -12)
    stripe.Position = UDim2.new(0, 8, 0, 6)
    stripe.BackgroundColor3 = color
    stripe.BorderSizePixel = 0
    stripe.Parent = row
    makeCorner(stripe, 4)

    makeLabel(row, {
        size = UDim2.new(0, 90, 0, 22),
        position = UDim2.new(0, 18, 0, 7),
        text = "Pad " .. padIndex,
        font = Enum.Font.GothamBold,
        textSize = 14,
        align = Enum.TextXAlignment.Left,
    })

    local count = makeLabel(row, {
        size = UDim2.new(0, 70, 0, 22),
        position = UDim2.new(1, -78, 0, 7),
        text = STRINGS.unknownStatus,
        color = color,
        font = Enum.Font.GothamBold,
        textSize = 14,
        backgroundTransparency = 0,
        backgroundColor = COLORS.countBg,
    })
    makeCorner(count, 5)

    local names = makeLabel(row, {
        size = UDim2.new(1, -30, 0, 20),
        position = UDim2.new(0, 18, 0, 30),
        text = STRINGS.emptyNames,
        color = COLORS.muted,
        textSize = 12,
        align = Enum.TextXAlignment.Left,
        truncate = Enum.TextTruncate.AtEnd,
    })

    state.propRows[padIndex] = { count = count, names = names }
end

local function createMonitorGui()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    state.propGui = Instance.new("ScreenGui")
    state.propGui.Name = STRINGS.monitorGui
    state.propGui.ResetOnSpawn = false
    state.propGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = monitor.guiSize
    frame.Position = monitor.guiPosition
    frame.BackgroundColor3 = COLORS.panel
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = state.propGui
    makeCorner(frame, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.stroke
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 38)
    header.BackgroundColor3 = COLORS.header
    header.BorderSizePixel = 0
    header.Parent = frame
    makeCorner(header, 8)

    makeLabel(header, {
        size = UDim2.new(1, -150, 1, 0),
        position = UDim2.new(0, 12, 0, 0),
        text = STRINGS.guiTitle,
        font = Enum.Font.GothamBold,
        textSize = 15,
        align = Enum.TextXAlignment.Left,
    })

    makeButton(header, "Start", -124, COLORS.start).MouseButton1Click:Connect(function()
        setCoordEnabled(true)
        log("Pad coordination enabled")
    end)

    makeButton(header, "Stop", -64, COLORS.stop).MouseButton1Click:Connect(function()
        setCoordEnabled(false)
        log("Pad coordination stopped")
    end)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -16, 1, -72)
    body.Position = UDim2.new(0, 8, 0, 44)
    body.BackgroundTransparency = 1
    body.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = body

    for padIndex = 1, 3 do
        createMonitorRow(body, padIndex)
    end

    state.propStatusLabel = makeLabel(frame, {
        size = UDim2.new(1, -16, 0, 20),
        position = UDim2.new(0, 8, 1, -24),
        text = state.coordEnabled and STRINGS.coordOn or STRINGS.coordOff,
        color = COLORS.status,
        font = Enum.Font.GothamBold,
        textSize = 12,
        align = Enum.TextXAlignment.Left,
    })

    attachDrag(header, frame)
end

local function resolvePropPads()
    local props = getProps()
    if not props then
        warnHub("Props folder not found")
        return {}
    end
    local children = props:GetChildren()
    local propTeleporters = props:FindFirstChild(STRINGS.propTeleporters)
    return {
        { index = 1, name = "PropTeleporters.Pad", pad = propTeleporters and propTeleporters:FindFirstChild(STRINGS.pad) },
        { index = 2, name = "Props[2].Pad", pad = children[2] and children[2]:FindFirstChild(STRINGS.pad) },
        { index = 3, name = "Props[3].Pad", pad = children[3] and children[3]:FindFirstChild(STRINGS.pad) },
    }
end

local function createPropBox(target)
    local size = target.pad.Size + monitor.boxExtraSize
    local cframe = target.pad.CFrame * CFrame.new(0, (size.Y - target.pad.Size.Y) * 0.5, 0)
    local color = COLORS.pads[target.index]
    local boxPart = makePart("PropPadBox_" .. target.index, size, cframe, color, 0.75, state.propFolder)

    local outline = Instance.new("SelectionBox")
    outline.Name = "Outline"
    outline.Adornee = boxPart
    outline.Color3 = color
    outline.LineThickness = 0.05
    outline.SurfaceTransparency = 1
    outline.Parent = boxPart

    makeBillboard(boxPart, target.name, color)
    return { index = target.index, name = target.name, pad = target.pad, part = boxPart, size = size, cframe = cframe }
end

local function updateBoxPresence(box, player, seen)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local inside = root and rootInsideBox(root, box)
    local playersInside = state.propInside[box.name]
    seen[player.UserId] = true

    if inside and not playersInside[player.UserId] then
        playersInside[player.UserId] = player
        logProp("ENTER " .. box.name .. " -> " .. player.Name)
    elseif not inside and playersInside[player.UserId] then
        playersInside[player.UserId] = nil
        logProp("EXIT " .. box.name .. " -> " .. player.Name)
    end
end

local function scanBox(box)
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        updateBoxPresence(box, player, seen)
    end
    for userId, player in pairs(state.propInside[box.name]) do
        if not seen[userId] then
            state.propInside[box.name][userId] = nil
            logProp("EXIT " .. box.name .. " -> " .. player.Name)
        end
    end
end

local function monitorLoop()
    while state.propRunning do
        for _, box in pairs(state.propBoxes) do
            scanBox(box)
        end
        updateMonitorGui()
        task.wait(monitor.pollInterval)
    end
end

local function startMonitor()
    if not monitor.enabled then
        return
    end
    if runtime.stopPropBoxes then
        pcall(runtime.stopPropBoxes)
    end

    clearMonitor()
    state.propFolder = Instance.new("Folder")
    state.propFolder.Name = STRINGS.monitorFolder
    state.propFolder.Parent = workspace

    for _, target in ipairs(resolvePropPads()) do
        if target.pad and target.pad:IsA("BasePart") then
            local box = createPropBox(target)
            state.propBoxes[target.index] = box
            state.propInside[box.name] = {}
            logProp("Watching " .. box.name)
        else
            warnHub("Missing " .. target.name)
        end
    end

    createMonitorGui()
    updateMonitorGui()
    state.propRunning = true
    runtime.propBoxActive = true
    runtime.stopPropBoxes = clearMonitor
    task.spawn(monitorLoop)
end

local runBias = Vector3.new(
    randomBetween(-2, 2),
    0,
    (math.random() < 0.5 and -1 or 1) * randomBetween(3, movement.pathJitter)
)

local function biasedTarget(target, distance)
    return target + runBias * math.clamp(distance / movement.pathJitterFade, 0, 1)
end

local function insideObstacle(position)
    local padding = movement.obstaclePad
    return position.X >= OBSTACLE.minX - padding
        and position.X <= OBSTACLE.maxX + padding
        and position.Z >= OBSTACLE.minZ - padding
        and position.Z <= OBSTACLE.maxZ + padding
end

local function segmentHitsObstacle(a, b)
    for sample = 0, movement.obstacleSamples do
        if insideObstacle(a:Lerp(b, sample / movement.obstacleSamples)) then
            return true
        end
    end
    return false
end

local function avoidObstacle(position, target)
    if not segmentHitsObstacle(position, target) then
        return target
    end
    return Vector3.new(movement.obstacleLeftX + randomBetween(-3, 3), target.Y, movement.obstacleBypassZ + randomBetween(-2, 2))
end

local function onFinalPlatform(position, target, distance)
    return state.humanoid
        and state.humanoid.FloorMaterial ~= Enum.Material.Air
        and position.Y >= movement.finalFloorY
        and distance <= movement.finalPlatformDistance
        and position.Z <= target.Z + 35
end

local function movementPhase(position, target, distance, tripState, startedAt)
    if tick() - startedAt < movement.warmup then
        return "warmup"
    end
    if tripState.stopJumping or onFinalPlatform(position, target, distance) then
        return "walkin"
    end
    if not tripState.crossed then
        return "approach"
    end
    if tripState.burstCount < movement.burstJumps then
        return "burst"
    end
    if position.Y < movement.climbTopY then
        return "climb"
    end
    return "cruise"
end

local function reached(position, target)
    return (position - target).Magnitude <= movement.reach and state.humanoid.FloorMaterial ~= Enum.Material.Air
end

local function createProgressState()
    return {
        startedAt = tick(),
        lastCheck = tick(),
        lastPosition = state.root.Position,
        stuckCount = 0,
    }
end

local function createTripState()
    local crossed = state.root.Position.Z <= TRIP_Z
    local stopJumping = state.root.Position.Z <= STOP_JUMP_Z
    return {
        crossed = crossed,
        stopJumping = stopJumping,
        burstCount = 0,
        nextBurst = 0,
        lastJump = 0,
        nextDash = 0,
        tripDashDone = crossed,
        postWallDashDone = stopJumping,
    }
end

local function updateTripState(position, tripState)
    if not tripState.crossed and position.Z <= TRIP_Z then
        tripState.crossed = true
        tripState.burstCount = 0
        tripState.nextBurst = 0
        tripState.tripDashDone = false
    end
    if not tripState.stopJumping and position.Z <= STOP_JUMP_Z then
        tripState.stopJumping = true
    end
end

local function moveForPhase(phase, target, position, direction)
    aimCamera(position, direction)
    if phase == "walkin" then
        releaseForward()
        state.humanoid:MoveTo(target)
        return
    end
    face(position, direction)
    holdForward()
    state.humanoid:Move(direction, false)
end

local function dashAllowed(phase, position, distance, tripState)
    if phase == "approach" then
        return math.max(0, position.Z - movement.preJumpZ) > movement.dashDistance and distance > movement.dashMinFlatDistance, "approach"
    end
    if tripState.crossed and tripState.burstCount >= movement.burstJumps and not tripState.stopJumping and phase ~= "walkin" and position.Y >= movement.climbTopY then
        return distance > movement.dashMinFlatDistance, "cruise"
    end
    if tripState.stopJumping and not tripState.postWallDashDone and state.humanoid.FloorMaterial ~= Enum.Material.Air then
        return distance > math.max(movement.walkInDistance, movement.reach + 8), "postwall"
    end
    return false, nil
end

local function handleDash(now, position, direction, distance, phase, tripState)
    local canDash, reason = dashAllowed(phase, position, distance, tripState)
    local mustTripDash = tripState.crossed and not tripState.stopJumping and not tripState.tripDashDone

    if (mustTripDash or canDash) and now >= tripState.nextDash then
        face(position, direction)
        holdForward()
        dash()
        tripState.nextDash = now + movement.dashCooldown + randomBetween(-movement.dashCooldownJitter, movement.dashCooldownJitter)
        tripState.tripDashDone = tripState.tripDashDone or mustTripDash

        if reason == "postwall" then
            tripState.postWallDashDone = true
            task.delay(movement.postWallReleaseDelay, function()
                if state.running then
                    releaseForward()
                end
            end)
        end
    end
end

local function handleJump(now, position, phase, tripState)
    if tripState.stopJumping then
        return
    end
    if tripState.crossed and tripState.burstCount < movement.burstJumps and now >= tripState.nextBurst then
        jump()
        tripState.burstCount += 1
        tripState.lastJump = now
        tripState.nextBurst = now + movement.burstJumpInterval
        return
    end
    if tripState.crossed and phase ~= "walkin" and position.Y < movement.climbTopY and now - tripState.lastJump >= movement.jumpCooldown then
        jump()
        tripState.lastJump = now
        return
    end
    if phase == "cruise" and position.Y < movement.cruiseFloorY and now - tripState.lastJump >= movement.jumpCooldown then
        jump()
        tripState.lastJump = now
    end
end

local function updateStuckRecovery(now, position, direction, distance, progress, shouldJump)
    if now - progress.lastCheck < movement.stuckCheckInterval then
        return false
    end

    local moved = (position - progress.lastPosition).Magnitude
    local stuck = now - progress.startedAt > movement.unstickStartTime and moved < movement.stuckMoveDistance and distance > movement.walkInDistance
    if stuck then
        progress.stuckCount += 1
        if shouldJump then
            jump()
        end
        local side = progress.stuckCount % 2 == 0 and movement.unstickSideForce or -movement.unstickSideForce
        local nudge = direction + Vector3.new(direction.Z, 0, -direction.X) * side
        if nudge.Magnitude > movement.minDirection then
            state.humanoid:Move(nudge.Unit, false)
        end
    else
        progress.stuckCount = 0
    end

    progress.lastPosition = position
    progress.lastCheck = now
    return progress.stuckCount >= movement.stuckLimit
end

local function parkourTo(target, label)
    refreshCharacter()
    setMoveTarget(label or "TARGET", target)
    setAutoRotate(false)
    if camera then
        camera.CameraSubject = state.humanoid
        camera.CameraType = Enum.CameraType.Scriptable
    end

    local progress = createProgressState()
    local tripState = createTripState()
    while state.running do
        RunService.Heartbeat:Wait()
        ensureCharacter()

        local now = tick()
        local position = state.root.Position
        local targetForSteering = biasedTarget(avoidObstacle(position, target), flatDistance(position, target))
        local direction, distance = flatDirection(position, targetForSteering)

        if reached(position, target) or now - progress.startedAt > movement.maxRunTime then
            break
        end

        updateTripState(position, tripState)
        local phase = movementPhase(position, target, distance, tripState, progress.startedAt)
        moveForPhase(phase, target, position, direction)
        handleDash(now, position, direction, distance, phase, tripState)
        handleJump(now, position, phase, tripState)

        local shouldJump = tripState.crossed and not tripState.stopJumping and now - tripState.lastJump >= movement.jumpCooldown
        if updateStuckRecovery(now, position, direction, distance, progress, shouldJump) then
            break
        end
    end

    releaseMovement()
    restoreAutoRotate()
    if camera then
        camera.CameraSubject = state.humanoid
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function walkTo(target, label, allowDash)
    refreshCharacter()
    setMoveTarget(label or "TARGET", target)
    setAutoRotate(true)

    local progress = createProgressState()
    local nextDash = 0
    while state.running do
        RunService.Heartbeat:Wait()
        ensureCharacter()

        local now = tick()
        local position = state.root.Position
        local direction, distance = flatDirection(position, target)
        if reached(position, target) or now - progress.startedAt > movement.maxRunTime then
            break
        end

        state.humanoid:MoveTo(target)
        if allowDash and distance >= movement.dashDistance and now >= nextDash then
            face(position, direction)
            dash()
            nextDash = now + movement.dashCooldown + randomBetween(-movement.dashCooldownJitter, movement.dashCooldownJitter)
        end

        if updateStuckRecovery(now, position, direction, distance, progress, false) then
            break
        end
    end
end

local function getPadTarget(padIndex)
    local box = state.propBoxes[padIndex]
    if box and box.pad then
        return box.pad.Position + Vector3.new(0, movement.padTargetYOffset, 0)
    end
    return PAD_POINTS[padIndex][1]
end

local function randomPadPoint(padIndex)
    local points = PAD_POINTS[padIndex] or PAD_POINTS[1]
    local index = math.random(1, #points)
    return points[index], index
end

local function initialPadPoint()
    local index = tonumber(hubConfig.initialPadPointIndex)
    if index and PAD_POINTS[1][index] then
        return PAD_POINTS[1][index], index
    end
    return randomPadPoint(1)
end

local function isTeamPlayer(player)
    return player and teamSet[player.Name] == true
end

local function teamCount()
    return math.max(#hubConfig.accounts, 1)
end

local function getDungeonLeaderName()
    return dungeon.leaderName or tostring(hubConfig.accounts[1])
end

local function canStartDungeon()
    return dungeon.startWhenTeamReady and (not dungeon.leaderOnly or localPlayer.Name == getDungeonLeaderName())
end

local function getDungeonDifficulty()
    local difficulty = tostring(dungeon.difficulty or "")
    if VALID_DIFFICULTIES[difficulty] then
        return difficulty
    end
    warnHub("Invalid hubconfig.dungeon.difficulty: " .. difficulty .. ". Using Normal.")
    return "Normal"
end

local function fireDungeonSetting(remote, settingName, settingValue)
    local ok, err = pcall(function()
        if settingValue == nil then
            remote:FireServer(settingName)
        else
            remote:FireServer(settingName, settingValue)
        end
    end)
    if not ok then
        warnHub("Failed to fire dungeon setting " .. tostring(settingName) .. ": " .. tostring(err))
    end
    return ok
end

local function startDungeonFromPad(padIndex)
    if runtime.startedDungeon or not canStartDungeon() then
        return
    end

    local remote = getDungeonSettingsRemote(padIndex)
    if not remote then
        warnHub("Dungeon settings remote missing for Pad " .. tostring(padIndex))
        return
    end

    local difficulty = getDungeonDifficulty()
    log("Starting dungeon from Pad " .. tostring(padIndex) .. " on " .. difficulty)

    if not fireDungeonSetting(remote, STRINGS.difficultySetting, difficulty) then
        return
    end

    task.wait(dungeon.startDelay)
    if fireDungeonSetting(remote, STRINGS.startSetting) then
        runtime.startedDungeon = true
    end
end

local function teamNearPadCount(padIndex)
    local count = 0
    local target = getPadTarget(padIndex)
    for _, name in ipairs(hubConfig.accounts) do
        local player = Players:FindFirstChild(tostring(name))
        local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and flatDistance(root.Position, target) <= coordination.teamStageRadius then
            count += 1
        end
    end
    return count
end

local function teamOnPadCount(padIndex)
    local box = state.propBoxes[padIndex]
    local players = box and state.propInside[box.name] or {}
    local count = 0
    for _, player in pairs(players) do
        if isTeamPlayer(player) then
            count += 1
        end
    end
    return count
end

local function ignoreNoEnergy(player, statusCount, padIndex, location)
    if state.noEnergyIgnored[player.UserId] then
        return true
    end
    if statusCount == 0 then
        state.noEnergyIgnored[player.UserId] = true
        log("Ignoring no-energy player " .. location .. " Pad " .. padIndex .. ": " .. player.Name)
        return true
    end
    return false
end

local function randomInTrackedPad(padIndex, statusCount)
    local box = state.propBoxes[padIndex]
    local players = box and state.propInside[box.name] or {}
    for _, player in pairs(players) do
        if not isTeamPlayer(player) and not ignoreNoEnergy(player, statusCount, padIndex, "on") then
            return true, player.Name
        end
    end
    return false, nil
end

local function randomNearPad(padIndex, statusCount)
    local target = getPadTarget(padIndex)
    for _, player in ipairs(Players:GetPlayers()) do
        if not isTeamPlayer(player) then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local near = root
                and flatDistance(root.Position, target) <= coordination.onPadRadius
                and math.abs(root.Position.Y - target.Y) <= movement.padNearYRange
            if near and not ignoreNoEnergy(player, statusCount, padIndex, "near") then
                return true, player.Name
            end
        end
    end
    return false, nil
end

local function randomBlockingPad(padIndex)
    local statusCount = getStatusCount(padIndex)
    local tracked, trackedName = randomInTrackedPad(padIndex, statusCount)
    if tracked then
        return true, trackedName
    end

    local nearby, nearbyName = randomNearPad(padIndex, statusCount)
    if nearby then
        return true, nearbyName
    end

    local teamOn = teamOnPadCount(padIndex)
    if statusCount and teamOn >= teamCount() and statusCount > teamOn then
        return true, "status " .. tostring(statusCount) .. "/4"
    end
    return false, nil
end

local function teamFullyOnPad(padIndex)
    if teamOnPadCount(padIndex) >= teamCount() then
        return true
    end
    -- Fallback: the pad's own status reads a full team and no random is in/near it.
    -- This covers cases where the prop-box presence check undercounts even though
    -- every team account is actually standing on the pad (status shows 4/4).
    local statusCount = getStatusCount(padIndex)
    if statusCount and statusCount >= teamCount() and teamOnPadCount(padIndex) >= 1 then
        local tracked = randomInTrackedPad(padIndex, statusCount)
        local nearby = randomNearPad(padIndex, statusCount)
        if not tracked and not nearby then
            return true
        end
    end
    return false
end

local function waitForCoordEnabled()
    while state.running and not state.coordEnabled do
        task.wait(0.5)
    end
    return state.running
end

local function waitForTeamNearPad(padIndex)
    while state.running do
        if not state.coordEnabled then
            return true
        end
        local count = teamNearPadCount(padIndex)
        if count >= teamCount() then
            return true
        end
        setCoordStatus("Pad " .. padIndex .. " team " .. count .. "/" .. teamCount())
        task.wait(1)
    end
    return false
end

local function padClearLongEnough(padIndex, clearSince)
    if getStatusCount(padIndex) ~= 0 or teamOnPadCount(padIndex) ~= 0 or randomBlockingPad(padIndex) then
        return false, nil
    end
    local startedAt = clearSince or tick()
    return tick() - startedAt >= coordination.padClearStableTime, startedAt
end

local function waitForPadClear(padIndex, timeout)
    local startedAt = tick()
    local clearSince = nil
    while state.running do
        if not state.coordEnabled then
            return true, "paused"
        end

        local isClear, newClearSince = padClearLongEnough(padIndex, clearSince)
        if isClear then
            setCoordStatus("Pad " .. padIndex .. " ready")
            return true, "clear"
        end

        local switchIn = timeout and math.max(0, timeout - (tick() - startedAt)) or 0
        local hasRandom, who = randomBlockingPad(padIndex)
        if newClearSince then
            clearSince = newClearSince
            setCoordStatus(string.format("Pad %d clear %.1fs/%.1fs", padIndex, tick() - clearSince, coordination.padClearStableTime))
        elseif hasRandom then
            clearSince = nil
            setCoordStatus("Pad " .. padIndex .. " random: " .. tostring(who) .. " switch " .. string.format("%.1fs", switchIn))
        else
            clearSince = nil
            setCoordStatus("Pad " .. padIndex .. " busy " .. getStatusText(padIndex) .. " switch " .. string.format("%.1fs", switchIn))
        end

        if timeout and tick() - startedAt >= timeout then
            return false, "busy timeout"
        end
        task.wait(coordination.waitPoll)
    end
    return false, "stopped"
end

local function emptyAlternatePad(currentPad)
    for _, padIndex in ipairs(ALTERNATE_ORDER[currentPad] or { 1, 2, 3 }) do
        if padIndex ~= currentPad and getStatusCount(padIndex) == 0 and not randomBlockingPad(padIndex) then
            return padIndex
        end
    end
    return nil
end

local function moveToPadStage(padIndex, label)
    local point, pointIndex = randomPadPoint(padIndex)
    walkTo(point, label .. " P" .. padIndex .. " " .. pointIndex, true)
    lookAtPoint(getPadTarget(padIndex))
end

local function bailFromPad(padIndex, reason)
    log("Bailing from Pad " .. padIndex .. ": " .. tostring(reason))
    moveToPadStage(padIndex, "BAIL")
end

local function waitWhileTeamHoldsPad(padIndex)
    while state.running do
        if not state.coordEnabled then
            bailFromPad(padIndex, "coord stopped")
            return
        end

        if teamOnPadCount(padIndex) < teamCount() then
            log("Team moved off Pad " .. padIndex)
            return
        end
        task.wait(coordination.waitPoll)
    end
end

local function waitForTeamOnPad(padIndex)
    local deadline = tick() + coordination.teamOnPadTimeout
    while state.running do
        if not state.coordEnabled then
            bailFromPad(padIndex, "coord stopped")
            return
        end

        if teamFullyOnPad(padIndex) then
            log("Team on Pad " .. padIndex .. ": " .. teamOnPadCount(padIndex) .. "/4")
            startDungeonFromPad(padIndex)
            waitWhileTeamHoldsPad(padIndex)
            return
        end

        local hasRandom, who = randomBlockingPad(padIndex)
        if hasRandom then
            bailFromPad(padIndex, who)
            return
        end

        if tick() >= deadline then
            bailFromPad(padIndex, "team timeout")
            return
        end
        task.wait(coordination.waitPoll)
    end
end

local function preparePad(padIndex)
    if teamOnPadCount(padIndex) > 0 and not randomBlockingPad(padIndex) then
        return padIndex
    end

    local clear, reason = waitForPadClear(padIndex, coordination.padBusySwitchTime)
    if clear then
        return padIndex
    end

    local alternate = emptyAlternatePad(padIndex)
    if alternate then
        log("Switching Pad " .. padIndex .. " -> Pad " .. alternate)
        setCoordStatus("Switching P" .. padIndex .. " -> P" .. alternate)
        moveToPadStage(alternate, "WAIT")
        return alternate
    end

    setCoordStatus("No empty alternate")
    moveToPadStage(padIndex, "WAIT")
    return padIndex, reason
end

local function enterPad(padIndex)
    log("Walking onto Pad " .. padIndex .. " (" .. getStatusText(padIndex) .. ")")
    lookAtPoint(getPadTarget(padIndex))
    walkTo(getPadTarget(padIndex), "PAD " .. padIndex, true)
    waitForTeamOnPad(padIndex)
end

local function coordinatePads(startPad)
    if teamCount() < 2 then
        warnHub("hubconfig.accounts only has " .. teamCount() .. " account(s)")
    end

    local currentPad = startPad
    while state.running do
        if not waitForCoordEnabled() or not waitForTeamNearPad(currentPad) or not waitForCoordEnabled() then
            break
        end

        currentPad = preparePad(currentPad)
        if waitForCoordEnabled() then
            enterPad(currentPad)
        end
    end
end

local function cleanup(keepVisualizer, keepMonitor)
    state.running = false
    releaseMovement()
    if not keepVisualizer then
        clearVisualizer()
    end
    if not keepMonitor then
        clearMonitor()
    end
    if state.humanoid then
        state.humanoid:Move(Vector3.new(0, 0, 0), false)
        state.humanoid.CameraOffset = Vector3.new(0, 0, 0)
    end
    restoreAutoRotate()
    if camera then
        camera.CameraSubject = state.humanoid
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function initialBypassPoint()
    return Vector3.new(
        movement.obstacleLeftX + randomBetween(movement.initialBypassXJitterMin, movement.initialBypassXJitterMax),
        movement.initialBypassY,
        movement.initialBypassZ + randomBetween(-movement.initialBypassZJitter, movement.initialBypassZJitter)
    )
end

local function moveToInitialStage()
    local target, pointIndex = initialPadPoint()
    local bypass = initialBypassPoint()
    log("Moving to P1 point " .. pointIndex)
    buildVisualizer({ bypass, target }, { "BYPASS", "P1 " .. pointIndex })

    if state.root.Position.Z > STOP_JUMP_Z then
        parkourTo(bypass, "BYPASS")
    else
        walkTo(bypass, "BYPASS", false)
    end

    if state.running then
        walkTo(target, "P1 " .. pointIndex, false)
        lookAtPoint(getPadTarget(1))
    end
end

local function run()
    refreshCharacter()
    startMonitor()
    moveToInitialStage()
    if state.running then
        coordinatePads(1)
    end
    runtime.done = true
    log("Done")
end

if runtime.stop then
    pcall(runtime.stop)
end
task.wait(0.1)
runtime.stop = cleanup

task.spawn(run)
