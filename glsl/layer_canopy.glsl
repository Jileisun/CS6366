// ============================================================
// layer_canopy.glsl
// Sparse overhead connective structure: a two-segment arched
// capsule from the left trunk top to the right trunk top.
// Only ~45% of cells spawn an arch, so the canopy suggests
// ecosystem connectivity without destroying readability.
// Returns vec3(distance, shadingAux, MAT_CANOPY).
// ============================================================

vec3 layerCanopy(vec3 p) {
  float dMin = 1e9;
  float aux = 0.0;

  float cellBase = floor(p.z / TRUNK_SPACING);
  for (int s = -1; s <= 1; s++) {
    float cellZ = cellBase + float(s);
    float cz = cellZ * TRUNK_SPACING;
    if (cz < TRUNK_Z_START || cz > TRUNK_Z_END) continue;
    if (hash11(cellZ * 13.37) < 0.55) continue;

    float archH = 3.1 + hash11(cellZ * 17.11) * 0.9;
    float sag   = (hash11(cellZ * 5.19) - 0.5) * 0.4;
    vec3 a = vec3(-CORRIDOR_SIDE, 2.0, cz);
    vec3 c = vec3(0.0 + sag, archH, cz + (hash11(cellZ * 3.77) - 0.5) * 0.5);
    vec3 b = vec3( CORRIDOR_SIDE, 2.0, cz);

    float d = min(sdCapsule(p, a, c, 0.11), sdCapsule(p, c, b, 0.11));
    if (d < dMin) { dMin = d; aux = hash11(cellZ * 19.3); }
  }
  return vec3(dMin, aux, MAT_CANOPY);
}
