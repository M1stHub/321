repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerGui

local cfg         = getgenv().DungeonConfig or {}
local LocalPlayer = game:GetService("Players").LocalPlayer

local function mainScript()
    getgenv().Config = {
        ["Auto Attack Dungeon"]      = true,
        ["Select Weapon Dungeon"]    = "Melee",
        ["Auto Store Fruit"]         = true,
        ["Random Devil Fruit"]       = true,
        ["Auto Turn On V4"]          = true,
        ["Auto Turn On Observation"] = true,
        ["Auto Turn On Buso"]        = true,
        ["Auto Turn On V3"]          = true,
        ["Boost Fps"]                = true,
    }
    getgenv().Key = cfg.key or ""
    loadstring(game:HttpGet(cfg.scriptUrl))()
end

local function autoPickCard()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/M1stHub/321/refs/heads/main/pickcard.lua"))()
end

local function autoSkipDungeon()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    while true do
        local gui = pg:FindFirstChild("ReturningToHubShortly")
        local btn = gui and gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Frame") and gui.Frame.Frame:FindFirstChild("2")
        if btn and btn:IsA("TextButton") and btn.Visible and btn.AbsoluteSize.X > 0 then
            pcall(firesignal, btn.Activated)
        end
        task.wait(0.5)
    end
end

task.spawn(autoSkipDungeon)

task.spawn(autoPickCard)
task.wait(1)
mainScript()