-->> PRIVATE VARIABLES <<--

local NetTest = script.Parent
local Common = require(NetTest.Common)

-->> STRUCTURE DEFINITIONS <<--

local EVENT_STRUCT: Common.Structure = {
	from = {
		ValueType = "Literal",
		Values = {"Server", "Client"},
		Optional = false,
		ContinueWhileCan = false,
	},
	data = {
		ValueType = "Type",
		Values = {},
		Optional = true,
		ContinueWhileCan = true,
	},
}

-->> PARSER <<--

local Parser = {} :: Common.Parser
Parser.__index = Parser

function Parser:ParseType(): Common.ParsedData
	local firstToken = self.Lexer:ConsumeAny("Primitive", "Text")
	local name, value
	
	if firstToken.Type == "Text" then
		name = firstToken.Value
		self.Lexer:Consume("FieldAssign")
		value = self.Lexer:Consume("Primitive").Value
	else
		value = firstToken.Value
	end
	
	-- Value
	local leafNode = {
		Type = "Primitive",
		DataName = value,
		Data = {}
	}
	local rootNode = leafNode
	
	-- Array modifier
	while self.Lexer:TryConsume("Array") do
		rootNode = {
			Type = "Modifier",
			DataName = "Array",
			Data = {rootNode}
		}
	end
	
	-- Optional modifier
	if self.Lexer:TryConsume("Optional") then
		rootNode = {
			Type = "Modifier",
			DataName = "Optional",
			Data = {rootNode}
		}
	end
	
	rootNode.Name = name or nil
	
	return rootNode
end

function Parser:ParseStructure(body: Common.Structure): {[string]: any}
	local struct = {}
	
	self.Lexer:Consume("OpenBraces")
	
	local function consumeLiteral(fieldName: string)
		local keyData = body[fieldName]
		local value = self.Lexer:Consume("Text")
		assert(table.find(keyData.Values, value.Value), `Unexpected value {value.Value} for field {fieldName}!`)
		return value.Value
	end
	
	local function consumeValue(fieldName: string)
		local keyData = body[fieldName]
		local value = if keyData.ValueType == "Literal" then consumeLiteral(fieldName)
			elseif keyData.ValueType == "Type" then self:ParseType()
			else nil
		assert(value, `Invalid value!`)

		if typeof(struct[fieldName]) == "table" then
			table.insert(struct[fieldName], value)
		else
			struct[fieldName] = value
		end
	end
	
	while true do
		if self.Lexer:TryConsume("CloseBraces") then
			break
		end
		
		local field = self.Lexer:Consume("Text")
		assert(body[field.Value], `Unexpected field {field.Value}!`)
		assert(not struct[field.Value], `Field {field.Value} is already assigned!`)
		
		self.Lexer:Consume("FieldAssign")
		
		local parentheses = self.Lexer:TryConsume("OpenParentheses")
		local keyData = body[field.Value]
		
		-- Prepare the table for multiple values
		if keyData.ContinueWhileCan then
			struct[field.Value] = {}
		end
		
		-- If there are no parentheses, expect only one value; loop otherwise
		if keyData.ContinueWhileCan and parentheses then
			-- Immediately check for close parentheses to allow 0 values
			while not self.Lexer:TryConsume("CloseParentheses") do
				consumeValue(field.Value)
				
				-- Don't require a comma if the next token is a close parentheses
				if self.Lexer:TryConsume("CloseParentheses") then
					break
				end
				
				self.Lexer:Consume("Comma")
			end
			parentheses = false	-- Already closed
		else
			consumeValue(field.Value)
		end
		
		if parentheses then
			self.Lexer:Consume("CloseParentheses")
		end
		
		-- Force comma at the end of the field assign unless it's the last field
		if self.Lexer:TryConsume("CloseBraces") then
			break
		end
		
		self.Lexer:Consume("Comma")
	end
	
	for key, keyData in body do
		if not keyData.Optional and not struct[key] then
			error(`Missing field {key}!`)
		end
	end
	
	return struct
end

function Parser:ParseEvent()
	local nameToken = self.Lexer:Consume("Text")
	self.Lexer:Consume("VariableAssign")
	
	local struct = self:ParseStructure(EVENT_STRUCT)
	local event = {
		Name = nameToken.Value,
		From = struct["from"],
		Data = {},
	}
	
	if struct["data"] then
		local valueNum = 1
		for _, parsedData: Common.ParsedData in struct["data"] do
			parsedData.Name = parsedData.Name or `value{valueNum}`
			table.insert(event.Data, parsedData)
			valueNum += 1
		end
	end
	
	if struct["from"] == "Server" then
		event.ID = #self.Output.ServerEvents + 1
		table.insert(self.Output.ServerEvents, event)
	elseif struct["from"] == "Client" then
		event.ID = #self.Output.ClientEvents + 1
		table.insert(self.Output.ClientEvents, event)
	end
end

function Parser:ParseSource()
	while not self.Lexer:TryConsume("EndOfFile") do
		local keyword = self.Lexer:Consume("Keyword")
		if keyword.Value == "event" then
			self:ParseEvent()
		else
			error(`Unknown keyword '{keyword.Value}'!`)
		end
	end
end

return table.freeze({
	new = function(lexer: Common.Lexer): Common.Parser
		local self = setmetatable({}, Parser) :: Common.Parser
		
		self.Lexer = lexer
		self.Output = {
			ServerEvents = {},
			ClientEvents = {},
		}
		
		return self
	end,
})
