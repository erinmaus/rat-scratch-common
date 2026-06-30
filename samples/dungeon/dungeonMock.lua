local GLTF = require("rat-scratch-gltf")
local Table = require("rat-scratch-common").Table
local FlatTable = require("rat-scratch-common").FlatTable
local SDF = require("rat-scratch-math").Geometry2D.SDF
local Polygon = require("rat-scratch-math").Geometry2D.Polygon
local Point = require("rat-scratch-math").Geometry2D.Point
local MarchingSquares = require("rat-scratch-math").MarchingSquares
local DualContour = require("rat-scratch-math").DualContour
local Contour = require("rat-scratch-math").Geometry2D.Contour
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local SkinnedModel = require("rat-scratch-graphics").Graphics3D.SkinnedModel
local ModelProcessor = require("rat-scratch-graphics").Graphics3D.ModelProcessor
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Quaternion = require("rat-scratch-math").Quaternion
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local Table = require("rat-scratch-common").Table
local BSPNode = require("rat-scratch-math").BSP2D.BSPNode
local Point = require("rat-scratch-math").Geometry2D.Point
local Polygon = require("rat-scratch-math").Geometry2D.Polygon

local function toWorldSpace(x, y)
	local w, h = love.graphics.getDimensions()
	w, h = w / 2, h / 2
	x, y = (x - w) / w * 20, (y - h) / h * 20
	return x, y
end

local function sampleSDF(polygons, x, y)
	local sample = SDF.distanceFromPolygons(x, y, polygons) + 1
	return sample, sample <= 0
end

local WARPED_MESH_TRANSFORMED_VERTEX_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec4" },
	{ location = 10, name = "VertexNormal", format = "floatvec4" },
}

local WARPED_MESH_STATIC_VERTEX_FORMAT = {
	{ location = 1, name = "VertexTexCoord", format = "floatvec4" },
	{ location = 2, name = "VertexColor", format = "floatvec4" },
}

local WARPED_MESH_INDEX_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

local WARPED_MESH_CURVE_VERTEX_FORMAT = {
	{ location = 0, name = "position", format = "floatvec2" },
	{ location = 1, name = "extent", format = "float" },
	{ location = 2, name = "smoothness", format = "float" },
}

local WARPED_MESH_INFO_FORMAT = {
	{ location = 0, name = "bounds", format = "floatvec2" },
	{ location = 1, name = "inputOffset", format = "uint32" },
	{ location = 2, name = "count", format = "uint32" },
	{ location = 3, name = "transform", format = "floatmat4x4" },
}

local WARPED_MESH_INDEX_INFO_FORMAT = {
	{ location = 0, name = "inputOffset", format = "uint32" },
	{ location = 1, name = "outputOffset", format = "uint32" },
	{ location = 2, name = "vertexOffset", format = "uint32" },
	{ location = 3, name = "count", format = "uint32" },
}

local WARPED_MESH_TILE_INFO_FORMAT = {
	{ location = 0, name = "meshIndex", format = "uint32" },
	{ location = 1, name = "output", format = "uint32" },
	{ location = 2, name = "curveSubsectionIndex", format = "uint32" },
}

local WARPED_MESH_CURVE_INFO_FORMAT = {
	{ location = 0, name = "offset", format = "uint32" },
	{ location = 1, name = "count", format = "uint32" },
	{ location = 2, name = "closed", format = "uint32" },
	{ location = 3, name = "extent", format = "float" },
}

local WARPED_MESH_CURVE_SUBSECTION_INFO_FORMAT = {
	{ location = 0, name = "curveIndex", format = "uint32" },
	{ location = 1, name = "offset", format = "uint32" },
	{ location = 2, name = "count", format = "uint32" },
	{ location = 3, name = "extent", format = "float" },
}

local demo = {}

demo.polygon = {}
demo.pendingSplit = {}
demo.polygonFinished = false

function demo.mousepressed(x, y, button)
	if demo.mesh then
		return
	end

	if button == 1 then
		if demo.polygonFinished then
			table.insert(demo.pendingSplit, x)
			table.insert(demo.pendingSplit, y)

			if #demo.pendingSplit == 4 then
				local node = demo.bsp:find(
					demo.pendingSplit[1],
					demo.pendingSplit[2]
				) or demo.bsp:find(
					demo.pendingSplit[3],
					demo.pendingSplit[4]
				)
				if node then
					local nx, ny = Point.direction(
						demo.pendingSplit[1],
						demo.pendingSplit[2],
						demo.pendingSplit[3],
						demo.pendingSplit[4]
					)

					node:split(
						demo.pendingSplit[1],
						demo.pendingSplit[2],
						nx,
						ny
					)
				end
				Table.clear(demo.pendingSplit)
			end
		else
			table.insert(demo.polygon, x)
			table.insert(demo.polygon, y)

			if #demo.polygon > 6 and not Polygon.isConvex(demo.polygon) then
				table.remove(demo.polygon)
				table.remove(demo.polygon)
			end
		end
	end
end

function demo.keypressed(_, scan, isRepeat)
	if scan == "space" then
		if not demo.polygonFinished then
			demo.polygonFinished = true
			demo.bsp = BSPNode(demo.polygon)
		else
			demo.build()
		end
	end
end

local function collectBSPLeafNodes(result, node)
	if node:getIsLeaf() then
		local polygon = node:getPolygon()
		local transformedPolygon = {}
		for i = 1, #polygon, 2 do
			local x, y = toWorldSpace(polygon[i], polygon[i + 1])
			table.insert(transformedPolygon, x)
			table.insert(transformedPolygon, y)
		end

		table.insert(result, transformedPolygon)
	end

	for _, child in node:iterate() do
		collectBSPLeafNodes(result, child)
	end

	return result
end

local function buildContours()
	local polygons = collectBSPLeafNodes({}, demo.bsp)

	return DualContour.generate(-40, -40, 40, 40, 0.25, polygons, sampleSDF)
end

local function generateCurve(contours, baseTileLength)
	local curveInfoData = {}
	local subCurveInfoInfoData = {}
	local curveVerticesData = {}

	for _, contour in ipairs(contours) do
		if Polygon.isClockwise(contour) then
			contour = Polygon.reverseOrder(contour)
		end

		local perimeter = Polygon.perimeter(contour)
		local tileCount = Common.round(perimeter / baseTileLength)
		local realTileLength = perimeter / tileCount

		local curveInfo = {
			offset = #curveVerticesData,
			extent = perimeter,
			closed = true,
		}

		local polygon = FlatTable.wrap(contour, 2)
		local index = 1
		local previousX, previousY = polygon:get(index)
		local currentLength = 0
		local tileIndex = 1

		local subCurveInfo = {
			curveIndex = #curveInfoData,
			offset = 0,
			count = 0,
			extent = 0,
		}

		while index <= polygon:getLength() do
			local nextX, nextY = polygon:get(index + 1)
			local length = Point.distance(previousX, previousY, nextX, nextY)

			if currentLength + length > realTileLength then
				local partialLength = realTileLength - currentLength
				local directionX, directionY =
					Point.directionNormal(previousX, previousY, nextX, nextY)

				table.insert(
					curveVerticesData,
					{ x = previousX, y = previousY, extent = partialLength }
				)
				subCurveInfo.extent = subCurveInfo.extent + partialLength

				previousX = previousX + directionX * partialLength
				previousY = previousY + directionY * partialLength
				currentLength = 0

				tileIndex = tileIndex + 1

				subCurveInfo.count = #curveVerticesData
					- (subCurveInfo.offset + curveInfo.offset)
				table.insert(subCurveInfoInfoData, subCurveInfo)

				local nextSubCurveOffset = subCurveInfo.count
					+ subCurveInfo.offset

				subCurveInfo = {
					curveIndex = #curveInfoData,
					offset = nextSubCurveOffset,
					count = 0,
					extent = 0,
				}
			else
				table.insert(
					curveVerticesData,
					{ x = previousX, y = previousY, extent = length }
				)
				subCurveInfo.extent = subCurveInfo.extent + length

				currentLength = currentLength + length
				previousX, previousY = nextX, nextY
				index = index + 1
			end
		end

		subCurveInfo.count = #curveVerticesData
			- (subCurveInfo.offset + curveInfo.offset)
		table.insert(subCurveInfoInfoData, subCurveInfo)

		table.insert(
			curveVerticesData,
			{ x = previousX, y = previousY, extent = 0 }
		)

		curveInfo.count = #curveVerticesData - curveInfo.offset
		table.insert(curveInfoData, curveInfo)
	end

	return curveVerticesData, curveInfoData, subCurveInfoInfoData
end

local function generateCurveBuffers(curveVertices, curveInfo, subCurveInfo)
	local curveVertexData = {}
	for _, vertex in ipairs(curveVertices) do
		table.insert(curveVertexData, {
			vertex.x,
			vertex.y,
			vertex.extent,
			0,
		})
	end

	local curveVertexBuffer = love.graphics.newBuffer(
		WARPED_MESH_CURVE_VERTEX_FORMAT,
		#curveVertexData,
		{ shaderstorage = true }
	)
	curveVertexBuffer:setArrayData(curveVertexData)

	local curveInfoData = {}
	for _, info in ipairs(curveInfo) do
		table.insert(curveInfoData, {
			info.offset,
			info.count,
			info.closed and 1 or 0,
			info.extent,
		})
	end

	local curveInfoBuffer = love.graphics.newBuffer(
		WARPED_MESH_CURVE_INFO_FORMAT,
		#curveInfoData,
		{ shaderstorage = true }
	)
	curveInfoBuffer:setArrayData(curveInfoData)

	local subCurveInfoData = {}
	for _, info in ipairs(subCurveInfo) do
		table.insert(subCurveInfoData, {
			info.curveIndex,
			info.offset,
			info.count,
			info.extent,
		})
	end

	local subCurveInfoBuffer = love.graphics.newBuffer(
		WARPED_MESH_CURVE_SUBSECTION_INFO_FORMAT,
		#subCurveInfoData,
		{ shaderstorage = true }
	)
	subCurveInfoBuffer:setArrayData(subCurveInfoData)

	return {
		rat_WarpedMeshCurveVertexBuffer = curveVertexBuffer,
		rat_WarpedMeshCurveInfoBuffer = curveInfoBuffer,
		rat_WarpedMeshCurveSubsectionInfoBuffer = subCurveInfoBuffer,
	}
end

local function loadModels()
	local parser =
		GLTF.loadFromFilesystem("samples/assets/dungeon/simpleWall.glb")
	local sceneDefinition = parser:loadScene(1, {
		attributes = {
			static = {
				output = GLTF.Attributes.fromFormat(Mesh.STATIC_MESH_FORMAT),
				compute_input = GLTF.Attributes.fromFormat(
					WARPED_MESH_TRANSFORMED_VERTEX_FORMAT
				),
				compute_output = GLTF.Attributes.fromFormat(
					WARPED_MESH_TRANSFORMED_VERTEX_FORMAT
				),
				static = GLTF.Attributes.fromFormat(
					WARPED_MESH_STATIC_VERTEX_FORMAT
				),
			},
		},
	})
	local scene = Scene.fromDefinition(sceneDefinition, false)

	local meshInfoData = {}
	local currentVertexOffset = 0
	local currentIndexOffset = 0
	local meshInfo = {}

	for i = 1, scene:getModelCount() do
		local model = scene:getModel(i)
		for j = 1, model:getMeshCount() do
			local mesh = model:getMesh(j)
			local vertexBuffer = mesh:getBufferByRole("compute_input")
			local indexBuffer = mesh:getIndexBuffer()

			table.insert(meshInfoData, {
				-1,
				1,
				currentVertexOffset,
				vertexBuffer:getElementCount(),
				model:getTransform():getMatrix("column"),
			})

			table.insert(meshInfo, {
				mesh = mesh,
				index = #meshInfo + 1,
				indexOffset = currentIndexOffset,
				indexCount = indexBuffer:getElementCount(),
				vertexOffset = currentVertexOffset,
				vertexCount = vertexBuffer:getElementCount(),
			})

			currentVertexOffset = currentVertexOffset
				+ vertexBuffer:getElementCount()
			currentIndexOffset = currentIndexOffset
				+ indexBuffer:getElementCount()
		end
	end

	local meshInfoBuffer = love.graphics.newBuffer(
		WARPED_MESH_INFO_FORMAT,
		#meshInfoData,
		{ shaderstorage = true }
	)
	meshInfoBuffer:setArrayData(meshInfoData)

	local sharedMeshInputVertexBuffer = love.graphics.newBuffer(
		WARPED_MESH_TRANSFORMED_VERTEX_FORMAT,
		currentVertexOffset,
		{ shaderstorage = true, vertex = true }
	)

	local sharedMeshInputIndexBuffer = love.graphics.newBuffer(
		WARPED_MESH_INDEX_FORMAT,
		currentIndexOffset,
		{ shaderstorage = true, index = true }
	)

	currentVertexOffset = 0
	currentIndexOffset = 0
	for i = 1, scene:getModelCount() do
		local model = scene:getModel(i)
		for j = 1, model:getMeshCount() do
			local mesh = model:getMesh(j)
			local vertexBuffer = mesh:getBufferByRole("compute_input")
			local indexBuffer = mesh:getIndexBuffer()
			local vertexBufferSize = vertexBuffer:getSize()
			local indexBufferSize = indexBuffer:getSize()

			love.graphics.copyBuffer(
				vertexBuffer,
				sharedMeshInputVertexBuffer,
				0,
				currentVertexOffset,
				vertexBufferSize
			)

			love.graphics.copyBuffer(
				indexBuffer,
				sharedMeshInputIndexBuffer,
				0,
				currentIndexOffset,
				indexBufferSize
			)

			currentVertexOffset = currentVertexOffset + vertexBufferSize
			currentIndexOffset = currentIndexOffset + indexBufferSize
		end
	end

	return {
		rat_WarpedMeshMeshInfoBuffer = meshInfoBuffer,
		rat_WarpedInputMeshVertexBuffer = sharedMeshInputVertexBuffer,
		rat_WarpedMeshInputIndexBuffer = sharedMeshInputIndexBuffer,
	},
		{
			meshInfo = meshInfo,
		},
		scene
end

local function generateRoomMesh(meshCount, subsectionCount, meshInfo)
	local tileInfoData = {}
	local indexInfoData = {}
	local tileInfo = {}

	local outputIndexOffset = 0
	local outputVertexOffset = 0
	for i = 1, subsectionCount do
		local meshIndex = love.math.random(meshCount)
		local mesh = meshInfo[meshIndex]

		table.insert(tileInfo, {
			meshIndex = meshIndex,
			outputVertexOffset = outputVertexOffset,
			vertexCount = mesh.vertexCount,
		})

		table.insert(tileInfoData, {
			meshIndex - 1,
			outputVertexOffset,
			i - 1,
		})

		table.insert(indexInfoData, {
			mesh.indexOffset,
			outputIndexOffset,
			outputVertexOffset,
			mesh.indexCount,
		})

		outputVertexOffset = outputVertexOffset + mesh.vertexCount
		outputIndexOffset = outputIndexOffset + mesh.indexCount
	end

	local outputIndexBuffer = love.graphics.newBuffer(
		WARPED_MESH_INDEX_FORMAT,
		outputIndexOffset,
		{ shaderstorage = true, index = true }
	)

	local outputTransformVertexBuffer = love.graphics.newBuffer(
		WARPED_MESH_TRANSFORMED_VERTEX_FORMAT,
		outputVertexOffset,
		{ shaderstorage = true, vertex = true }
	)

	local outputStaticVertexBuffer = love.graphics.newBuffer(
		WARPED_MESH_STATIC_VERTEX_FORMAT,
		outputVertexOffset,
		{ shaderstorage = true, vertex = true }
	)

	for i = 1, #tileInfo do
		local tile = tileInfo[i]
		local mesh = meshInfo[tile.meshIndex]
		local inputStaticVertexBuffer = mesh.mesh:getBufferByRole("static")

		love.graphics.copyBuffer(
			mesh.mesh:getBufferByRole("static"),
			outputStaticVertexBuffer,
			0,
			outputStaticVertexBuffer:getElementStride()
				* tile.outputVertexOffset,
			inputStaticVertexBuffer:getSize()
		)
	end

	local indexInfoBuffer = love.graphics.newBuffer(
		WARPED_MESH_INDEX_INFO_FORMAT,
		#indexInfoData,
		{ shaderstorage = true }
	)
	indexInfoBuffer:setArrayData(indexInfoData)

	local tileInfoBuffer = love.graphics.newBuffer(
		WARPED_MESH_TILE_INFO_FORMAT,
		#tileInfoData,
		{ shaderstorage = true }
	)
	tileInfoBuffer:setArrayData(tileInfoData)

	local mesh = love.graphics.newMesh(
		Mesh.STATIC_MESH_FORMAT,
		outputVertexOffset,
		"triangles",
		"static"
	)

	for _, attribute in ipairs(WARPED_MESH_STATIC_VERTEX_FORMAT) do
		mesh:setAttributeEnabled(attribute.location, true)
		mesh:attachAttribute(attribute.location, outputStaticVertexBuffer)
	end

	for _, attribute in ipairs(WARPED_MESH_TRANSFORMED_VERTEX_FORMAT) do
		mesh:setAttributeEnabled(attribute.location, true)
		mesh:attachAttribute(attribute.location, outputTransformVertexBuffer)
	end

	mesh:setIndexBuffer(outputIndexBuffer)

	return {
		rat_WarpedMeshOutputIndexBuffer = outputIndexBuffer,
		rat_WarpedMeshIndexInfoBuffer = indexInfoBuffer,
		rat_WarpedMeshTileInfoBuffer = tileInfoBuffer,
		rat_WarpedOutputMeshVerticesBuffer = outputTransformVertexBuffer,
	},
		mesh
end

local function combineBufferUniforms(result, buffers, ...)
	if not buffers and select("#", ...) == 0 then
		return result
	end

	for uniform, buffer in pairs(buffers) do
		result[uniform] = buffer
	end

	return combineBufferUniforms(result, ...)
end

local function sendBufferUniforms(shader, buffers)
	for uniform, buffer in pairs(buffers) do
		if shader:hasUniform(uniform, buffer) then
			shader:send(uniform, buffer)
		end
	end
end

local function dispatchThreadgroups(shader, x, y, z)
	x = x or 1
	y = y or 1
	z = z or 1

	local localX, localY, localZ = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(x / localX), 1),
		math.max(math.ceil(y / localY), 1),
		math.max(math.ceil(z / localZ), 1)
	)
end

function demo.build()
	local warpMeshShader = ShaderPreprocessor.newComputeShader(
		"rat-scratch-dungeon/Shaders/WarpMesh/WarpMesh.compute.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	local offsetIndicesShader = ShaderPreprocessor.newComputeShader(
		"rat-scratch-dungeon/Shaders/WarpMesh/OffsetIndexBuffer.compute.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.simpleShader = ShaderPreprocessor.newShader(
		"samples/assets/shaders/SimpleModel/SimpleModel.frag.glsl",
		"samples/assets/shaders/SimpleModel/SimpleModel.vert.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	local contour = buildContours()
	local meshBuffers, info, scene = loadModels()
	local curveVertexInfo, curveInfo, subCurveInfo = generateCurve(contour, 2)
	local curveBuffers =
		generateCurveBuffers(curveVertexInfo, curveInfo, subCurveInfo)
	local tileBuffers, mesh =
		generateRoomMesh(#info.meshInfo, #subCurveInfo, info.meshInfo)

	local bufferUniforms =
		combineBufferUniforms({}, meshBuffers, curveBuffers, tileBuffers)

	sendBufferUniforms(warpMeshShader, bufferUniforms)
	sendBufferUniforms(offsetIndicesShader, bufferUniforms)

	local maxVertexCount, maxIndexCount = 0, 0
	for _, mesh in ipairs(info.meshInfo) do
		maxVertexCount = math.max(mesh.vertexCount, maxVertexCount)
		maxIndexCount = math.max(mesh.indexCount, maxIndexCount)
	end

	dispatchThreadgroups(warpMeshShader, maxVertexCount, #subCurveInfo)
	dispatchThreadgroups(offsetIndicesShader, maxIndexCount, #subCurveInfo)

	demo.mesh = mesh
end

local function getProjectionTransform()
	return Transform.makePerspectiveTransform(
		math.rad(45),
		love.graphics.getWidth() / love.graphics.getHeight(),
		0.1,
		1000
	)
end

local function getCameraTransform()
	local x, y = toWorldSpace(love.mouse.getPosition())
	x = Common.sign(x) * Common.clamp(math.abs(x) * 2, 10, 30)
	y = Common.sign(y) * Common.clamp(math.abs(y) * 2, 10, 30)

	return Transform.lookAt(Vector3(x, 4, y), Vector3.ZERO)
end

--- @param node RatScratch.Math.BSP2D.BSPNode
local function drawBSPNode(node)
	if node:getIsLeaf() then
		local mx, my = love.mouse.getPosition()
		if Polygon.isPointInside(mx, my, node:getPolygon()) then
			love.graphics.setColor(0, 1, 0, 1)
		else
			love.graphics.setColor(1, 1, 1, 0.25)
		end

		love.graphics.polygon("line", node:getPolygon())
	else
		for _, child in node:iterate() do
			drawBSPNode(child)
		end
	end
end

function demo.drawBSP()
	love.graphics.push("all")
	love.graphics.setPointSize(2)
	love.graphics.setColor(1, 1, 1, 1)

	if demo.bsp then
		drawBSPNode(demo.bsp)
	elseif #demo.polygon > 2 then
		love.graphics.line(demo.polygon)
	else
		love.graphics.points(demo.polygon)
	end

	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.points(demo.pendingSplit)
	love.graphics.pop()
end

function demo.draw()
	if not demo.mesh then
		demo.drawBSP()
		return
	end

	local projection = getProjectionTransform()
	local camera = getCameraTransform()

	love.graphics.push("all")
	love.graphics.setDepthMode("lequal", true)
	love.graphics.setProjection(projection)
	love.graphics.applyTransform(camera)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(demo.simpleShader)
	love.graphics.draw(demo.mesh)
	love.graphics.pop()
end

return demo
