local Vector3 = require "rat-scratch-math.Vector3"
local Common  = require "rat-scratch-math.Common"

local Transform = {}

---@param transform love.Transform
---@param result love.Transform?
---@return love.Transform
function Transform.transposeTransform(transform, result)
    result = result or transform

    local m11, m21, m31, m41,
    m12, m22, m32, m42,
    m13, m23, m33, m43,
    m14, m24, m34, m44 = transform:getMatrix()

    result:setMatrix(
        m11, m12, m13, m14,
        m21, m22, m23, m24,
        m31, m32, m33, m34,
        m41, m42, m43, m44)

    return result
end

--- @param translation RatScratch.Math.Vector3
--- @param transform love.Transform?
--- @return love.Transform
function Transform.makeTranslationTransform(translation, transform)
    transform = transform or love.math.newTransform()

    local m11, m12, m13, m14 = 1, 0, 0, translation.x
    local m21, m22, m23, m24 = 0, 1, 0, translation.y
    local m31, m32, m33, m34 = 0, 0, 1, translation.z
    local m41, m42, m43, m44 = 0, 0, 0, 1

    transform:setMatrix(
        m11, m12, m13, m14,
        m21, m22, m23, m24,
        m31, m32, m33, m34,
        m41, m42, m43, m44)

    return transform
end

--- @param rotation RatScratch.Math.Quaternion
--- @param transform love.Transform?
--- @return love.Transform
function Transform.makeRotationTransform(rotation, transform)
    transform = transform or love.math.newTransform()

    local m11, m12, m13, m14 = 1, 0, 0, 0
    local m21, m22, m23, m24 = 0, 1, 0, 0
    local m31, m32, m33, m34 = 0, 0, 1, 0
    local m41, m42, m43, m44 = 0, 0, 0, 1

    local qxx = rotation.x * rotation.x
    local qyy = rotation.y * rotation.y
    local qzz = rotation.z * rotation.z
    local qxz = rotation.x * rotation.z
    local qxy = rotation.x * rotation.y
    local qyz = rotation.y * rotation.z
    local qwx = rotation.w * rotation.x
    local qwy = rotation.w * rotation.y
    local qwz = rotation.w * rotation.z

    m11 = 1 - 2 * (qyy + qzz)
    m12 = 2 * (qxy + qwz)
    m13 = 2 * (qxz - qwy)

    m21 = 2 * (qxy - qwz)
    m22 = 1 - 2 * (qxx + qzz)
    m23 = 2 * (qyz + qwx)

    m31 = 2 * (qxz + qwy)
    m32 = 2 * (qyz - qwx)
    m33 = 1 - 2 * (qxx + qyy)

    transform:setMatrix(
        m11, m12, m13, m14,
        m21, m22, m23, m24,
        m31, m32, m33, m34,
        m41, m42, m43, m44)

    return transform
end

--- @param scale RatScratch.Math.Vector3
--- @param transform love.Transform
--- @return love.Transform
function Transform.makeScaleTransform(scale, transform)
    transform = transform or love.math.newTransform()

    local m11, m12, m13, m14 = scale.x, 0, 0, 0
    local m21, m22, m23, m24 = 0, scale.y, 0, 0
    local m31, m32, m33, m34 = 0, 0, scale.z, 0
    local m41, m42, m43, m44 = 0, 0, 0, 1

    transform:setMatrix(
        m11, m12, m13, m14,
        m21, m22, m23, m24,
        m31, m32, m33, m34,
        m41, m42, m43, m44)

    return transform
end

--- @param left number
--- @param right number
--- @param bottom number
--- @param top number
--- @param near number
--- @param far number
--- @param transform love.Transform?
--- @return love.Transform
function Transform.makeOrthoTransform(left, right, bottom, top, near, far, transform)
    transform = transform or love.math.newTransform()

    local m11, m12, m13, m14 = 2 / (right - left), 0, 0, -(right + left) / (right - left)
    local m21, m22, m23, m24 = 0, 2 / (top - bottom), 0, -(top + bottom) / (top - bottom)
    local m31, m32, m33, m34 = 0, 0, -2 / (far - near), -(far + near) / (far - near)
    local m41, m42, m43, m44 = 0, 0, 0, 1

    transform:setMatrix(
        m11, m12, m13, m14,
        m21, m22, m23, m24,
        m31, m32, m33, m34,
        m41, m42, m43, m44)

    return transform
end

--- @param fieldOfView number
--- @param aspectRatio number
--- @param near number
--- @param far number
--- @param transform love.Transform?
--- @return love.Transform
function Transform.makePerspectiveTransform(fieldOfView, aspectRatio, near, far, transform)
    local f = 1 / math.tan(fieldOfView / 2)

    local m11, m12, m13, m14 = 0, 0, 0, 0
    local m21, m22, m23, m24 = 0, 0, 0, 0
    local m31, m32, m33, m34 = 0, 0, 0, 0
    local m41, m42, m43, m44 = 0, 0, 0, 0

    m11 = -(f / aspectRatio)
    m22 = f
    m33 = (far + near) / (near - far)
    m34 = (2 * far * near) / (near - far)
    m43 = -1

    transform = transform or love.math.newTransform()
    transform:setMatrix(
        m11, m12, m13, m14,
        m21, m22, m23, m24,
        m31, m32, m33, m34,
        m41, m42, m43, m44)

    return transform
end

--- @param projectionView love.Transform
--- @param point RatScratch.Math.Vector3
--- @param viewportX number
--- @param viewportY number
--- @param viewportWidth number
--- @param viewportHeight number
--- @param result RatScratch.Math.Vector3
--- @return RatScratch.Math.Vector3
function Transform.project(projectionView, point, viewportX, viewportY, viewportWidth, viewportHeight, result)
    result = result or Vector3()

    local x, y, z = point:transform(projectionView, result):get()
    x = viewportX + (x + 1) / 2 * viewportWidth
    y = viewportY + (y + 1) / 2 * viewportHeight

    return result:from(x, y, z)
end

--- @param inverseProjectionView love.Transform
--- @param point RatScratch.Math.Vector3
--- @param result RatScratch.Math.Vector3?
--- @return RatScratch.Math.Vector3
function Transform.unproject(inverseProjectionView, point, result)
    result = result or Vector3()

    local _, w = point:perspectiveTransform(inverseProjectionView, 1, result)
    if math.abs(w) > Common.EPSILON then
        local inverseW = 1 / w
        result:from(
            result.x * inverseW,
            result.y * inverseW,
            result.z * inverseW)
    end

    return result
end

do
    local workingTransform = love.math.newTransform()

    function Transform.compose(translation, rotation, scale, transform)
        transform = transform or love.math.newTransform()
        transform:reset()

        if scale then
            Transform.makeScaleTransform(scale, workingTransform)
            transform:apply(workingTransform)
        end

        if rotation then
            Transform.makeRotationTransform(rotation, workingTransform)
            transform:apply(workingTransform)
        end

        if translation then
            Transform.makeTranslationTransform(translation, workingTransform)
            transform:apply(workingTransform)
        end

        return transform
    end
end

return Transform
