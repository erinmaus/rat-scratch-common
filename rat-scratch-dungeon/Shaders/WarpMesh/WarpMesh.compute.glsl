#pragma language glsl4

#include "./Types.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"

layout(local_size_x = 64, local_size_y = 1) in;

restrict buffer rat_WarpedInputMeshVertexBuffer {
  RatScratchWarpedMeshVertex rat_WarpedInputMeshVertices[];
};

restrict buffer rat_WarpedOutputMeshVerticesBuffer {
  RatScratchWarpedMeshVertex rat_WarpedOutputMeshVertices[];
};

restrict buffer rat_WarpedMeshCurveVertexBuffer {
  RatScratchWarpedMeshCurveVertex rat_WarpedMeshCurveVertices[];
};

restrict buffer rat_WarpedMeshMeshInfoBuffer {
  RatScratchWarpedMeshInfo rat_WarpedMeshes[];
};

restrict buffer rat_WarpedMeshTileInfoBuffer {
  RatScratchWarpedMeshTileInfo rat_WarpedMeshTiles[];
};

restrict buffer rat_WarpedMeshCurveInfoBuffer {
  RatScratchWarpedMeshCurveInfo rat_WarpedMeshCurves[];
};

restrict buffer rat_WarpedMeshCurveSubsectionInfoBuffer {
  RatScratchWarpedMeshCurveSubsectionInfo rat_WarpedMeshCurveSubsections[];
};

uniform mat4 rat_ModelTransform;
uniform mat4 rat_NormalTransform;
uniform uint rat_CurveVertexCount;

uint getCurveVertexIndex(int index, int offset, int curveCount, uint closed) {
  int relativeClampedIndex;
  if (closed == 1) {
    // First, if negative, transform to a positive index. Then, wrap positive
    // index.
    relativeClampedIndex = (index % curveCount) + curveCount;
    relativeClampedIndex %= curveCount;
  } else {
    relativeClampedIndex = clamp(index, 0, curveCount - 1);
  }

  return uint(relativeClampedIndex + offset);
}

void evaluateCurve(float t, uint tileIndex, out vec2 farVertex,
                   out vec2 previousVertex, out vec2 currentVertex,
                   out vec2 nextVertex, out float smoothness, out float s) {
  RatScratchWarpedMeshTileInfo tileInfo = rat_WarpedMeshTiles[tileIndex];
  RatScratchWarpedMeshInfo meshInfo = rat_WarpedMeshes[tileInfo.meshIndex];
  RatScratchWarpedMeshCurveSubsectionInfo curveSubsectionInfo =
      rat_WarpedMeshCurveSubsections[tileInfo.curveSubsectionIndex];
  RatScratchWarpedMeshCurveInfo curveInfo =
      rat_WarpedMeshCurves[curveSubsectionInfo.curveIndex];

  float targetSum = curveSubsectionInfo.extent * t;

  int k = 0;
  float sum = 0.0;

  uint startIndex = curveInfo.offset + curveSubsectionInfo.offset;
  uint stopIndex = min(startIndex + curveSubsectionInfo.count,
                       curveInfo.offset + curveInfo.count);
  for (uint i = startIndex; i <= stopIndex; ++i) {
    if (i == stopIndex) {
      s = 1.0;
      break;
    }

    float extent = rat_WarpedMeshCurveVertices[i].extent;
    float nextSum = sum + extent;
    if (nextSum >= targetSum) {
      s = (targetSum - sum) / max(extent, RAT_EPSILON);
      break;
    }

    sum = nextSum;
    ++k;
  }

  s = clamp(s, 0.0, 1.0);

  int offset = int(startIndex);
  int curveVertexCount = int(curveInfo.count);
  uint curveClosed = curveInfo.closed;

  uint farVertexIndex =
      getCurveVertexIndex(k - 1, offset, curveVertexCount, curveClosed);
  uint previousVertexIndex =
      getCurveVertexIndex(k, offset, curveVertexCount, curveClosed);
  uint currentVertexIndex =
      getCurveVertexIndex(k + 1, offset, curveVertexCount, curveClosed);
  uint nextVertexIndex =
      getCurveVertexIndex(k + 2, offset, curveVertexCount, curveClosed);

  farVertex = rat_WarpedMeshCurveVertices[farVertexIndex].position;
  previousVertex = rat_WarpedMeshCurveVertices[previousVertexIndex].position;
  currentVertex = rat_WarpedMeshCurveVertices[currentVertexIndex].position;
  nextVertex = rat_WarpedMeshCurveVertices[nextVertexIndex].position;

  float fromS = rat_WarpedMeshCurveVertices[previousVertexIndex].smoothness;
  float toS = rat_WarpedMeshCurveVertices[currentVertexIndex].smoothness;

  smoothness = mix(fromS, toS, s);
}

void transformByCurve(uint tileIndex, vec2 bounds, inout vec4 position,
                      inout vec4 normal) {
  float left = bounds.x;
  float right = bounds.y;
  float t = (position.x - left) / (right - left);

  vec2 farVertex, previousVertex, currentVertex, nextVertex;
  float smoothness, s;
  evaluateCurve(t, tileIndex, farVertex, previousVertex, currentVertex,
                nextVertex, smoothness, s);

  vec2 positionLinear = previousVertex + s * (currentVertex - previousVertex);
  vec2 tangentLinear = currentVertex - previousVertex;

  float sSquared = s * s;
  float sCubed = sSquared * s;
  vec2 positionCatmull =
      0.5 *
      ((2.0 * previousVertex) + (-farVertex + currentVertex) * s +
       (2.0 * farVertex - 5.0 * previousVertex + 4.0 * currentVertex -
        nextVertex) *
           sSquared +
       (-farVertex + 3.0 * previousVertex - 3.0 * currentVertex + nextVertex) *
           sCubed);
  vec2 tangentCatmull = 0.5 * ((-farVertex + currentVertex) +
                               2.0 *
                                   (2.0 * farVertex - 5.0 * previousVertex +
                                    4.0 * currentVertex - nextVertex) *
                                   s +
                               3.0 *
                                   (-farVertex + 3.0 * previousVertex -
                                    3.0 * currentVertex + nextVertex) *
                                   sSquared);

  vec2 blendedPosition = mix(positionLinear, positionCatmull, smoothness);
  vec2 blendedTangent = mix(tangentLinear, tangentCatmull, smoothness);

  vec2 T = safeNormalize(blendedTangent);
  vec2 N = vec2(-T.y, T.x);
  mat3 worldMatrix =
      mat3(vec3(T.x, 0.0, T.y), vec3(0.0, 1.0, 0.0), vec3(N.x, 0.0, N.y));

  position.xz = blendedPosition + (vec2(position.z) * N);
  normal.xyz = normalize(worldMatrix * normal.xyz);
}

void computemain() {
  uint vertexIndex = gl_GlobalInvocationID.x;
  uint tileIndex = gl_GlobalInvocationID.y;

  RatScratchWarpedMeshTileInfo tileInfo = rat_WarpedMeshTiles[tileIndex];
  uint meshIndex = tileInfo.meshIndex;

  RatScratchWarpedMeshInfo meshInfo = rat_WarpedMeshes[meshIndex];
  if (vertexIndex >= meshInfo.count) {
    return;
  }

  RatScratchWarpedMeshVertex vertex =
      rat_WarpedInputMeshVertices[meshInfo.offset + vertexIndex];

  vertex.position = meshInfo.transform * vertex.position;
  vertex.normal.xyz =
      transpose(inverse(mat3(meshInfo.transform))) * vertex.normal.xyz;

  transformByCurve(tileIndex, meshInfo.bounds, vertex.position, vertex.normal);
  vertex.position.w = 1.0;
  vertex.normal.w = 0.0;

  rat_WarpedOutputMeshVertices[tileInfo.offset + vertexIndex] = vertex;
}
