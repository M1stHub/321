local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")

-- Sends one Discord embed to the configured webhook.
local function SendWebhook(content, title, color, webhookUrl)
	local payload = {
		embeds = {
			{
				title  = title,
				color  = color,
				footer = { text = "<t:" .. os.time() .. ":t>" },
			}
		}
	}
	if content then
		payload.content = content
	end
	pcall(function()
		(http_request or request)({
			Url     = webhookUrl,
			Method  = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body    = HttpService:JSONEncode(payload),
		})
	end)
end

-- Disconnects all temporary seat listeners once the script knows what happened.
local function disconnectAll(connections)
	for _, c in pairs(connections) do
		c:Disconnect()
	end
end

-- Finds an object inside workspace.Map without erroring if part of the path is
-- missing.
local function findInMap(...)
	local node = workspace:FindFirstChild("Map")
	for _, name in ipairs({...}) do
		if not node then return nil end
		node = node:FindFirstChild(name)
	end
	return node
end

-- Only the chosen notification account is allowed to send webhook messages.
if Players.LocalPlayer.UserId ~= getgenv().notiAcc then return end

-- Changes FPS only for the notification account. Some executors may not provide
-- setfpscap, so this safely does nothing if it is unavailable.
local function setNotificationFps(cap)
	if typeof(setfpscap) == "function" then
		pcall(setfpscap, cap)
	end
end

local webhookUrl     = getgenv().notiWebhook or ""
local isGateDetected = false

-- Watches for the Leviathan gate. It sends one "Frozen Dimension Found" alert
-- when the gate appears, then resets after the gate disappears.
task.spawn(function()
	while true do
		local doorLeft = findInMap("LeviathanGate", "DOORLEFT")

		if doorLeft and not isGateDetected then
			SendWebhook(
				"<@409058235203584023> <@1218901676002381854>",
				"Frozen Dimension Found",
				255,
				webhookUrl
			)
			isGateDetected = true
		elseif not doorLeft then
			isGateDetected = false
		end

		task.wait(10)
	end
end)


-- Watches for Frozen Heart, then waits for someone to use a Beast Hunter cannon
-- seat so it can report whether the heart was collected or missed.
while true do
	task.wait(1)
	local heart, waited = nil, 0
	while not heart and waited < 60 do
		task.wait(1)
		waited = waited + 1
		heart = findInMap("FrozenHeart")
	end
	if not heart then continue end

	setNotificationFps(80)

	local boat = workspace:FindFirstChild("Boats")
		and workspace.Boats:FindFirstChild("Beast Hunter")
	if not boat then continue end

	local seatUsed    = false
	local connections = {}

	for i, cannon in ipairs(boat:GetChildren()) do
		local seat = cannon:FindFirstChild("Seat")
		if seat then
			connections[i] = seat.ChildAdded:Connect(function(child)
				if child.Name == "SeatWeld" and not seatUsed then
					seatUsed = true
					disconnectAll(connections)
				end
			end)
		end
	end

	local elapsed = 0
	repeat
		task.wait(0.1)
		elapsed = elapsed + 0.1
	until seatUsed or elapsed > 120

	if not seatUsed then
		disconnectAll(connections)
		continue
	end

	task.wait(1)

	if findInMap("FrozenHeart") then
		SendWebhook(nil, "Got Heart",    0x00FF00, webhookUrl)
	else
		SendWebhook(nil, "Missed Heart", 0xFF0000, webhookUrl)
	end
	setNotificationFps(30)

	task.wait(5)
end
