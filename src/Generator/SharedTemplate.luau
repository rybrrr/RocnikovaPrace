return [[--!strict
--!native
--!optimize 2
--!nolint ForRange

-->> TYPES <<--

type BufferInfo = {
	Buffer: buffer,
	Size: number,
	Cursor: number,
}

-->> SETUP <<--

<COMPONENT>
local ReceiveBuffer: buffer
local ReceiveBufferSize: number
local ReceiveCursor: number
local ReceivePosition: number

local EventCallbacks = table.create(<RECEIVE_EVENT_COUNT>) :: any
for i=1, <RECEIVE_EVENT_COUNT> do
	EventCallbacks[i] = {}
end

-->> FUNCTIONS <<--

<COMPONENT>
local function Allocate(bytes: number)
	local inUse = (SendCursor + bytes)

	-- Resize the buffer if it is not long enough
	if inUse > SendBufferSize then
		while inUse > SendBufferSize do
			-- Resize to twice the size to avoid resizing every time
			SendBufferSize *= 2
		end

		local newBuffer = buffer.create(SendBufferSize)
		buffer.copy(newBuffer, 0, SendBuffer, 0, SendCursor)
		SendBuffer = newBuffer
	end
	
	SendPosition = SendCursor
	SendCursor = SendCursor + bytes
end

local function Read(Bytes: number)
	ReceivePosition = ReceiveCursor
	ReceiveCursor = ReceiveCursor + Bytes
end

<COMPONENT>
RunService.Heartbeat:Connect(StepReplication)

-->> RETURNS <<--

return table.freeze({
	StepReplication = StepReplication,
	
<EVENT_DEFINITIONS>
})
]]
