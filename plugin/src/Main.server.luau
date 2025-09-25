local Main = script:FindFirstAncestor("MCPStudioPlugin")
local MockWebSocketService = require(Main.MockWebSocketService)
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local URI = "http://localhost:44755"
local RECEIVE_ENDPOINT = "/request"
local SEND_ENDPOINT = "/response"

if RunService:IsRunning() then
	return
end

-- set debug flag
local DEBUG_MODE = false

local old_warn = warn
local function log(...)
	if DEBUG_MODE then
		old_warn(...)
	end
end

local function fetchBuiltinTools()
	local tools = {}

	local scriptParent = script.Parent
	if not scriptParent then
		log("Warning: Could not find script parent.")
		return tools
	end

	local toolsFolder = scriptParent:FindFirstChild("Tools")
	if toolsFolder then
		log("Tools folder found.")

		local runCodeTool = toolsFolder:FindFirstChild("RunCode")
		local insertModelTool = toolsFolder:FindFirstChild("InsertModel")

		if runCodeTool and runCodeTool:IsA("ModuleScript") then
			table.insert(tools, require(runCodeTool))
			log("Loaded RunCode tool.")
		else
			log("Warning: RunCode tool not found.")
		end

		if insertModelTool and insertModelTool:IsA("ModuleScript") then
			table.insert(tools, require(insertModelTool))
			log("Loaded InsertModel tool.")
		else
			log("Warning: InsertModel tool not found.")
		end
	end

	log("Tools loaded: " .. #tools)
	return tools
end

local tools = fetchBuiltinTools()

local function connectWebSocket()
	local client = MockWebSocketService:CreateClient(URI)
	client:SetReceiveEndpoint(RECEIVE_ENDPOINT)
	client:SetSendEndpoint(SEND_ENDPOINT)

	client.Opened:Connect(function()
		log("[MCP] Connection opened")
	end)

	client.Closed:Connect(function()
		log("[MCP] Connection closed")
	end)

	client.MessageReceived:Connect(function(message)
		log("[MCP] Message received")

		local body = HttpService:JSONDecode(message)
		assert(body and body.id and body.args, "Invalid message received")

		local id = body.id
		local responseSent = false
		local function sendResponseOnce(response)
			if not responseSent then
				log("[MCP] Sending response:" .. response)
				responseSent = true
				client:Send({
					id = id,
					response = response,
				})
			end
		end

		local args = body.args

		for i, tool in ipairs(tools) do
			if typeof(tool) == "function" then
				local success, response = pcall(tool, args)

				if success and response then
					sendResponseOnce(response)
				elseif not success then
					sendResponseOnce("Error handling request: " .. tostring(response))
				end
			else
				log("Tool " .. i .. " is not a function, skipping")
			end
		end

		sendResponseOnce("No tool found to handle request")
		log("[MCP] Successfully handled request")
	end)

	return client
end

local function getButtonImage()
	local ok, response = pcall(function()
		return StudioService:GetClassIcon("PackageLink").Image
	end)
	return ok and response or "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

local currentClient = connectWebSocket() -- nil for default off
print("The MCP Studio plugin is ready for prompts.")

local toolbar = plugin:CreateToolbar("MCP")
local toggleButton = toolbar:CreateButton("Toggle MCP", "Toggle connection to the server", getButtonImage())
toggleButton.ClickableWhenViewportHidden = true
toggleButton:SetActive(currentClient ~= nil)

toggleButton.Click:Connect(function()
	if not currentClient then
		currentClient = connectWebSocket()
		print("The MCP Studio plugin is ready for prompts.")
	else
		currentClient:Close()
		currentClient = nil
		print("The MCP Studio plugin is stopped.")
	end
end)
