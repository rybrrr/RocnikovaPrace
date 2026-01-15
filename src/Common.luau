-->> TOKEN TYPES <<--

export type TokenType = "Whitespace"
	| "VariableAssign"
	| "FieldAssign"
	| "OpenParentheses"
	| "CloseParentheses"
	| "OpenBraces"
	| "CloseBraces"
	| "Comma"
	| "Optional"
	| "Array"
	| "Keyword"
	| "Primitive"
	| "Boolean"
	| "Text"
	| "EndOfFile"
	| "Unknown"

export type Primitive = "u8" | "u16" | "u32"
	| "i8" | "i16" | "i32"
	| "f32" | "f64"
	| "string" | "buffer" | "boolean"
	| "Vector2" | "Vector3" | "CFrame"
	| "Color3" | "BrickColor"

export type Modifier = "Optional" | "Array"

export type Token = {
	Type: TokenType,
	Value: string,
	Start: number,
	End: number,
}

export type TokenPatternData = {
	Type: TokenType,
	Pattern: string,
	Validate: ((token: string) -> boolean)?,	-- If Validate function is provided, it checks whether the token is 
	-- actually of the type or if it is just a pattern coincidence
}

export type Lexer = {
	-- Members:
	Source: string,
	Size: number,
	Cursor: number,

	-- Methods:
	TryConsume: (self: Lexer, type: TokenType) -> Token?,
	Consume: (self: Lexer, type: TokenType) -> Token,
	ConsumeAny: (self: Lexer, ...TokenType) -> Token,
	GetNextToken: (self: Lexer, advanceCursor: boolean) -> Token,
}

-->> PARSER TYPES <<--

export type StructureKey = {
	ValueType: "Literal" | "Type",
	Values: {any},
	Optional: boolean,
	ContinueWhileCan: boolean,
}

export type Structure = {[string]: StructureKey}

export type BytesData = {
	Static: number,
	Dynamic: {string},
}

export type PrimitiveData = {
	StaticBytes: number,
	DynamicBytes: string,
	Write: string,
	Read: string,
	LuauType: string,
}

export type ModifierData = PrimitiveData

export type ParsedData = {
	Type: "Primitive" | "Modifier",
	Name: string?,
	DataName: Primitive | Modifier,
	Data: {ParsedData},
}

export type Event = {
	Name: string,
	ID: number,
	From: "Server" | "Client",
	Data: {ParsedData},
}

export type ParsedSource = {
	ClientEvents: {Event},
	ServerEvents: {Event},
}

export type Parser = {
	-- Members:
	Lexer: Lexer,
	Output: ParsedSource,

	-- Public methods:
	ParseType: (self: Parser) -> ParsedData,
	ParseStructure: (self: Parser, body: Structure) -> {[string]: any},
	ParseEvent: (self: Parser) -> (),
	ParseSource: (self: Parser) -> (),
}

-->> GENERATOR TYPES <<--

export type TemplateTags = "<COMPONENT>" | "<EVENT_DEFINITIONS>"			-- Shared
	| "<EVENT_CALLBACKS>" | "<BREAK>" | "<EVENTS_WRITE>" | "<EVENTS_READ>"	-- Server & Client

export type GeneratorTags = "<OUTPUT>" | "<TEMP_VAR>" | "<TEMP_VARn>"
	| "<VALUE>" | "<WRITE_ABC>" | "<READ>" | "<READn>" | "<READ_OUT>"
	| "<VALUE_TYPE>" | "<VALUE_TYPEn>" | "<SELF_TYPE>"

export type EventGeneratedData = {
	From: "Server" | "Client",
	Write: string,
	Read: string,
	Connect: string,
	Fire: string,
	Callback: string,
}

export type ProcessedEventsOneSide = {
	Definitions: string,
	Callbacks: string,
	Write: string,
	Read: string,
}

export type ProcessedEvents = {
	Server: ProcessedEventsOneSide,
	Client: ProcessedEventsOneSide,
}

export type Generator = {
	-- Members:
	ParsedSource: ParsedSource,
	ServerOutput: string?,
	ClientOutput: string?,

	-- Methods:
	GenerateAllEvents: (self: Generator) -> (),
}

export type GeneratorStatic = {
	new: (parsedSource: ParsedSource) -> Generator,
	GenerateEventWrite: (event: Event) -> string,
	GenerateEventRead: (event: Event) -> string,
	GenerateEventConnect: (event: Event) -> string,
	GenerateEventFireFromServer: (event: Event) -> string,
	GenerateEventFireFromClient: (event: Event) -> string,
	GenerateEventCallback: (event: Event) -> string,
	GenerateEvent: (event: Event) -> EventGeneratedData,
	ProcessEvents: (events: {EventGeneratedData}) -> ProcessedEvents
}

-->> MODULE <<--

local Common = {}

Common.PRIMITIVES = {
	u8 = {
		--Range = NumberRange.new(0, 255),
		--Integer = true,
		StaticBytes = 1,
		DynamicBytes = nil,
		Write = "buffer.writeu8(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readu8(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},
	u16 = {
		--Range = NumberRange.new(0, 65535),
		--Integer = true,
		StaticBytes = 2,
		DynamicBytes = nil,
		Write = "buffer.writeu16(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readu16(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},
	u32 = {
		--Range = NumberRange.new(0, 4294967295),
		--Integer = true,
		StaticBytes = 4,
		DynamicBytes = nil,
		Write = "buffer.writeu32(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readu32(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},

	i8 = {
		--Range = NumberRange.new(-128, 127),
		--Integer = true,
		StaticBytes = 1,
		DynamicBytes = nil,
		Write = "buffer.writei8(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readi8(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},
	i16 = {
		--Range = NumberRange.new(-32768, 32767),
		--Integer = true,
		StaticBytes = 2,
		DynamicBytes = nil,
		Write = "buffer.writei16(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readi16(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},
	i32 = {
		--Range = NumberRange.new(-2147483648, 2147483647),
		--Integer = true,
		StaticBytes = 4,
		DynamicBytes = nil,
		Write = "buffer.writei32(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readi32(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},
	
	f32 = {
		--Range = NumberRange.new(-16777216, 16777216),
		--Integer = false,
		StaticBytes = 4,
		DynamicBytes = nil,
		Write = "buffer.writef32(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readf32(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},
	f64 = {
		--Range = NumberRange.new(-2 ^ 53, 2 ^ 53),
		--Integer = false,
		StaticBytes = 8,
		DynamicBytes = nil,
		Write = "buffer.writef64(SendBuffer, SendPosition, <VALUE>)",
		Read = "<OUTPUT> = buffer.readf64(ReceiveBuffer, ReceivePosition)",
		LuauType = "number",
	},

	string = {
		-- Range = NumberRange.new(0, 65535),
		StaticBytes = 2,
		DynamicBytes = "#<VALUE>",
		Write = [[buffer.writeu16(SendBuffer, SendPosition, #<VALUE>)		-- Length
			buffer.writestring(SendBuffer, SendPosition+2, <VALUE>)]],
		Read = [[<TEMP_VAR> = buffer.readu16(ReceiveBuffer, ReceivePosition)		-- Length
			Read(<TEMP_VAR>)
			<OUTPUT> = buffer.readstring(ReceiveBuffer, ReceivePosition, <TEMP_VAR>)]],
		LuauType = "string",
	},
	buffer = {
		--Range = NumberRange.new(0, 65535)
		StaticBytes = 2,
		DynamicBytes = "buffer.len(<VALUE>)",
		Write = [[buffer.writeu16(SendBuffer, SendPosition, buffer.len(<VALUE>))		-- Length
			buffer.copy(ReceiveBuffer, SendPosition+2, <VALUE>)]],
		Read = [[<TEMP_VAR> = buffer.readu16(ReceiveBuffer, ReceivePosition)		-- Length
			Read(<TEMP_VAR>)
			<OUTPUT> = buffer.create(<TEMP_VAR>)
			buffer.copy(<OUTPUT>, 0, ReceiveBuffer, ReceivePosition, <TEMP_VAR>)]],
		LuauType = "buffer",
	},

	boolean = {
		StaticBytes = 1,
		DynamicBytes = nil,
		Write = "buffer.writeu8(SendBuffer, SendPosition, <VALUE> and 1 or 0)",
		Read = "<OUTPUT> = buffer.readu8(ReceiveBuffer, ReceivePosition) == 1",
		LuauType = "boolean",
	},
	
	Vector2 = {
		StaticBytes = 8,
		DynamicBytes = nil,
		Write = [[buffer.writef32(SendBuffer, SendPosition, <VALUE>.X)
			buffer.writef32(SendBuffer, SendPosition+4, <VALUE>.Y)]],
		Read = [[<OUTPUT> = Vector2.new(
				buffer.readf32(ReceiveBuffer, ReceivePosition),
				buffer.readf32(ReceiveBuffer, ReceivePosition+4)
			)]],
		LuauType = "Vector2",
	},
	Vector3 = {
		StaticBytes = 12,
		DynamicBytes = nil,
		Write = [[buffer.writef32(SendBuffer, SendPosition, <VALUE>.X)
			buffer.writef32(SendBuffer, SendPosition+4, <VALUE>.Y)
			buffer.writef32(SendBuffer, SendPosition+8, <VALUE>.Z)]],
		Read = [[<OUTPUT> = Vector3.new(
				buffer.readf32(ReceiveBuffer, ReceivePosition),
				buffer.readf32(ReceiveBuffer, ReceivePosition+4),
				buffer.readf32(ReceiveBuffer, ReceivePosition+8)
			)]],
		LuauType = "Vector3",
	},
	CFrame = {
		StaticBytes = 24,
		DynamicBytes = nil,
		Write = [[-- Position
			buffer.writef32(SendBuffer, SendPosition, <VALUE>.X)
			buffer.writef32(SendBuffer, SendPosition+4, <VALUE>.Y)
			buffer.writef32(SendBuffer, SendPosition+8, <VALUE>.Z)
			
			-- AxisAngle (faster than euler angles)
			<TEMP_VAR>, <TEMP_VAR2> = <VALUE>:ToAxisAngle()
			<TEMP_VAR> = <TEMP_VAR> * <TEMP_VAR2>	-- Save space by incorporating theta as the magnitude
			buffer.writef32(SendBuffer, SendPosition+12, <TEMP_VAR>.X)
			buffer.writef32(SendBuffer, SendPosition+16, <TEMP_VAR>.Y)
			buffer.writef32(SendBuffer, SendPosition+20, <TEMP_VAR>.Z)]],
		Read = [[-- Position
			<TEMP_VAR> = Vector3.new(
				buffer.readf32(ReceiveBuffer, ReceivePosition),
				buffer.readf32(ReceiveBuffer, ReceivePosition+4),
				buffer.readf32(ReceiveBuffer, ReceivePosition+8)
			)
			
			-- AxisAngle
			<TEMP_VAR2> = Vector3.new(
				buffer.readf32(ReceiveBuffer, ReceivePosition+12),
				buffer.readf32(ReceiveBuffer, ReceivePosition+16),
				buffer.readf32(ReceiveBuffer, ReceivePosition+20)
			)
			<TEMP_VAR3> = <TEMP_VAR2>.Magnitude
			<OUTPUT> = if <TEMP_VAR3> > 0
				then CFrame.fromAxisAngle(<TEMP_VAR2>, <TEMP_VAR3>) + <TEMP_VAR>
				else CFrame.new(<TEMP_VAR>)]],
		LuauType = "CFrame",
	},
	
	Color3 = {
		StaticBytes = 3,
		DynamicBytes = nil,
		Write = [[buffer.writeu8(SendBuffer, SendPosition, math.round(<VALUE>.R * 255))
			buffer.writeu8(SendBuffer, SendPosition+1, math.round(<VALUE>.G * 255))
			buffer.writeu8(SendBuffer, SendPosition+2, math.round(<VALUE>.B * 255))]],
		Read = [[<OUTPUT> = Color3.fromRGB(
				buffer.readu8(ReceiveBuffer, ReceivePosition),
				buffer.readu8(ReceiveBuffer, ReceivePosition+1),
				buffer.readu8(ReceiveBuffer, ReceivePosition+2)
			)]],
		LuauType = "Color3",
	},
	BrickColor = {
		StaticBytes = 2,
		DynamicBytes = nil,
		Write = "buffer.writeu16(SendBuffer, SendPosition, <VALUE>.Number)",
		Read = "<OUTPUT> = BrickColor.new(buffer.readu16(ReceiveBuffer, ReceivePosition)",
		LuauType = "BrickColor",
	},
} :: {[Primitive]: PrimitiveData}

Common.MODIFIERS = {
	Optional = {
		StaticBytes = 1,
		DynamicBytes = nil,
		Write = [[buffer.writeu8(SendBuffer, SendPosition, <VALUE> and 1 or 0)
			if <VALUE> then
				<WRITE_<VALUE>>
			end]],
		Read = [[<TEMP_VAR> = buffer.readu8(ReceiveBuffer, ReceivePosition) == 1
			if <TEMP_VAR> then
				<READ>
				<OUTPUT> = <READ_OUT>
			end]],
		LuauType = "<VALUE_TYPE>?",
	},
	
	Array = {
		StaticBytes = 2,
		DynamicBytes = nil,
		Write = [[<TEMP_VAR> = #<VALUE>
			buffer.writeu16(SendBuffer, SendPosition, <TEMP_VAR>)
			for <TEMP_VAR2> = 1, <TEMP_VAR> do
				<TEMP_VAR3> = <VALUE>[<TEMP_VAR2>]
				<WRITE_<TEMP_VAR3>>
			end]],
		Read = [[<TEMP_VAR> = buffer.readu16(ReceiveBuffer, ReceivePosition)
			<OUTPUT> = table.create(<TEMP_VAR>) :: <SELF_TYPE>
			for <TEMP_VAR2> = 1, <TEMP_VAR> do
				<READ>
				<OUTPUT>[<TEMP_VAR2>] = <READ_OUT>
			end]],
		LuauType = "{<VALUE_TYPE>}",
	},
} :: {[Modifier]: ModifierData}

Common.KEYWORDS = {
	event = true,
} :: {[string]: true}

return Common
