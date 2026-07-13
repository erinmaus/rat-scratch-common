struct RatScratchSkinnedMeshStaticVertex {
  vec4 textureCoordinate;
  vec4 color;
};

struct RatScratchSkinnedMeshInputVertex {
  vec4 position;
  vec4 normal;
  uvec4 boneIndex;
  vec4 boneWeight;
};

struct RatScratchSkinnedMeshOutputVertex {
  vec4 position;
  vec4 normal;
};
