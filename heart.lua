local currentUserId = game.Players.LocalPlayer.UserId
local webhookUrl = getgenv().heartConfig.Users[currentUserId]

if webhookUrl then
    local HttpService = game:GetService("HttpService")
    local function SendHeartWebhook(title, webhookUrl)
        local timestamp = os.date("%H:%M:%S")
        local embed = {
            title = title,
            color = 255,
            footer = { text = timestamp },
        }

        pcall(function()
            (http_request or request)({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ content = "", embeds = { embed } }),
            })
        end)
    end
    
    while true do
        local heart
        local heartWait = 0
        while not heart and heartWait < 60 do
            task.wait(1)
            heartWait = heartWait + 1
            if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("FrozenHeart") then
                heart = workspace.Map.FrozenHeart
            end
        end
        
        if not heart then
            continue
        end
        
        local boat = workspace:FindFirstChild("Boats") and workspace.Boats:FindFirstChild("Beast Hunter")
        if not boat then
            continue
        end
        
        local seatUsed = false
        local connections = {}
        for i, cannon in ipairs(boat:GetChildren()) do
            local seat = cannon:FindFirstChild("Seat")
            if seat then
                connections[i] = seat.ChildAdded:Connect(function(child)
                    if child.Name == "SeatWeld" and not seatUsed then
                        seatUsed = true
                        for _, c in ipairs(connections) do
                            c:Disconnect()
                        end
                    end
                end)
            end
        end

        local seatWait = 0
        repeat 
            task.wait(2)
            seatWait = seatWait + 0.1
        until seatUsed or seatWait > 120

        if not seatUsed then
            continue
        end

        local heartFound = false
        if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("FrozenHeart") then
            heartFound = true
        end

        if heartFound then
            SendHeartWebhook("Got Heart", webhookUrl)
        else
            SendHeartWebhook("Missed Heart", webhookUrl)
        end

        local heartGone = false
        local heartGoneWait = 0
        while not heartGone and heartGoneWait < 300 do
            task.wait(2)
            heartGoneWait = heartGoneWait + 0.5
            if not (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("FrozenHeart")) then
                heartGone = true
            end
        end
    end
end 
