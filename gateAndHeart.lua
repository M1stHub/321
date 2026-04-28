local HttpService = game:GetService("HttpService")

local function SendWebhook(content, title, color, webhookUrl)
	local timestamp = "<t:" .. os.time() .. ":t>"
	local embed = {
		title = title,
		color = color,
		footer = {
			text = timestamp
		},
	}
	local payload = {
		embeds = {
			embed
		}
	}
	if content then
		payload.content = content
	end
	pcall(function()
		(http_request or request)({
			Url = webhookUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)
end

local heartWebhookUrl = getgenv().notiWebhook or ""
local gateWebhookUrl  = getgenv().notiWebhook or ""

local isGateDetected = false

task.spawn(function()
	while true do
		local doorLeft = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("LeviathanGate") and workspace.Map.LeviathanGate:FindFirstChild("DOORLEFT")
		if doorLeft and not isGateDetected then
			SendWebhook("@everyone", "Frozen Dimension Found", 255, gateWebhookUrl)
			isGateDetected = true
		elseif not doorLeft then
			isGateDetected = false
		end
		task.wait(10)
	end
end)

while true do
	task.wait(1)
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
		task.wait(0.1)
		seatWait = seatWait + 0.1
	until seatUsed or seatWait > 120
	if not seatUsed then
		continue
	end
	task.wait(1)
	local heartFound = false
	if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("FrozenHeart") then
		heartFound = true
	end
	if heartFound then
		SendWebhook(nil, "Got Heart", 65280, heartWebhookUrl)
	else
		SendWebhook(nil, "Missed Heart", 16711680, heartWebhookUrl)
	end
	task.wait(5)
end
