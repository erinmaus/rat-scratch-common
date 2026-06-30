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
  uint offset;
  uint count;
  mat4 transform;
};

struct RatScratchWarpedMeshIndexInfo {
  uint inputOffset;
  uint outputOffset;
  uint vertexOffset;
  uint count;
};

struct RatScratchWarpedMeshTileInfo {
  uint meshIndex;
  uint offset;
  uint curveSubsectionIndex;
};

struct RatScratchWarpedMeshCurveInfo {
  uint offset;
  uint count;
  uint closed;
  float extent;
};

struct RatScratchWarpedMeshCurveSubsectionInfo {
  uint curveIndex;
  uint offset;
  uint count;
  float extent;
};
