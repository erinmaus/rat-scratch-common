vec2 evaluateCatmullRom(float s, vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
  float s2 = s * s;
  float s3 = s2 * s;

  vec2 c1 = 2.0 * p1;
  vec2 c2 = -p0 + p2;
  vec2 c3 = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3;
  vec2 c4 = -p0 + 3.0 * p1 - 3.0 * p2 + p3;

  return 0.5 * (c1 + c2 * s + c3 * s2 + c4 * s3);
}

vec2 evaluateCatmullRomTangent(float s, vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
  float s2 = s * s;

  vec2 t1 = -p0 + p2;
  vec2 t2 = 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3);
  vec2 t3 = 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3);

  return 0.5 * (t1 + t2 * s + t3 * s2);
}
