local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local cfg = getgenv().SameHubConfig or {}
local MAIN_USERID = cfg.mainUserId
local SCRIPT_URL = cfg.scriptUrl or cfg.hubParkourUrl or cfg.hubWalkUrl
local ALLOWED_ACCOUNTS = cfg.allowedAccounts

if not MAIN_USERID then
    warn("[SameHub] SameHubConfig.mainUserId not set")
    return
end
if not SCRIPT_URL then
    warn("[SameHub] SameHubConfig.scriptUrl (or hubParkourUrl / hubWalkUrl) not set")
    return
end
if ALLOWED_ACCOUNTS and not table.find(ALLOWED_ACCOUNTS, LocalPlayer.Name) then
    warn("[SameHub] " .. LocalPlayer.Name .. " not in allowedAccounts")
    return
end

local function executeMain()
    local ok, err = pcall(function() loadstring(game:HttpGet(SCRIPT_URL))() end)
    if not ok then warn("[SameHub] script error: " .. tostring(err)) end
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

local function countPresent()
    local present = 0
    for _, name in ipairs(ALLOWED_ACCOUNTS or {}) do
        local p = Players:FindFirstChild(name)
        local ch = p and p.Character
        if ch and ch:FindFirstChild("HumanoidRootPart") then
            present += 1
        end
    end
    return present
end

local function waitForAllAccounts()
    if not ALLOWED_ACCOUNTS or #ALLOWED_ACCOUNTS == 0 then return end
    local total = #ALLOWED_ACCOUNTS
    local elapsed = 0
    while true do
        local present = countPresent()
        if present >= total then
            print(("[SameHub] All %d accounts present, executing"):format(total))
            return
        end
        if elapsed % 3 == 0 then
            print(("[SameHub] Waiting for all accounts in lobby... (%d/%d)"):format(present, total))
        end
        task.wait(1)
        elapsed += 1
    end
end

if LocalPlayer.UserId == MAIN_USERID then
    print("[SameHub] This is the main account")
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
end

waitForAllAccounts()
executeMain()
