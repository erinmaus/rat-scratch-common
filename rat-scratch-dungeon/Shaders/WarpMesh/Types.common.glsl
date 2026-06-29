struct RatScratchWarpedMeshVertex {
  vec4 position;
  vec4 normal;
};

struct RatScratchWarpedMeshCurveVertex {
  vec2 position;
  float extent;
  float smoothness;
};

struct RatScratchWarpedMeshInfo {
  // x = left, y = right
  vec2 bounds;
  uint inputOffset;
  uint outputOffset;
  uint vertexCount;
  uint curveSubsectionIndex;
};

struct RatScratchWarpedMeshCurveInfo {
  uint curveOffset;
  uint vertexCount;
  uint closed;
  float extent;
};

struct RatScratchWarpedMeshCurveSubsectionInfo {
  uint curveIndex;
  uint curveOffset;
  uint vertexCount;
  float extent;
};
