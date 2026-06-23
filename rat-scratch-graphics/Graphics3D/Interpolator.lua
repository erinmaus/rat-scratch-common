local Vector3 = require ("rat-scratch-math").Vector3
local Quaternion = require ("rat-scratch-math").Quaternion

--- @alias RatScratch.Graphics.Graphics3D.InterpolatorType "step" | "linear" | "cubicSpline"

--- @type table<RatScratch.Graphics.Graphics3D.InterpolatorType, RatScratch.Graphics.Graphics3D.Interpolator>
local Interpolator = {}

local lerpOrSlerp = {
    [Vector3] = Vector3.lerp,
    [Quaternion] = function(from, to, delta, result)
        from:slerp(to, delta, result)
        result:normalize(result)
    end
}

--- @param t number
--- @param keyFrame1 RatScratch.Graphics.Graphics3D.KeyFrame
--- @param keyFrame2 RatScratch.Graphics.Graphics3D.KeyFrame
local function getCubicSplineControlValues(t, keyFrame1, keyFrame2)
    local deltaTime = keyFrame2.time - keyFrame1.time
    local s = (t - keyFrame1.time) / deltaTime
    s = math.min(math.max(s, 0), 1)

    local s2 = s * s
    local s3 = s2 * s

    local c1 = 2 * s3 - 3 * s2 + 1
    local c2 = (s3 - 2 * s2 + s) * deltaTime
    local c3 = -2 * s3 + 3 * s2
    local c4 = (s3 - s2) * deltaTime

    return c1, c2, c3, c4
end

--- @param t number
--- @param result RatScratch.Math.Quaternion
--- @param keyFrame1 RatScratch.Graphics.Graphics3D.KeyFrame
--- @param keyFrame2 RatScratch.Graphics.Graphics3D.KeyFrame
local function cubicSplineQuaternion(t, result, keyFrame1, keyFrame2)
    local c1, c2, c3, c4 = getCubicSplineControlValues(t, keyFrame1, keyFrame2)

    result:from(
        c1 * keyFrame1.value.x + c2 * keyFrame1.outTangent.x + c3 * keyFrame2.value.x + c4 * keyFrame2.inTangent.x,
        c1 * keyFrame1.value.y + c2 * keyFrame1.outTangent.y + c3 * keyFrame2.value.y + c4 * keyFrame2.inTangent.y,
        c1 * keyFrame1.value.z + c2 * keyFrame1.outTangent.z + c3 * keyFrame2.value.z + c4 * keyFrame2.inTangent.z,
        c1 * keyFrame1.value.w + c2 * keyFrame1.outTangent.w + c3 * keyFrame2.value.w + c4 * keyFrame2.inTangent.w)
end

--- @param t number
--- @param result RatScratch.Math.Vector3
--- @param keyFrame1 RatScratch.Graphics.Graphics3D.KeyFrame
--- @param keyFrame2 RatScratch.Graphics.Graphics3D.KeyFrame
local function cubicSplineVector3(t, result, keyFrame1, keyFrame2)
    local c1, c2, c3, c4 = getCubicSplineControlValues(t, keyFrame1, keyFrame2)

    result:from(
        c1 * keyFrame1.value.x + c2 * keyFrame1.outTangent.x + c3 * keyFrame2.value.x + c4 * keyFrame2.inTangent.x,
        c1 * keyFrame1.value.y + c2 * keyFrame1.outTangent.y + c3 * keyFrame2.value.y + c4 * keyFrame2.inTangent.y,
        c1 * keyFrame1.value.z + c2 * keyFrame1.outTangent.z + c3 * keyFrame2.value.z + c4 * keyFrame2.inTangent.z)
end

--- @type table<any, RatScratch.Graphics.Graphics3D.Interpolator>
local cubicSpline = {
    [Quaternion] = cubicSplineQuaternion,
    [Vector3] = cubicSplineVector3
}

--- @alias RatScratch.Graphics.Graphics3D.Interpolator fun(time: number, result: RatScratch.Graphics.Graphics3D.KeyFrameValue, currentKeyFrame: RatScratch.Graphics.Graphics3D.KeyFrame, afterKeyFrame: RatScratch.Graphics.Graphics3D.KeyFrame)

--- @param time number
--- @param result RatScratch.Graphics.Graphics3D.KeyFrameValue
--- @param currentKeyFrame RatScratch.Graphics.Graphics3D.KeyFrame
--- @param afterKeyFrame RatScratch.Graphics.Graphics3D.KeyFrame
function Interpolator.step(time, result, currentKeyFrame, afterKeyFrame)
    --- @cast result any
    result:from(currentKeyFrame.value:get())
end

--- @param time number
--- @param result RatScratch.Graphics.Graphics3D.KeyFrameValue
--- @param currentKeyFrame RatScratch.Graphics.Graphics3D.KeyFrame
--- @param afterKeyFrame RatScratch.Graphics.Graphics3D.KeyFrame
function Interpolator.linear(time, result, currentKeyFrame, afterKeyFrame)
    local delta = (time - currentKeyFrame.time) / (afterKeyFrame.time - currentKeyFrame.time)
    delta = math.min(math.max(delta, 0), 1)

    local func = lerpOrSlerp[currentKeyFrame.type]
    func(currentKeyFrame.value, afterKeyFrame.value, delta, result)
end

--- @param time number
--- @param result RatScratch.Graphics.Graphics3D.KeyFrameValue
--- @param currentKeyFrame RatScratch.Graphics.Graphics3D.KeyFrame
--- @param afterKeyFrame RatScratch.Graphics.Graphics3D.KeyFrame
function Interpolator.cubicSpline(time, result, currentKeyFrame, afterKeyFrame)
    local func = cubicSpline[currentKeyFrame.type]
    func(time, result, currentKeyFrame, afterKeyFrame)
end

return Interpolator
