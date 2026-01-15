return [[
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReliableEvent = ReplicatedStorage:WaitForChild("NETTEST_RELIABLE") :: RemoteEvent

local SendBuffer = buffer.create(64)
local SendBufferSize = 64
local SendCursor = 0
local SendPosition = 0

<BREAK>
<BREAK>
<EVENTS_WRITE>

<EVENTS_READ>

local function StepReplication()
	-- Avoid sending empty data
	if SendCursor == 0 then
		return
	end
	
	-- Trim the data size
	local trimmedBuffer = buffer.create(SendCursor)
	buffer.copy(trimmedBuffer, 0, SendBuffer, 0, SendCursor)
	ReliableEvent:FireServer(trimmedBuffer)

	-- Reset data
	SendBuffer = buffer.create(64)
	SendBufferSize = 64
	SendCursor = 0
end

local function EventReceived(receiveBuffer: buffer)
	ReceiveBuffer = receiveBuffer
	ReceiveBufferSize = buffer.len(receiveBuffer)
	ReceiveCursor = 0
	ReceivePosition = 0

	while ReceiveCursor < ReceiveBufferSize do
		Read(1)
		local eventID = buffer.readu8(ReceiveBuffer, ReceivePosition)
		
		-- Doing case-by-case is faster than generalization
<EVENT_CALLBACKS>
	end
end

-->> CONNECTIONS <<--

ReliableEvent.OnClientEvent:Connect(EventReceived)]]
