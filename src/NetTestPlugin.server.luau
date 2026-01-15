-->> VARIABLES <<--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Icon made by icon wind from www.flaticon.com
local toolbar = plugin:CreateToolbar("NetTest")
local openEditorButton = toolbar:CreateButton(
	"Toggle Editor",
	"Toggles Text Editor Where You Can Type Event Definitions To",
	"rbxassetid://131120349635993"
)

openEditorButton.ClickableWhenViewportHidden = true

-->> TEXT INPUT SETUP <<--

local WarningInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	true,
	false,
	400,
	80,
	10,
	10
)

-- Create new 'DockWidgetPluginGuiInfo' object
local WidgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	200, 
	300, 
	100, 
	100 
)

-- Create new widget GUI
local DockWidget = plugin:CreateDockWidgetPluginGuiAsync("NetTestWidget", WidgetInfo)

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, 0, 1, 0)
TextBox.BackgroundColor3 = Color3.new(0.16, 0.13, 0.29)
TextBox.ZIndex = 0
TextBox.TextColor3 = Color3.new(1, 1, 1)
TextBox.ClearTextOnFocus = false
TextBox.MultiLine = true
TextBox.Text = ""
TextBox.PlaceholderText = "Paste Net Code Here"
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.TextYAlignment = Enum.TextYAlignment.Top
TextBox.Parent = DockWidget 

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingLeft = UDim.new(0, 5)
UIPadding.PaddingRight = UDim.new(0, 5)
UIPadding.PaddingTop = UDim.new(0, 5)
UIPadding.PaddingBottom = UDim.new(0, 5)
UIPadding.Parent = TextBox

local ConvertButton = Instance.new("TextButton")
ConvertButton.Size = UDim2.new(0, 40, 0, 40)
ConvertButton.Position = UDim2.new(1, -45, 1, -45)
ConvertButton.BackgroundColor3 = Color3.new(0.10, 0.08, 0.18)
ConvertButton.ZIndex = 1
ConvertButton.Text = ""
ConvertButton.Parent = DockWidget

local ConvertButtonImage = Instance.new("ImageButton")
ConvertButtonImage.AnchorPoint = Vector2.new(.5, .5)
ConvertButtonImage.Size = UDim2.new(.8, 0, .8, 0)
ConvertButtonImage.Position = UDim2.new(.5, 0, .5, 0)
ConvertButtonImage.BackgroundTransparency = 1
ConvertButtonImage.Image = "rbxassetid://108449005858974"
ConvertButtonImage.Parent = ConvertButton

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.new(0.06, 0.05, 0.11)
UIStroke.Thickness = 2
UIStroke.Parent = ConvertButton

-->> PLUGIN FUNCTIONS <<--

local _warningId = 0

local function DisplayWarning(text: string)
	local warningWidget = plugin:CreateDockWidgetPluginGuiAsync(`WarningWidget{_warningId}`, WarningInfo)
	
	local warningLabel = Instance.new("TextLabel")
	warningLabel.Size = UDim2.new(1, 0, 1, 0)
	warningLabel.BackgroundColor3 = Color3.new(0.16, 0.13, 0.29)
	warningLabel.TextColor3 = Color3.new(1, 1, 1)
	warningLabel.TextWrapped = true
	warningLabel.Text = text
	warningLabel.Parent = warningWidget
	
	local function CloseWarning()
		warningWidget:Destroy()
	end
	
	_warningId += 1
end

local function ToggleTextBox()
	DockWidget.Enabled = not DockWidget.Enabled
end

local function ConvertNetCode()
	local Lexer = require(script.Lexer)
	local Parser = require(script.Parser)
	local Generator = require(script.Generator)

	local myLexer = Lexer.new(TextBox.Text)
	local myParser = Parser.new(myLexer)
	myParser:ParseSource()
	
	local myGenerator = Generator.new(myParser.Output)
	myGenerator:GenerateAllEvents()
	
	local Generated = ReplicatedStorage:FindFirstChild("Generated")
	if not Generated then
		Generated = Instance.new("Folder")
		Generated.Name = "Generated"
		Generated.Parent = ReplicatedStorage
	end
	
	local serverOutput = Generated:FindFirstChild("Server") or Instance.new("ModuleScript", Generated)
	serverOutput.Name = "Server"
	serverOutput.Source = myGenerator.ServerOutput
	
	local clientOutput = Generated:FindFirstChild("Client") or Instance.new("ModuleScript", Generated)
	clientOutput.Name = "Client"
	clientOutput.Source = myGenerator.ClientOutput

	print("Successfully converted net code!")
end

local function TryConvert()
	local success, result = pcall(ConvertNetCode)
	if not success then
		DisplayWarning(`Conversion failed: {result}`)
	end
end

-->> CONNECTIONS <<--

openEditorButton.Click:Connect(ToggleTextBox)

ConvertButton.Activated:Connect(TryConvert)
ConvertButtonImage.Activated:Connect(TryConvert)
