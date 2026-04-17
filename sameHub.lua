local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local cfg = getgenv().SameHubConfig or {}
local MAIN_USERID = cfg.mainUserId
local HUB_WALK_URL = cfg.hubWalkUrl
local ALLOWED_ACCOUNTS = cfg.allowedAccounts

if not MAIN_USERID then
    warn("[SameHub] SameHubConfig.mainUserId not set")
    return
end
if not HUB_WALK_URL then
    warn("[SameHub] SameHubConfig.hubWalkUrl not set")
    return
end
if ALLOWED_ACCOUNTS and not table.find(ALLOWED_ACCOUNTS, LocalPlayer.Name) then
    warn("[SameHub] " .. LocalPlayer.Name .. " not in allowedAccounts")
    return
end

local function executeMain()
    loadstring(game:HttpGet(HUB_WALK_URL))()
end

local function waitForMainInLobby()
    local elapsed = 0
    while true do
        if Players:GetPlayerByUserId(MAIN_USERID) then
            print("[SameHub] Main account found in lobby, proceeding")
            return
        end
        if elapsed % 5 == 0 then
            print("[SameHub] Waiting for main account in lobby... (" .. elapsed .. "s)")
        end
        task.wait(1)
        elapsed += 1
    end
end

if LocalPlayer.UserId == MAIN_USERID then
    print("[SameHub] This is the main account, executing hubWalk directly")
    executeMain()
else
    print("[SameHub] Alt account, checking if main is in lobby...")
    if not Players:GetPlayerByUserId(MAIN_USERID) then
        print("[SameHub] Main not found, firing JoinPlayerFromProfile...")
        local ok, err = pcall(function()
            ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("JoinPlayerFromProfile", 5):FireServer(MAIN_USERID)
        end)
        if not ok then
            warn("[SameHub] JoinPlayerFromProfile failed: " .. tostring(err))
        end
        waitForMainInLobby()
    end
    executeMain()
end
