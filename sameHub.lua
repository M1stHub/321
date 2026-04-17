local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local cfg = getgenv().SameHubConfig or {}
local MAIN_USERID = cfg.mainUserId
local HUB_WALK_URL = cfg.hubWalkUrl

if not MAIN_USERID then
    warn("[SameHub] SameHubConfig.mainUserId not set")
    return
end
if not HUB_WALK_URL then
    warn("[SameHub] SameHubConfig.hubWalkUrl not set")
    return
end

local function executeMain()
    loadstring(game:HttpGet(HUB_WALK_URL))()
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
