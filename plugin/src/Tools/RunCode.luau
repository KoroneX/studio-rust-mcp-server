local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local HttpService = game:GetService("HttpService")

local function runCodeWithOutput(command)
	local output = ""

	local function getTableType(arg)
		local hasArray = false
		local hasTable = false
		for key, _value in arg do
			if typeof(key) == "number" then
				hasArray = true
			else
				hasTable = true
			end
			if hasArray and hasTable then
				break
			end
		end
		return hasArray, hasTable
	end

	local function serializeTable(arg)
		if typeof(arg) == "table" then
			local _, isTable = getTableType(arg)

			local newArg = {}
			for key, value in arg do
				local newKey = serializeTable(key)
				if isTable then
					newArg[tostring(newKey)] = serializeTable(value)
				else
					newArg[newKey] = serializeTable(value)
				end
			end
			return newArg
		elseif type(arg) == "function" then
			return "[FUNCTION: " .. tostring(arg) .. "]"
		elseif type(arg) == "userdata" then
			return tostring(arg) or "UNABLE_TO_SERIALIZE"
		end
		return arg
	end

	local function toStrTable(t)
		local strTable = {}
		for i, arg in ipairs(t) do
			local serializedArg = serializeTable(arg)
			if typeof(serializedArg) == "table" then
				strTable[i] = HttpService:JSONEncode(serializedArg)
			else
				strTable[i] = tostring(serializedArg)
			end
		end
		return strTable
	end

	local function addToOutput(header, ...)
		local packed = table.pack(...)
		local strResults = {}
		for i = 1, packed.n do
			local serializedArg = serializeTable(packed[i])
			if typeof(serializedArg) == "table" then
				table.insert(strResults, HttpService:JSONEncode(serializedArg))
			else
				table.insert(strResults, tostring(serializedArg))
			end
		end
		output ..= header .. " " .. table.concat(strResults, "\t") .. "\n"
	end

	local function executeCode()
		local chunk = loadstring(command)
		local chunkfenv = getfenv(chunk)

		local oldPrint = print
		chunkfenv.print = function(...)
			oldPrint(...)
			addToOutput("[OUTPUT]", ...)
		end

		local oldWarn = warn
		chunkfenv.warn = function(...)
			oldWarn(...)
			addToOutput("[WARNING]", ...)
		end

		local oldError = error
		chunkfenv.error = function(...)
			oldError(...)
			addToOutput("[ERROR]", ...)
		end

		local results = table.pack(chunk())
		if #results > 0 then
			addToOutput("[RETURNED RESULTS]", table.unpack(results))
		end

		return results
	end

	local ok, errorMessage = pcall(executeCode)
	if not ok then
		addToOutput("[UNEXPECTED ERROR]", errorMessage)
	end

	return output
end

local function handleRunCode(args)
	if not args["RunCode"] then
		return nil
	end

	local runCodeArgs = args["RunCode"]
	if type(runCodeArgs.command) ~= "string" then
		error("Missing command in RunCode")
	end

	return runCodeWithOutput(runCodeArgs.command)
end

return handleRunCode
