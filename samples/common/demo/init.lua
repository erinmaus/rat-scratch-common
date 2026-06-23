local demo = {}

function demo.new(path)
	return love.filesystem.load(path or "samples/common/demo/init.lua")()
end

return demo
