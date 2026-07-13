layout(local_size_x = 64, local_size_y = 1) in;

#include "@/Math/Barycentric.common.glsl"
#include "@/Math/Ray.common.glsl"
#include "@/SkinnedModel/Types.common.glsl"

uniform mat4 rat_WorldMatrix;

restrict readonly buffer rat_SkinnedVerticesBuffer {
  RatScratchSkinnedMeshOutputVertex rat_SkinnedVertices[];
};

restrict buffer rat_StaticVerticesBuffer {
  RatScratchSkinnedMeshStaticVertex rat_StaticVertices[];
};

restrict readonly buffer rat_IndicesBuffer { uint rat_Indices[]; };

uniform uint rat_TriangleCount;

struct Ray {
  vec3 origin;
  vec3 direction;
};

restrict readonly buffer rat_RayBuffer { Ray rat_Rays[]; };

struct RayHitInfo {
  uint count;
};

buffer rat_RayHitInfoBuffer { RayHitInfo rat_RayHitInfo[]; };

struct RayHit {
  uint hit;
  uint ray; // 4

  vec3 worldCoordinate;   // 16
  vec2 textureCoordinate; //

  vec2 textureCoordinateA;
  vec2 textureCoordinateB;
  vec2 textureCoordinateC;

  vec3 worldCoordinateA;
  vec3 worldCoordinateB;
  vec3 worldCoordinateC;
};

buffer rat_RayHitsBuffer { RayHit rat_RayHits[]; };

uniform uint rat_RayCount;
uniform uint rat_RayHitCount;

void computemain() {
  uint triangleIndex = gl_GlobalInvocationID.x;
  uint rayIndex = gl_GlobalInvocationID.y;

  if (triangleIndex >= rat_TriangleCount || rayIndex >= rat_RayCount) {
    return;
  }

  uint baseIndex = triangleIndex * 3;
  uint i = rat_Indices[baseIndex];
  uint j = rat_Indices[baseIndex + 1];
  uint k = rat_Indices[baseIndex + 2];

  vec2 s = rat_StaticVertices[i].textureCoordinate.st;
  vec2 t = rat_StaticVertices[j].textureCoordinate.st;
  vec2 r = rat_StaticVertices[k].textureCoordinate.st;

  vec3 a = (rat_WorldMatrix * rat_SkinnedVertices[i].position).xyz;
  vec3 b = (rat_WorldMatrix * rat_SkinnedVertices[j].position).xyz;
  vec3 c = (rat_WorldMatrix * rat_SkinnedVertices[k].position).xyz;

  Ray ray = rat_Rays[rayIndex];

  float projection;
  float side;
  vec3 barycentricCoordinates;
  if (intersectRayTriangle(ray.origin, ray.direction, a, b, c, projection, side,
                           barycentricCoordinates) &&
      side >= 1) {
    vec3 worldCoordinate = ray.origin + projection * ray.direction;
    cartesianToBarycentric(worldCoordinate, a, b, c, barycentricCoordinates);

    vec2 textureCoordinate =
        barycentricToCartesian(barycentricCoordinates, s, t, r);

    uint rayHitIndex = atomicAdd(rat_RayHitInfo[0].count, 1);
    if (rayHitIndex < rat_RayHitCount) {
      RayHit hit;

      hit.hit = 1;
      hit.ray = rayIndex;
      hit.worldCoordinate = worldCoordinate;
      hit.textureCoordinate = textureCoordinate;
      hit.textureCoordinateA = s;
      hit.textureCoordinateB = t;
      hit.textureCoordinateC = r;
      hit.worldCoordinateA = a;
      hit.worldCoordinateB = b;
      hit.worldCoordinateC = c;

      rat_RayHits[rayHitIndex] = hit;
    }
  }
}
