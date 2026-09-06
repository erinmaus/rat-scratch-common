local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Search = require("rat-scratch-common").Search
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.Draw : RatScratch.Common.BaseObject
--- @field private data number[]
--- @field private offset integer
--- @field private pointers (false | RatScratch.Pipeline.Buffer.PipelinePointer)[]
--- @overload fun(data?: number[], index: integer): RatScratch.Pipeline.Draw
local Draw = Object()

Draw.DRAW_FORMAT = {
	{ location = 0, name = "objectInstanceIndex", format = "uint32" },
	{ location = 1, name = "modelInstanceIndex", format = "uint32" },
	{ location = 2, name = "meshInstanceIndex", format = "uint32" },
	{ location = 3, name = "modelIndex", format = "uint32" },
	{ location = 4, name = "meshIndex", format = "uint32" },
	{ location = 5, name = "meshletIndex", format = "uint32" },
	{ location = 6, name = "staticBaseVertexOffset", format = "uint32" },
	{ location = 7, name = "skinnedBaseVertexOffset", format = "uint32" },
	{ location = 8, name = "boneOffsetCount", format = "uint32vec2" },
	{ location = 9, name = "indexOffset", format = "uint32" },
	{ location = 10, name = "cameraIndex", format = "uint32" },
	{ location = 11, name = "layerIndex", format = "uint32" },
}

Draw.DRAW_FORMAT_INSTANCE = BufferFormat.get(Draw.DRAW_FORMAT)

--- @param data number[]
--- @param index integer
function Draw:new(data, index)
	self.data = data
		or Table.new(Draw.DRAW_FORMAT_INSTANCE:getComponentCount(), 0)
	self.offset = (index or 1) - 1

	self.pointers = Table.new(Draw.DRAW_FORMAT_INSTANCE:getAttributeCount(), 0)
	for i = 1, Draw.DRAW_FORMAT_INSTANCE:getAttributeCount() do
		self.pointers[i] = false
	end

	self.validPointers =
		Table.new(Draw.DRAW_FORMAT_INSTANCE:getAttributeCount(), 0)

	self.offsets = Table.new(Draw.DRAW_FORMAT_INSTANCE:getAttributeCount(), 0)

	self:reset()
end

--- @param data number[]
--- @param index integer
function Draw:from(data, index)
	self.data = data
		or Table.new(Draw.DRAW_FORMAT_INSTANCE:getComponentCount(), 0)
	self.offset = (index or 1) - 1

	for i = 1, Draw.DRAW_FORMAT_INSTANCE:getAttributeCount() do
		self.pointers[i] = false
	end

	Table.clear(self.validPointers)
	Table.clear(self.offsets)
	self:reset()
end

function Draw:getData()
	return self.data
end

function Draw:getOffset()
	return self.offset
end

function Draw:getIndex()
	return self.offset + 1
end

--- @param a integer
--- @param b integer
local function _compare(a, b)
	return a - b
end

--- @param attribute string | integer
--- @param pointer? RatScratch.Pipeline.Buffer.PipelinePointer
--- @param pointerIndex? integer
function Draw:setPointer(attribute, pointer, pointerIndex)
	local index = Draw.DRAW_FORMAT_INSTANCE:getAttributeLocation(attribute) + 1

	local validIndex = Search.first(self.validPointers, index, _compare)
	if validIndex then
		table.remove(self.validPointers, validIndex)
	end

	self.pointers[index] = pointer or false

	if pointer then
		table.insert(
			self.validPointers,
			Search.lessThanEqual(self.validPointers, index, _compare) + 1
		)

		self.offsets[index] = (pointerIndex or 1) - 1
	else
		self.offsets[index] = nil
	end
end

--- @overload fun(count: integer): RatScratch.Pipeline.Draw[]
--- @overload fun(count: integer, data: number[], index: integer): RatScratch.Pipeline.Draw[]
--- @overload fun(count: integer, data: number[], index: integer, result: RatScratch.Pipeline.Draw[]): RatScratch.Pipeline.Draw[]
function Draw.newBatch(count, a, b, c)
	local data, index, result
	if a and b and c then
		data = a
		index = b
		result = c
	elseif a and b then
		data = a
		index = b
		result = Table.new(count, 0)
	else
		data =
			Table.new(Draw.DRAW_FORMAT_INSTANCE:getComponentCount() * count, 0)
		index = 1
		result = Table.new(count, 0)
	end

	--- @cast data number[]
	--- @cast index integer
	--- @cast result RatScratch.Pipeline.Draw[]

	local componentCount = Draw.DRAW_FORMAT_INSTANCE:getComponentCount()
	for i = 1, count do
		local draw = result[i]
		if not draw then
			draw = Draw(data, index)
			table.insert(result, Draw(data, index))
		else
			draw:from(data, index)
		end

		index = index + componentCount
	end

	for i = #result, count + 1, -1 do
		table.remove(result, i)
	end

	return result
end

function Draw:reset()
	BufferFormat.resetValue(Draw.DRAW_FORMAT_INSTANCE, self.data, self.offset)
end

function Draw:update()
	for _, index in ipairs(self.validPointers) do
		local pointer = self.pointers[index]
		--- @cast pointer RatScratch.Pipeline.Buffer.PipelinePointer

		local location = index - 1
		local fieldCount, fieldIndex =
			Draw.DRAW_FORMAT_INSTANCE:getCountOffset(location)
		local i = fieldIndex
		local j = fieldIndex + fieldCount - 1

		local pointerIndex, pointerCount = pointer:getIndexCount()

		Table.copy(
			self.data,
			i + self.offset,
			j + self.offset,
			math.max(pointerIndex - 1 + self.offsets[index], 0),
			pointerCount
		)
	end
end

--- @param draws RatScratch.Pipeline.Draw[]
--- @param i? integer
--- @param j? integer
function Draw.updateBatch(draws, i, j)
	i = i or 1
	j = j or #draws

	for k = i, j do
		draws[k]:update()
	end
end

--- @param draws RatScratch.Pipeline.Draw[]
--- @param i? integer
--- @param j? integer
function Draw.resetBatch(draws, i, j)
	i = i or 1
	j = j or #draws

	for k = i, j do
		draws[k]:reset()
	end
end

return Draw
