local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.Graphics.Graphics3D.Model : RatScratch.Common.BaseObject
--- @overload fun(name?: string, meshes: RatScratch.Graphics.Graphics3D.Mesh[])
--- @field private name string
--- @field private meshes RatScratch.Graphics.Graphics3D.Mesh[]
--- @field private meshesByName table<string, RatScratch.Graphics.Graphics3D.Mesh>
local Model = Object()

--- @param inputMeshes RatScratch.Graphics.Graphics3D.Mesh[]
--- @return RatScratch.Graphics.Graphics3D.Mesh[], table<string, RatScratch.Graphics.Graphics3D.Mesh>
function Model.validateMeshes(inputMeshes)
    assert(#inputMeshes > 0, "must have one or more meshes")

    local meshes = {}
    local meshesByName = {}
    for _, mesh in ipairs(inputMeshes) do
        local name = mesh:getName()
        if name ~= "" then
            assert(not meshesByName[name], "mesh with duplicate name: %s", name)
            meshesByName[name] = mesh
        end

        table.insert(meshes, mesh)
    end

    return meshes, meshesByName
end

--- @param name string
--- @param meshes RatScratch.Graphics.Graphics3D.Mesh[]
function Model:new(name, meshes)
    local outputMeshes, outputMeshesByName = Model.validateMeshes(meshes)

    self.name = name or ""
    self.meshes = outputMeshes
    self.meshesByName = outputMeshesByName
end

function Model:getName()
    return self.name
end

--- @param key number | string
--- @return RatScratch.Graphics.Graphics3D.Mesh
function Model:getMesh(key)
    if type(key) == "number" then
        assert(self.meshes[key] ~= nil, "no mesh at index %d", key)
        return self.meshes[key]
    elseif type(key) == "string" then
        assert(self.meshesByName[key] ~= nil, "no mesh with given name: %s", key)
        return self.meshesByName[key]
    end

    error("expected \"number\" or \"string\" for parameter \"key\"")
end

function Model:getMeshCount()
    return #self.meshes
end

return Model
