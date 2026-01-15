-->> PRIVATE VARIABLES <<--

local NetTest = script.Parent
local Common = require(NetTest.Common)

local SharedTemplate = require(script.SharedTemplate)
local ServerParts = require(script.ServerParts)
local ClientParts = require(script.ClientParts)

-->> SERVER & CLIENT PREPARATION <<--

local ServerTemplate, ClientTemplate = SharedTemplate, SharedTemplate

do
	local serverParts = ServerParts:split("<BREAK>")
	local clientParts = ClientParts:split("<BREAK>")
	
	for _, part in serverParts do
		ServerTemplate = ServerTemplate:gsub("<COMPONENT>", part, 1)
	end
	
	for _, part in clientParts do
		ClientTemplate = ClientTemplate:gsub("<COMPONENT>", part, 1)
	end
end

-->> PRIVATE FUNCTIONS <<--

local function GetTempVarCount(data: Common.ParsedData, mode: "Write" | "Read"): number
	local dataInfo = Common.PRIMITIVES[data.DataName] or Common.MODIFIERS[data.DataName]
	local tempVarCount = 0
	
	-- Count only unique tags
	local seenTempTag = {}
	for tempVarTag in dataInfo[mode]:gmatch("(<TEMP_VAR%d*>)") do
		if not seenTempTag[tempVarTag] then
			seenTempTag[tempVarTag] = true
			tempVarCount += 1
		end
	end
	
	-- Match read tags too for temporary output
	for tempVarTag in dataInfo[mode]:gmatch("(<READ%d*>)") do
		if not seenTempTag[tempVarTag] then
			seenTempTag[tempVarTag] = true
			tempVarCount += 1
		end
	end
	
	for _, innerData in data.Data do
		tempVarCount += GetTempVarCount(innerData, mode)
	end
	
	return tempVarCount
end

local function GetLuauType(data: Common.ParsedData): string
	local dataInfo = Common.PRIMITIVES[data.DataName] or Common.MODIFIERS[data.DataName]
	local luauType = dataInfo.LuauType
	
	for _, innerData in data.Data do
		local nextValueTag = luauType:match("(<VALUE_TYPE%d*>)")
		luauType = luauType:gsub(nextValueTag, `{GetLuauType(innerData)}`)
	end
	
	return luauType
end

local function GetUntypedArguments(event: Common.Event): string
	local arguments = {}

	for _, data in event.Data do
		table.insert(arguments, data.Name)
	end
	
	return table.concat(arguments, ", ")
end

-- Write:

local function PrepareWriteData(event: Common.Event): {Arguments: string, TempVarCount: number}
	local tempVarCount = 0
	local arguments = {}
	
	for _, data in event.Data do
		local innerTempVarCount = GetTempVarCount(data, "Write")
		local luauType = GetLuauType(data)
		
		table.insert(arguments, `{data.Name}: {luauType}`)
		tempVarCount += innerTempVarCount
	end
	
	return {
		Arguments = table.concat(arguments, ", "),
		TempVarCount = tempVarCount,
	}
end

local function GetWriteBlock(data: Common.ParsedData, depth: number, tempVarOffset: number): (string, number)
	local dataInfo = Common.PRIMITIVES[data.DataName] or Common.MODIFIERS[data.DataName]
	local bytes = table.concat({dataInfo.StaticBytes, dataInfo.DynamicBytes}, " + ")
	local write = dataInfo.Write
	local lines = {}
	
	-- Convert value tags in bytes
	bytes = bytes:gsub("<VALUE>", data.Name)
	
	-- Allocate the necessary bytes
	table.insert(lines, ("	"):rep(depth) .. `Allocate({bytes})`)
	
	-- Convert value tags
	write = write:gsub("<VALUE>", data.Name)

	-- Replace temporary variables
	local tempVarCount = 0
	while true do
		local nextTempVarTag = write:match("(<TEMP_VAR%d*>)")
		if not nextTempVarTag then
			break
		end

		tempVarCount += 1
		write = write:gsub(nextTempVarTag, `tempVar{tempVarOffset + tempVarCount}`)
	end
	
	-- Replace all inner data
	for _, innerData in data.Data do
		local nextWriteTag, innerDataName = write:match("(<WRITE_(.*)>)")
		innerData.Name = innerDataName
		
		local innerWriteBlock, innerTempVarCount = GetWriteBlock(innerData, depth + 1, tempVarOffset + tempVarCount)
		write = write:gsub(nextWriteTag, innerWriteBlock .. "\n")
		
		tempVarCount += innerTempVarCount
	end

	-- Find the indentation to subtract; this way we can keep the indentation differences
	local leastIndent = math.huge
	for line in write:gmatch("[^\n]+") do
		local lineIndent = line:match("^(%s*).*")
		if #lineIndent ~= 0 then
			leastIndent = math.min(leastIndent, #lineIndent)
		end
	end
	
	-- Write the lines
	for line in write:gmatch("[^\n]+") do
		local lineIndent, strippedLine = line:match("^(%s*)(.*)")
		local currIndent = math.max(#lineIndent - leastIndent, 0) + depth
		table.insert(lines, string.rep("	", currIndent) .. strippedLine)
	end
	
	local writeBlock = table.concat(lines, "\n")
	
	return writeBlock, tempVarCount
end

-- Read:

local function PrepareReadData(event: Common.Event): {Returns: string, TempVarCount: number}
	local tempVarCount = 0
	local returns = {}

	for _, data in event.Data do
		local innerTempVarCount = GetTempVarCount(data, "Read")
		local luauType = GetLuauType(data)

		table.insert(returns, luauType)
		tempVarCount += innerTempVarCount
	end

	return {
		Returns = table.concat(returns, ", "),
		TempVarCount = tempVarCount,
	}
end

local function GetReadBlock(data: Common.ParsedData, depth: number, tempVarOffset: number): (string, number)
	local dataInfo = Common.PRIMITIVES[data.DataName] or Common.MODIFIERS[data.DataName]
	local read = dataInfo.Read
	local lines = {}

	-- Allocate the necessary bytes
	if dataInfo.StaticBytes > 0 then
		table.insert(lines, ("	"):rep(depth) .. `Read({dataInfo.StaticBytes})`)
	end
	
	-- Replace types in type casts
	read = read:gsub("<SELF_TYPE>", GetLuauType(data))
	
	-- Replace temporary variables
	local tempVarCount = 0
	while true do
		local nextTempVarTag = read:match("(<TEMP_VAR%d*>)")
		if not nextTempVarTag then
			break
		end

		tempVarCount += 1
		read = read:gsub(nextTempVarTag, `tempVar{tempVarOffset + tempVarCount}`)
	end
	
	-- Count the read variables too, but don't gsub
	local tempReadVarNum = tempVarOffset + tempVarCount + 1
	local seenTag = {}
	local tagStart, tagEnd = read:find("<READ%d*>")
	while tagStart do
		tempVarCount += 1
		tagStart, tagEnd = read:find("<READ%d*>", tagEnd + 1)
	end

	-- Replace all inner data
	for _, innerData in data.Data do
		local tempReadVarName = `tempVar{tempReadVarNum}`
		local nextReadTag, readNum = read:match("(<READ(%d*)>)")
		local innerReadBlock, innerTempVarCount = GetReadBlock(innerData, depth + 1, tempVarOffset + tempVarCount)
		
		innerReadBlock = innerReadBlock:gsub("<OUTPUT>", tempReadVarName)
		read = read:gsub(`<READ{readNum}>`, innerReadBlock)
		read = read:gsub(`<READ_OUT{readNum}>`, tempReadVarName)

		tempVarCount += innerTempVarCount
		tempReadVarNum += 1
	end

	-- Find the indentation to subtract; this way we can keep the indentation differences
	local leastIndent = math.huge
	for line in read:gmatch("[^\n]+") do
		local lineIndent = line:match("^(%s*).*")
		if #lineIndent ~= 0 then
			leastIndent = math.min(leastIndent, #lineIndent)
		end
	end

	-- Write the lines
	for line in read:gmatch("[^\n]+") do
		local lineIndent, strippedLine = line:match("^(%s*)(.*)")
		local currIndent = math.max(#lineIndent - leastIndent, 0) + depth
		table.insert(lines, string.rep("	", currIndent) .. strippedLine)
	end

	local readBlock = table.concat(lines, "\n")
	return readBlock, tempVarCount
end

-->> GENERATOR <<--

local Generator = {} :: Common.Generator
Generator.__index = Generator

-->> STATIC FUNCTIONS <<--

local GeneratorStatic = {} :: Common.GeneratorStatic

GeneratorStatic.new = function(parsedSource: Common.ParsedSource): Common.Generator
	local self = setmetatable({}, Generator) :: Common.Generator

	self.ParsedSource = parsedSource
	self.ServerOutput = nil
	self.ClientOutput = nil

	return self
end

GeneratorStatic.GenerateEventWrite = function(event: Common.Event): string
	--[[
	Code structure:
	1. Prepare arguments, get temporary variable count
	2. Prepare temporary variables
	3. Write function beginning, allocate initial bytes, write event id
	4. Convert all the write blocks' tags and write down the converted blocks
	5. Write function end and return the function as a string
	]]
	
	-- Prepare the initial data first
	local initialData = PrepareWriteData(event)
	
	local tempVarNames = {}
	for i=1, initialData.TempVarCount do
		table.insert(tempVarNames, `tempVar{i}`)
	end

	-- Start the write function
	local lines = {}
	table.insert(lines, `local function {event.Name}_Write({initialData.Arguments})`)
	
	if #tempVarNames > 0 then
		table.insert(lines, `	local {table.concat(tempVarNames, ", ")}`)
	end
	
	table.insert(lines, `	Allocate(1)`)
	table.insert(lines, `	buffer.writeu8(SendBuffer, SendPosition, {event.ID})	-- EventID`)

	-- Create the write function's body
	local tempVarOffset = 0
	for i, data in event.Data do
		local writeBlock, usedTempVars = GetWriteBlock(data, 1, tempVarOffset)
		table.insert(lines, writeBlock)
		tempVarOffset += usedTempVars
		
		if event.Data[i+1] then
			-- Keep an empty line between data types
			table.insert(lines, "")
		end
	end

	-- Finish the write function
	table.insert(lines, "end")
	
	return table.concat(lines, "\n")
end

GeneratorStatic.GenerateEventRead = function(event: Common.Event): string
	--[[
	Code structure:
	1. Prepare returns, get temporary variable count
	2. Prepare temporary variables and outputs
	3. Write function beginning, read event id
	4. Convert all the read blocks' tags and write down the converted blocks
	5. Write function end and return the function as a string
	]]
	
	if #event.Data == 0 then
		-- No data, no need to read anything
		return ""
	end
	
	-- Prepare the initial data first
	local initialData = PrepareReadData(event)

	local outputNames = {}
	for i=1, #event.Data do
		table.insert(outputNames, `output{i}`)
	end
	
	local tempVarNames = {}
	for i=1, initialData.TempVarCount do
		table.insert(tempVarNames, `tempVar{i}`)
	end

	-- Start the read function
	local lines = {}
	table.insert(lines, `local function {event.Name}_Read(): ({initialData.Returns})`)
	
	if #outputNames > 0 then
		table.insert(lines, `	local {table.concat(outputNames, ", ")}`)
	end
	if #tempVarNames> 0 then
		table.insert(lines, `	local {table.concat(tempVarNames, ", ")}`)
	end

	-- Create the read function's body
	local tempVarOffset = 0
	for i, data in event.Data do
		local readBlock, usedTempVars = GetReadBlock(data, 1, tempVarOffset)
		
		-- Replace final outputs
		readBlock = readBlock:gsub("<OUTPUT>", `output{i}`)
		
		table.insert(lines, readBlock)
		tempVarOffset += usedTempVars

		if event.Data[i+1] then
			-- Keep an empty line between data types
			table.insert(lines, "")
		end
	end

	-- Finish the read function
	table.insert(lines, `	return {table.concat(outputNames, ", ")}`)
	table.insert(lines, "end")

	return table.concat(lines, "\n")
end

GeneratorStatic.GenerateEventConnect = function(event: Common.Event): string
	local initialWriteData = PrepareWriteData(event)
	local arguments = initialWriteData.Arguments
	
	if event.From == "Client" and #arguments > 0 then
		arguments = `player: Player, {arguments}`
	elseif event.From == "Client" then
		arguments = "player: Player"
	end
	
	local lines = {
		`	{event.Name} = \{`,
		`		Connect = function(connectedFunction: ({arguments}) -> ()): () -> ()`,
		`			table.insert(EventCallbacks[{event.ID}], connectedFunction)`,
		`			return function()`,
		`				table.remove(EventCallbacks[{event.ID}], table.find(EventCallbacks[{event.ID}], connectedFunction))`,
		`			end`,
		`		end`,
		`	},`,
	}
	
	return table.concat(lines, "\n")
end

GeneratorStatic.GenerateEventFireFromServer = function(event: Common.Event): string
	local initialWriteData = PrepareWriteData(event)
	local returns = GetUntypedArguments(event)
	local arguments = if #initialWriteData.Arguments > 0
		then `player: Player, {initialWriteData.Arguments}`
		else "player: Player"
	
	local lines = {
		`	{event.Name} = \{`,
		`		FireClient = function({arguments})`,
		`			LoadData(player)`,
		`			{event.Name}_Write({returns})`,
		`			SaveData(player)`,
		`		end,`,
		`	},`,
	}

	return table.concat(lines, "\n")
end

GeneratorStatic.GenerateEventFireFromClient = function(event: Common.Event): string
	local initialWriteData = PrepareWriteData(event)
	local returns = GetUntypedArguments(event)
	
	local lines = {
		`	{event.Name} = \{`,
		`		FireServer = function({initialWriteData.Arguments})`,
		`			{event.Name}_Write({returns})`,
		`		end,`,
		`	},`,
	}

	return table.concat(lines, "\n")
end

GeneratorStatic.GenerateEventCallback = function(event: Common.Event): string
	local initialWriteData = PrepareWriteData(event)
	local returns = GetUntypedArguments(event)
	returns = if #returns > 0 then returns else nil
	
	local arguments = if event.From == "Server"
		then table.concat({"callback", returns}, ", ")
		else table.concat({"callback", "player", returns}, ", ")
	
	local ifType = if event.ID == 1 then "if" else "elseif"
	
	local lines = {
		`		{ifType} eventID == {event.ID} then`,
		`			for _, callback in EventCallbacks[{event.ID}] do`,
		`				task.spawn({arguments})`,
		`			end`,
	}
	
	if returns then
		table.insert(
			lines,
			2,
			`			local {returns} = {event.Name}_Read()`
		)
	end
	
	return table.concat(lines, "\n")
end

GeneratorStatic.GenerateEvent = function(event: Common.Event): Common.EventGeneratedData
	local generatedData = {
		From = event.From,
		Write = GeneratorStatic.GenerateEventWrite(event),
		Read = GeneratorStatic.GenerateEventRead(event),
		Connect = GeneratorStatic.GenerateEventConnect(event),
		Fire = if event.From == "Server"
			then GeneratorStatic.GenerateEventFireFromServer(event)
			else GeneratorStatic.GenerateEventFireFromClient(event),
		Callback = GeneratorStatic.GenerateEventCallback(event),
	}
	
	return generatedData
end

GeneratorStatic.ProcessEvents = function(events: {Common.EventGeneratedData}): Common.ProcessedEvents
	-- Definitions: string,
	-- Callbacks: string,
	-- Write: string,
	-- Read: string,
	
	local sides = {"Server", "Client"}
	local numEvents = #events
	local split = {}
	for _, side in sides do
		split[side] = {
			Definitions = table.create(numEvents),
			Callbacks = table.create(numEvents),
			Write = table.create(numEvents),
			Read = table.create(numEvents),
		}
	end
	
	for _, event in events do
		local side = event.From
		local otherSide = if event.From == "Server" then "Client" else "Server"
		
		table.insert(split[side].Definitions, event.Fire)
		table.insert(split[side].Write, event.Write)
		
		table.insert(split[otherSide].Definitions, event.Connect)
		table.insert(split[otherSide].Callbacks, event.Callback)
		table.insert(split[otherSide].Read, event.Read)
	end
	
	for _, data: Common.ProcessedEventsOneSide in split do
		if #data.Callbacks > 0 then
			table.insert(data.Callbacks, table.concat({
				"		else",
				"			error('Unknown event id')",
				"		end",
			}, "\n"))
		end
	end
	
	local processed = {} :: Common.ProcessedEvents
	for _, side in sides do
		processed[side] = {
			Definitions = table.concat(split[side].Definitions, "\n\n"),
			Callbacks = table.concat(split[side].Callbacks, "\n"),
			Write = table.concat(split[side].Write, "\n\n"),
			Read = table.concat(split[side].Read, "\n\n"),
		}
	end
	
	return processed
end

-->> DYNAMIC METHODS <<--

function Generator:GenerateAllEvents()
	local output = {
		Server = ServerTemplate:gsub("<RECEIVE_EVENT_COUNT>", #self.ParsedSource.ClientEvents),
		Client = ClientTemplate:gsub("<RECEIVE_EVENT_COUNT>", #self.ParsedSource.ServerEvents),
	}
	
	local events = {}
	
	for _, event in self.ParsedSource.ClientEvents do
		local generated = GeneratorStatic.GenerateEvent(event)
		table.insert(events, generated)
	end
	
	for _, event in self.ParsedSource.ServerEvents do
		local generated = GeneratorStatic.GenerateEvent(event)
		table.insert(events, generated)
	end
	
	local processedEvents = GeneratorStatic.ProcessEvents(events)
	
	for side, processedData in processedEvents do
		output[side] = output[side]:gsub("<EVENT_DEFINITIONS>", processedData.Definitions)
			:gsub("<EVENT_CALLBACKS>", processedData.Callbacks)
			:gsub("<EVENTS_WRITE>", processedData.Write)
			:gsub("<EVENTS_READ>", processedData.Read)
	end
	
	self.ClientOutput = output.Client
	self.ServerOutput = output.Server
end

return table.freeze(GeneratorStatic)
