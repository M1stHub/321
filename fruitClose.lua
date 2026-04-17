repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function tryClose()
    local gui = player.PlayerGui:FindFirstChild("SpinnerWindow")
    if not gui then return end

    local aboveSpinner = gui:FindFirstChild("AboveSpinner")
    if not aboveSpinner then return end

    local nav = aboveSpinner:FindFirstChild("Navigation")
    if not nav then return end

    local closeButton = nav:FindFirstChild("CloseButton")
    if not closeButton then return end

    local conns = getconnections(closeButton.Activated)
    if conns[1] then
        conns[1]:Fire()
    end
end

while true do
    tryClose()
    task.wait(0.5)
end
