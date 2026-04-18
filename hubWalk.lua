local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local cfg = getgenv().DungeonBotConfig or {}
local ALLOWED_ACCOUNTS = cfg.allowedAccounts or {
    "1",
    "2",
    "3",
    "4",
}
local NEAR_RADIUS = cfg.nearRadius or 50
local REACH_DIST  = cfg.reachDist  or 5
local BAIL_SWITCH_LIMIT = cfg.bailSwitchLimit or 3

local PAD_CONFIGS = {
    {
        name = "DUNGEON_TELEPORTER3",
        object = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER3,
        walkOnPositions = {
            CFrame.new(-373.536316, 235.687775, -455.370514, 0.974182844, 1.05044293e-07, -0.22576046, -9.23628249e-08, 1, 6.67345219e-08, 0.22576046, -4.4159755e-08, 0.974182844),
            CFrame.new(-383.009399, 235.68779, -449.414764, -0.205830127, -1.12180658e-07, 0.978587747, -2.78042318e-08, 1, 1.08787091e-07, -0.978587747, -4.81721951e-09, -0.205830127),
            CFrame.new(-375.76712, 235.68779, -445.878906, -0.960089564, -2.97983629e-08, -0.279692799, -2.14198881e-09, 1, -9.91869058e-08, 0.279692799, -9.46292147e-08, -0.960089564),
            CFrame.new(-380.974976, 235.68779, -442.194275, -0.893374443, 6.62406734e-08, 0.449312955, 3.52165976e-08, 1, -7.74049909e-08, -0.449312955, -5.33283639e-08, -0.893374443),
            CFrame.new(-384.293945, 235.68779, -435.973175, -0.774265766, -7.97903283e-07, 0.632860601, 5.30492628e-07, 1, 1.90981314e-06, -0.632860601, 1.81443079e-06, -0.774265766),
            CFrame.new(-391.718506, 235.68779, -429.641815, -0.666306913, -6.01425398e-08, 0.74567759, -1.84832194e-09, 1, 7.90032928e-08, -0.74567759, 5.12621909e-08, -0.666306913),
            CFrame.new(-391.567871, 235.68779, -439.324554, 0.81830442, -1.10868768e-06, 0.574785054, 1.15987135e-07, 1, 1.76374613e-06, -0.574785054, -1.37661368e-06, 0.81830442),
            CFrame.new(-382.163696, 235.687805, -431.758423, -0.215178594, -4.08859114e-06, -0.976574719, 4.18149369e-07, 1, -4.27880013e-06, 0.976574719, -1.32906086e-06, -0.215178594),
            CFrame.new(-376.100769, 235.687775, -425.211212, -0.694819093, -1.97906174e-05, -0.719184518, -1.29647435e-06, 1, -2.62655849e-05, 0.719184518, -1.73174267e-05, -0.694819093),
            CFrame.new(-369.816559, 235.687775, -435.111359, 0.809042692, -6.80446846e-08, -0.587749839, 2.56687436e-08, 1, -8.04382623e-08, 0.587749839, 4.99911899e-08, 0.809042692),
            CFrame.new(-369.775513, 235.687775, -427.462738, -0.70772171, -2.46831278e-05, -0.706491351, -2.06037316e-06, 1, -3.28736605e-05, 0.706491351, -2.18097648e-05, -0.70772171),
            CFrame.new(-361.183899, 235.687775, -424.382416, -0.368807167, -1.07619535e-07, -0.929505944, -1.26708635e-08, 1, -1.1075393e-07, 0.929505944, -2.90691986e-08, -0.368807167),
            CFrame.new(-361.023804, 235.687775, -434.110687, 0.859865248, -3.47039588e-08, -0.510521114, -1.17129417e-08, 1, -8.77055015e-08, 0.510521114, 8.13946173e-08, 0.859865248),
            CFrame.new(-351.341248, 235.687775, -425.077057, -0.30787769, -9.12572716e-07, -0.95142597, -2.51087879e-08, 1, -9.51038032e-07, 0.95142597, -2.68914249e-07, -0.30787769),
            CFrame.new(-346.240479, 235.6194, -420.217529, -0.624623358, 3.31570732e-07, -0.780926168, 1.66260641e-08, 1, 4.1128817e-07, 0.780926168, 2.43916475e-07, -0.624623358),
            CFrame.new(-338.535736, 235.687744, -427.795197, 0.696491778, -1.14933449e-07, -0.717564762, 1.35142972e-08, 1, -1.47054109e-07, 0.717564762, 9.27245978e-08, 0.696491778),
            CFrame.new(-346.798767, 235.687775, -435.253265, 0.973793805, -8.66484271e-08, 0.227432624, 8.78797923e-09, 1, 3.43357755e-07, -0.227432624, -3.32360969e-07, 0.973793805),
            CFrame.new(-336.715332, 235.687561, -439.561066, 0.866617262, 5.54924895e-07, -0.498973459, -2.08032631e-07, 1, 7.50821926e-07, 0.498973459, -5.46872457e-07, 0.866617262),
            CFrame.new(-336.608643, 235.687744, -445.879242, 0.981031597, -7.50339041e-07, -0.19384779, 7.10915913e-08, 1, -3.51098083e-06, 0.19384779, 3.43060219e-06, 0.981031597),
            CFrame.new(-341.642303, 235.687744, -452.78244, 0.409446508, 0.000127352148, 0.912334144, 2.58194268e-05, 1, -0.000151176879, -0.912334144, 8.54547834e-05, 0.409446478),
            CFrame.new(-343.439667, 235.687775, -448.234009, -0.451188445, 7.15424612e-05, 0.892428696, 7.41262284e-06, 1, -7.64184006e-05, -0.892428696, -2.78638636e-05, -0.451188445),
        },
    },
    {
        name = "DUNGEON_TELEPORTER2",
        object = workspace.Map["Simulation Hub"].Pads.DUNGEON_TELEPORTER2,
        transitPos = CFrame.new(-299.870087, 235.687744, -375.938843, -0.813491344, 5.11981924e-08, -0.581577003, -4.5274704e-09, 1, 9.43662641e-08, 0.581577003, 7.93992143e-08, -0.813491344),
        walkOnPositions = {
            CFrame.new(-248.91507, 235.687744, -440.81955, 0.933903337, 5.09446814e-08, -0.357525647, -3.43950965e-08, 1, 5.2647934e-08, 0.357525647, -3.68709507e-08, 0.933903337),
            CFrame.new(-254.512268, 235.687729, -441.686249, 0.835766435, -1.14334273e-06, 0.54908514, -1.18878923e-07, 1, 2.26321504e-06, -0.54908514, -1.95679377e-06, 0.835766435),
            CFrame.new(-255.266891, 235.687744, -436.881165, -0.380847961, 0.000106389445, 0.924637675, 1.31923789e-05, 1, -0.00010962689, -0.924637675, -2.95530081e-05, -0.380847961),
            CFrame.new(-255.803787, 235.687729, -433.409058, -0.593941867, -1.05435454e-07, 0.804507971, -6.78571794e-08, 1, 8.09590901e-08, -0.804507971, -6.50665033e-09, -0.593941867),
            CFrame.new(-251.006348, 235.687729, -432.665955, -0.982822299, 5.59270497e-08, -0.184554517, 3.8444913e-08, 1, 9.83044615e-08, 0.184554517, 8.95206327e-08, -0.982822299),
            CFrame.new(-259.075928, 235.687729, -425.92981, -0.768554568, 3.90257264e-06, 0.639784217, -1.92217584e-07, 1, -6.33073205e-06, -0.639784217, -4.98849113e-06, -0.768554568),
            CFrame.new(-261.994141, 235.490417, -418.726227, -0.99447298, 1.85473473e-05, 0.104992628, 1.0177625e-05, 1, -8.02530121e-05, -0.104992628, -7.87408717e-05, -0.99447298),
            CFrame.new(-253.772583, 235.670502, -426.785767, 0.729327381, -2.81402445e-05, -0.684164882, 2.81713506e-06, 1, -3.81276986e-05, 0.684164882, 2.58801902e-05, 0.729327381),
            CFrame.new(-253.880203, 235.687714, -426.038147, -0.403978705, -0.000177882321, -0.914768398, -3.05313661e-05, 1, -0.0001809729, 0.914768398, -4.51800697e-05, -0.403978705),
            CFrame.new(-254.797958, 235.444702, -418.802368, -0.915819883, -6.26693554e-06, -0.401589304, -5.33165974e-07, 1, -1.43894558e-05, 0.401589304, -1.29640357e-05, -0.915819883),
            CFrame.new(-245.311188, 235.028137, -414.82486, -0.429487735, -8.03898092e-06, -0.903072715, 3.25165132e-07, 1, -9.05645265e-06, 0.903072715, -4.18328316e-06, -0.429487735),
            CFrame.new(-238.487976, 235.62619, -420.544434, 0.335911512, -8.81283777e-05, -0.941893578, -8.57973737e-06, 1, -9.66249427e-05, 0.941893578, 4.05386309e-05, 0.335911483),
            CFrame.new(-239.27298, 235.021912, -410.32254, -0.891388834, 4.287933e-07, -0.453239352, 3.16858092e-07, 1, 3.2289654e-07, 0.453239352, 1.44213786e-07, -0.891388834),
            CFrame.new(-226.639359, 235.028885, -411.732666, 0.312105417, -7.82706775e-05, -0.950047493, 8.11711016e-06, 1, -7.97194734e-05, 0.950047493, 1.71692391e-05, 0.312105417),
            CFrame.new(-227.486786, 235.028915, -403.358856, -0.941551685, -1.01873675e-05, -0.336868554, -1.50271751e-06, 1, -2.60412598e-05, 0.336868554, -2.40129739e-05, -0.941551685),
            CFrame.new(-220.032196, 235.028915, -402.783539, 0.0501562059, -0.000112179368, -0.998741388, 1.35745777e-05, 1, -0.000111639027, 0.998741388, -7.95810223e-06, 0.0501562059),
            CFrame.new(-214.330811, 235.028915, -411.375885, 0.601480603, -8.93175667e-08, -0.798887432, 1.58376101e-09, 1, -1.10610038e-07, 0.798887432, 6.5264544e-08, 0.601480603),
            CFrame.new(-213.597504, 235.028915, -419.066162, 0.953725696, -4.02727437e-06, -0.300678104, 5.02231956e-07, 1, -1.18009357e-05, 0.300678104, 1.11038453e-05, 0.953725696),
            CFrame.new(-214.139236, 235.687698, -427.490753, 0.561667264, 4.61876043e-05, 0.827363193, 4.56668113e-06, 1, -5.89252195e-05, -0.827363193, 3.68746732e-05, 0.561667264),
            CFrame.new(-214.654755, 235.687729, -433.709045, 0.954535544, -1.79732979e-05, -0.298097134, -1.61145708e-05, 1, -0.000111893823, 0.298097134, 0.000111610345, 0.954535544),
            CFrame.new(-207.915009, 235.687729, -426.306641, -0.605176628, -4.08374144e-05, -0.796091199, -4.15634395e-06, 1, -4.81378156e-05, 0.796091199, -2.58230539e-05, -0.605176628),
            CFrame.new(-217.196594, 235.649307, -422.850311, 0.0830424726, 2.14654574e-05, 0.99654603, -1.21406072e-06, 1, -2.14386873e-05, -0.99654603, 5.70454233e-07, 0.0830424726),
            CFrame.new(-224.864838, 236.335052, -421.47583, -0.413344592, 3.81857972e-05, 0.910574675, 3.47363448e-06, 1, -4.03591148e-05, -0.910574675, -1.35192176e-05, -0.413344592),
        },
    },
}
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
    local padBlacklist = {}
    local padIdx = 1
    local bailCount = 0

    local function currentPad() return PAD_CONFIGS[padIdx] end

    setCoordStatus("Waiting nearby", Color3.fromRGB(200, 160, 50))
    log("Waiting for all " .. total .. " accs nearby...")

    while running do
        local n = getNearbyCount(currentPad().name)
        guiNearby.Text = n .. "/" .. total
        guiOnPad.Text  = currentPad().object:GetAttribute("NumPlayersOnPad") or "?"
        if n >= total then break end
        task.wait(0.5)
    end

    if not running then stopPipeline(); return end
    log("All accounts nearby — using " .. currentPad().name)

    while running do
        local pad = currentPad()

        setCoordStatus("Waiting pad=0", Color3.fromRGB(200, 160, 50))
        while running do
            local c = pad.object:GetAttribute("NumPlayersOnPad") or 0
            guiOnPad.Text = c .. "/" .. total
            if c == 0 then
                local t = allPlayersInside[pad.name]
                if t then for k in pairs(t) do t[k] = nil end end
                break
            end
            task.wait(0.3)
        end
        if not running then break end

        log("Pad empty — walking on " .. pad.name)
        setCoordStatus("Walking on", Color3.fromRGB(100, 180, 255))
        if pad.transitPos then
            walkTo(pad.transitPos.Position)
            if not running then break end
        end
        local walkOnCF = pad.walkOnPositions[math.random(#pad.walkOnPositions)]
        walkTo(walkOnCF.Position)
        if not running then break end

        setCoordStatus("On pad", Color3.fromRGB(80, 220, 120))
        local bailed = false
        local allOursConfirmed = false

        while running do
            local padCount = pad.object:GetAttribute("NumPlayersOnPad") or 0
            local oursOnly = onlyOursOnPad(pad.name)
            local realRandom = false
            for name in pairs(allPlayersInside[pad.name] or {}) do
                if not table.find(ALLOWED_ACCOUNTS, name) and not padBlacklist[name] then
                    realRandom = true; break
                end
            end
            local hasRandom = padCount > 0 and not oursOnly and realRandom
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
            bailCount += 1
            log("Waiting for pad to clear... (" .. bailCount .. "/" .. BAIL_SWITCH_LIMIT .. ")")
            task.wait(3)
            local c = pad.object:GetAttribute("NumPlayersOnPad") or 0
            if c == 0 then
                for name in pairs(allPlayersInside[pad.name] or {}) do
                    if not table.find(ALLOWED_ACCOUNTS, name) and not padBlacklist[name] then
                        padBlacklist[name] = true
                        log("Blacklisted " .. name .. " (pad still 0, no energy)")
                    end
                end
            end
            if bailCount >= BAIL_SWITCH_LIMIT then
                padIdx = padIdx % #PAD_CONFIGS + 1
                bailCount = 0
                padBlacklist = {}
                log("Switching to " .. currentPad().name)
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
