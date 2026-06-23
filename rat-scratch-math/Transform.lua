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
    m21 = 2 * (qxy + qwz)
    m31 = 2 * (qxz - qwy)

    m12 = 2 * (qxy - qwz)
    m22 = 1 - 2 * (qxx + qzz)
    m32 = 2 * (qyz + qwx)

    m13 = 2 * (qxz + qwy)
    m23 = 2 * (qyz - qwx)
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

--- @param left number
--- @param right number
--- @param bottom number
--- @param top number
--- @param near number
--- @param far number
--- @param transform love.Transform?
--- @return love.Transform
function Transform.makeFrustumTransform(left, right, bottom, top, near, far, transform)
    transform = transform or love.math.newTransform()

    local xRange = right - left
    local yRange = top - bottom
    local zRange = near - far

    local m11 = (2 * near) / xRange
    local m13 = (right + left) / zRange
    local m14 = (2 * right * near) / zRange

    local m22 = (2 * near) / yRange
    local m23 = (top + bottom) / zRange
    local m24 = (2 * top * near) / zRange

    local m33 = (far + near) / zRange
    local m34 = (2 * far * near) / zRange
    local m43 = -1

    transform:setMatrix(
        m11, 0, m13, m14,
        0, m22, m23, m24,
        0, 0, m33, m34,
        0, 0, m43, 0)

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

do
    local F = Vector3()
    local U = Vector3()
    local f = Vector3()
    local s = Vector3()
    local u = Vector3()

    --- @param eye RatScratch.Math.Vector3
    --- @param center RatScratch.Math.Vector3
    --- @param up? RatScratch.Math.Vector3
    --- @param transform? love.Transform
    function Transform.lookAt(eye, center, up, transform)
        transform = transform or love.math.newTransform()

        up = up or Vector3.UNIT_Y

        center:subtract(eye, F):normalize(f)
        up:normalize(U)

        f:cross(U, s):normalize(s)
        s:cross(f, u):normalize(u)

        local m14 = -(s.x * eye.x + s.y * eye.y + s.z * eye.z)
        local m24 = -(u.x * eye.x + u.y * eye.y + u.z * eye.z)
        local m34 = (f.x * eye.x + f.y * eye.y + f.z * eye.z)

        transform:setMatrix(
            s.x, s.y, s.z, m14,
            u.x, u.y, u.z, m24,
            -f.x, -f.y, -f.z, m34,
            0, 0, 0, 1)

        return transform
    end
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

function Transform.compose(translation, rotation, scale, transform)
    transform = transform or love.math.newTransform()

    local tx, ty, tz = 0, 0, 0
    if translation then
        tx, ty, tz = translation.x, translation.y, translation.z
    end

    local sx, sy, sz = 1, 1, 1
    if scale then
        sx, sy, sz = scale.x, scale.y, scale.z
    end

    local r11, r12, r13 = 1, 0, 0
    local r21, r22, r23 = 0, 1, 0
    local r31, r32, r33 = 0, 0, 1

    if rotation then
        local qxx = rotation.x * rotation.x
        local qyy = rotation.y * rotation.y
        local qzz = rotation.z * rotation.z
        local qxz = rotation.x * rotation.z
        local qxy = rotation.x * rotation.y
        local qyz = rotation.y * rotation.z
        local qwx = rotation.w * rotation.x
        local qwy = rotation.w * rotation.y
        local qwz = rotation.w * rotation.z

        r11 = 1 - 2 * (qyy + qzz)
        r21 = 2 * (qxy + qwz)
        r31 = 2 * (qxz - qwy)

        r12 = 2 * (qxy - qwz)
        r22 = 1 - 2 * (qxx + qzz)
        r32 = 2 * (qyz + qwx)

        r13 = 2 * (qxz + qwy)
        r23 = 2 * (qyz - qwx)
        r33 = 1 - 2 * (qxx + qyy)
    end

    transform:setMatrix(
        r11 * sx, r12 * sy, r13 * sz, tx,
        r21 * sx, r22 * sy, r23 * sz, ty,
        r31 * sx, r32 * sy, r33 * sz, tz,
        0, 0, 0, 1)

    return transform
end

return Transform
