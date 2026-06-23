#pragma language glsl4

layout(local_size_x = 64) in;

#include "./Types.common.glsl"

restrict buffer rat_SkinnedMeshInputVerticesBuffer {
    RatScratchSkinnedMeshInputVertex rat_SkinnedMeshInputVertices[];
};

restrict buffer rat_SkinnedMeshOutputVerticesBuffer {
    RatScratchSkinnedMeshOutputVertex rat_SkinnedMeshOutputVertices[];
};

restrict buffer rat_BoneMatrixBuffer {
    mat4 rat_BoneMatrix[];
};

uniform uint rat_VertexCount;

void computemain() {
    uint index = gl_GlobalInvocationID.x;

    if (index >= rat_VertexCount)
    {
        return;
    }

    RatScratchSkinnedMeshInputVertex inputVertex = rat_SkinnedMeshInputVertices[index];

    vec4 position = vec4(inputVertex.position.xyz, 1.0);
    vec3 normal = inputVertex.normal.xyz;
    uvec4 boneIndex = inputVertex.boneIndex;
    vec4 boneWeight = inputVertex.boneWeight;

    vec4 finalPosition = vec4(0.0);
    vec3 finalNormal = vec3(0.0);

    for (int i = 0; i < 4; i++) {
        uint boneID = boneIndex[i];
        float weight = boneWeight[i];

        if (weight > 0.0) {
            mat4 boneMatrix = rat_BoneMatrix[boneID];
            finalPosition += boneMatrix * position * vec4(weight);
            finalNormal += mat3(boneMatrix) * normal * vec3(weight);
        }
    }

    rat_SkinnedMeshOutputVertices[index].position = finalPosition;
    rat_SkinnedMeshOutputVertices[index].normal = vec4(normalize(finalNormal), 0.0);
}
