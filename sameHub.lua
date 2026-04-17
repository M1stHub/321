local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local cfg = getgenv().SameHubConfig or {}
local MAIN_USERID = cfg.mainUserId

if not MAIN_USERID then
    warn("[SameHub] SameHubConfig.mainUserId not set")
    return
end

local function executeMain()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/M1stHub/321/refs/heads/main/pathwalk.lua"))()
end

local function waitForMainInLobby()
    while true do
        if Players:GetPlayerByUserId(MAIN_USERID) then return end
        task.wait(1)
    end
end

if LocalPlayer.UserId == MAIN_USERID then
    executeMain()
else
    if not Players:GetPlayerByUserId(MAIN_USERID) then
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("JoinPlayerFromProfile"):FireServer(MAIN_USERID)
        waitForMainInLobby()
    end
    executeMain()
end
