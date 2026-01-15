return [[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReliableEvent: RemoteEvent = ReplicatedStorage:FindFirstChild("NETTEST_RELIABLE") :: any
if not ReliableEvent then
	ReliableEvent = Instance.new("RemoteEvent")
	ReliableEvent.Name = "NETTEST_RELIABLE"
	ReliableEvent.Parent = ReplicatedStorage
end

local SendBuffer: buffer
local SendBufferSize: number
local SendCursor: number
local SendPosition: number

<BREAK>
local PlayerBufferMap: {[Player]: BufferInfo} = {}

local function LoadData(player: Player)
	local playerData = PlayerBufferMap[player]

	-- If there is no data, create default data
	if not playerData then
		SendBuffer = buffer.create(64)
		SendBufferSize = 64
		SendCursor = 0
		SendPosition = 0
		return
	end

	-- Load the player's data into the local variables
	SendBuffer = playerData.Buffer
	SendBufferSize = playerData.Size
	SendCursor = playerData.Cursor
	SendPosition = playerData.Cursor
end

local function SaveData(player: Player)
	-- Avoid creating a new table
	local playerData = PlayerBufferMap[player]
	if not playerData then
		PlayerBufferMap[player] = {
			Buffer = SendBuffer,
			Size = SendBufferSize,
			Cursor = SendCursor,
		}
		return
	end
	
	playerData.Buffer = SendBuffer
	playerData.Size = SendBufferSize
	playerData.Cursor = SendCursor
end

<BREAK>
<EVENTS_WRITE>

<EVENTS_READ>

local function StepReplication()
	for player, playerData in PlayerBufferMap do
		-- Avoid sending empty data
		if playerData.Cursor == 0 then
			continue
		end
		
		-- Trim the data size
		local trimmedBuffer = buffer.create(playerData.Cursor)
		buffer.copy(trimmedBuffer, 0, playerData.Buffer, 0, playerData.Cursor)
		ReliableEvent:FireClient(player, trimmedBuffer)

		-- Reset data
		playerData.Buffer = buffer.create(64)
		playerData.Size = 64
		playerData.Cursor = 0
	end
end

local function EventReceived(player: Player, receiveBuffer: buffer)
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

local function PlayerRemoving(player: Player)
	PlayerBufferMap[player] = nil
end

-->> CONNECTIONS <<--

Players.PlayerRemoving:Connect(PlayerRemoving)
ReliableEvent.OnServerEvent:Connect(EventReceived)]]
