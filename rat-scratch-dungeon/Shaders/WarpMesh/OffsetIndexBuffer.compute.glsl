#pragma language glsl4

#include "./Types.common.glsl"

layout(local_size_x = 64, local_size_y = 1) in;

restrict buffer rat_WarpedMeshInputIndexBuffer {
  uint rat_WarpedMeshInputIndices[];
};

restrict buffer rat_WarpedMeshOutputIndexBuffer {
  uint rat_WarpedMeshOutputIndices[];
};

restrict buffer rat_WarpedMeshIndexInfoBuffer {
  RatScratchWarpedMeshIndexInfo rat_WarpedMeshes[];
};

void computemain() {
  uint index = gl_GlobalInvocationID.x;
  uint meshIndex = gl_GlobalInvocationID.y;

  RatScratchWarpedMeshIndexInfo meshInfo = rat_WarpedMeshes[meshIndex];
  uint indexCount = meshInfo.count;

  if (index >= meshInfo.count) {
    return;
  }

  uint inputIndex = rat_WarpedMeshInputIndices[meshInfo.inputOffset + index];
  rat_WarpedMeshOutputIndices[meshInfo.outputOffset + index] =
      inputIndex + meshInfo.vertexOffset;
}
