local HttpService = game:GetService("HttpService")

local MockWebSocketClient = {}
MockWebSocketClient.__index = MockWebSocketClient

local EnumWebSocketState = {
	Connecting = "Connecting",
	Open = "Open",
	Closing = "Closing",
	Closed = "Closed",
}

local CloseableStates = {
	[EnumWebSocketState.Connecting] = true,
	[EnumWebSocketState.Open] = true,
}

local POLL_WAIT_TIME = 1

-- Type definitions removed for 2021 compatibility

function MockWebSocketClient.new(uri)
	local self = setmetatable({}, MockWebSocketClient)

	self._uri = uri
	self._receiveEndpoint = ""
	self._sendEndpoint = ""
	self._pollTask = nil
	self._shouldStop = false

	self._OpenedEvent = Instance.new("BindableEvent")
	self.Opened = self._OpenedEvent.Event

	self._ClosedEvent = Instance.new("BindableEvent")
	self.Closed = self._ClosedEvent.Event

	self._MessageReceivedEvent = Instance.new("BindableEvent")
	self.MessageReceived = self._MessageReceivedEvent.Event

	self.ConnectionState = EnumWebSocketState.Connecting

	delay(0, function() self:_OpenImpl() end)

	return self
end

local function doRequest(url, method, body)
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = method,
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = body and HttpService:JSONEncode(body) or nil,
			-- Compress removed for 2021 compatibility
		})
	end)

	return (ok and response.Success) and response or nil
end

function MockWebSocketClient:_OpenImpl()
	assert(self.ConnectionState == EnumWebSocketState.Connecting, "WebSocket is not in the Connecting state")

	self.ConnectionState = EnumWebSocketState.Open
	self._OpenedEvent:Fire()

	self._pollTask = spawn(function()
		while self.ConnectionState == EnumWebSocketState.Open and not self._shouldStop do
			local response = doRequest(self._uri .. self._receiveEndpoint, "GET")

			if response and response.Body then
				self._MessageReceivedEvent:Fire(response.Body)
			end

			wait(POLL_WAIT_TIME)
		end
	end)
end

function MockWebSocketClient:Send(data)
	doRequest(self._uri .. self._sendEndpoint, "POST", data)
end

function MockWebSocketClient:Close()
	if CloseableStates[self.ConnectionState] then
		self.ConnectionState = EnumWebSocketState.Closing

		if self._pollTask and coroutine.status(self._pollTask) == "running" then
			-- task.cancel is not available for 2021, using flag instead
			self._shouldStop = true
			self._pollTask = nil
		end

		self.ConnectionState = EnumWebSocketState.Closed
		self._ClosedEvent:Fire()
	end
end

-- START DEVIATION: These methods are not present in the real WebSocketClient instance
function MockWebSocketClient:SetReceiveEndpoint(endpoint)
	self._receiveEndpoint = endpoint
end

function MockWebSocketClient:SetSendEndpoint(endpoint)
	self._sendEndpoint = endpoint
end
-- END DEVIATION

local MockWebSocketService = {}
MockWebSocketService.__index = MockWebSocketService

function MockWebSocketService:CreateClient(uri)
	return MockWebSocketClient.new(uri)
end

return MockWebSocketService
