local PostProcess = {}

PostProcess.MESH_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec2" },
}

PostProcess.MESH = love.graphics.newMesh(PostProcess.MESH_FORMAT, {
	{ -1, -1 },
	{ 1, -1 },
	{ 1, 1 },
	{ 1, 1 },
	{ -1, 1 },
	{ -1, -1 },
}, "triangles")

function PostProcess.draw()
	love.graphics.draw(PostProcess.MESH)
end

function PostProcess.drawInstanced(count)
	love.graphics.draw(PostProcess.MESH, count)
end

return PostProcess
