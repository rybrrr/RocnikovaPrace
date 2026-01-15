-->> PRIVATE VARIABLES <<--

local NetTest = script.Parent
local Common = require(NetTest.Common)

-->> SETUP <<--

local BOOLEANS = {
	["true"] = true,
	["false"] = true,
}

-- Save token patterns in order in which we should recognize them
local TOKEN_PATTERNS: {Common.TokenPatternData} = {
	-- Simple tokens first
	[1] = {
		Type = "Whitespace",
		Pattern = "^%s+",
	},
	[2] = {
		Type = "VariableAssign",
		Pattern = "^=",
	},
	[3] = {
		Type = "FieldAssign",
		Pattern = "^:",
	},
	[4] = {
		Type = "OpenParentheses",
		Pattern = "^%(",
	},
	[5] = {
		Type = "CloseParentheses",
		Pattern = "^%)",
	},
	[6] = {
		Type = "OpenBraces",
		Pattern = "^%{",
	},
	[7] = {
		Type = "CloseBraces",
		Pattern = "^%}",
	},
	[8] = {
		Type = "Comma",
		Pattern = "^,",
	},
	[9] = {
		Type = "Optional",
		Pattern = "^%?",
	},
	[10] = {
		Type = "Array",
		Pattern = "^%[%]",
	},
	
	-- Keywords go second
	[11] = {
		Type = "Keyword",
		Pattern = "^%a+",
		Validate = function(token: string): boolean
			return Common.KEYWORDS[token]
		end,
	},
	
	-- Types go third
	[12] = {
		Type = "Primitive",
		Pattern = "^%w+",
		Validate = function(token: string): boolean
			return Common.PRIMITIVES[token]
		end,
	},
	[13] = {
		Type = "Boolean",
		Pattern = "^%a+",
		Validate = function(token: string): boolean
			return BOOLEANS[token]
		end,
	},
	
	-- Text (identifiers, ...) goes last
	[14] = {
		Type = "Text",
		Pattern = "^[%a_][%w_]*",
	},
}

local IGNORED_TYPES = {
	["Whitespace"] = true,
}

-->> LEXER <<--

local Lexer = {} :: Common.Lexer
Lexer.__index = Lexer

function Lexer:TryConsume(type: Common.TokenType): Common.Token?
	local nextToken = self:GetNextToken(false)
	if nextToken.Type == type then
		-- Advance cursor and return token
		self.Cursor = nextToken.End + 1
		return nextToken
	end
end

function Lexer:Consume(type: Common.TokenType): Common.Token
	local nextToken = self:GetNextToken(true)
	assert(nextToken.Type == type, `Expected token of type {type} got {nextToken.Type} instead!`)
	return nextToken
end

function Lexer:ConsumeAny(...: Common.TokenType): Common.Token
	local types = table.pack(...)
	local nextToken = self:GetNextToken(true)
	assert(table.find(types, nextToken.Type),
		`Expected token of type ({table.concat(types, "|")}) got {nextToken.Type} instead!`
	)
	return nextToken
end

function Lexer:GetNextToken(advanceCursor: boolean): Common.Token
	if self.Cursor > self.Size then
		return {
			Type = "EndOfFile",
			Value = "",
			Start = self.Size,
			End = self.Size,
		}
	end
	
	for _, patternData in TOKEN_PATTERNS do
		local startIndex, endIndex = string.find(self.Source, patternData.Pattern, self.Cursor)

		-- Pattern did not match
		if not startIndex or not endIndex then
			continue
		end

		local text = string.sub(self.Source, startIndex, endIndex)

		-- Validate token type if needed
		if patternData.Validate and not patternData.Validate(text) then
			continue
		end
		
		-- Advance even if it's ignored with advanceCursor = false
		if advanceCursor or IGNORED_TYPES[patternData.Type] then
			self.Cursor = endIndex + 1
		end
		
		-- Return the next token if the current one is ignored
		if IGNORED_TYPES[patternData.Type] then
			return self:GetNextToken(advanceCursor)
		end
		
		return {
			Type = patternData.Type,
			Value = text,
			Start = startIndex,
			End = endIndex,
		}
	end
	
	-- Return unknown token
	local symbol = string.sub(self.Source, self.Cursor, self.Cursor)
	local unknownToken = {
		Type = "Unknown",
		Value = symbol,
		Start = self.Cursor,
		End = self.Cursor ,
	}
	
	if advanceCursor then
		self.Cursor += 1
	end
	
	return unknownToken
end

return table.freeze({
	new = function(source: string): Common.Lexer
		local self = setmetatable({}, Lexer) :: Common.Lexer

		self.Source = source
		self.Size = #source
		self.Cursor = 1

		return self
	end,
})
