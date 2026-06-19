local function attachDebugger()
	local isDebug = false

	for i = 2, #arg do
		if arg[i] == "/debug" or arg[i] == "--debug" then
			isDebug = true
		end
	end

	isDebug = isDebug and os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
	if isDebug then
		require("lldebugger").start()

		function love.errorhandler(msg)
			error(msg, 2)
		end
	end
end

attachDebugger()

function love.draw()
	love.graphics.print("rat-scratch-common", 8, 8)
end
