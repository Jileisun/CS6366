// ============================================================
// layer_clusters.glsl
// Small ecosystem growths: cheap sphere unions concentrated at
// trunk bases (left + right) plus rare center sprouts. Provides
// foreground detail and scale without expensive geometry.
// Returns vec3(distance, shadingAux, MAT_CLUSTER).
// ============================================================

vec3 layerClusters(vec3 p) {
  float dMin = 1e9;
  float aux = 0.0;

  float cellBase = floor(p.z / TRUNK_SPACING);
  for (int s = -1; s <= 1; s++) {
    float cellZ = cellBase + float(s);
    float cz = cellZ * TRUNK_SPACING;

    // ---- left base cluster ----
    {
      float seed = cellZ * 7.131 + 41.0;
      float jx = hash11(seed) * 0.35;
      float jz = (hash11(seed + 2.1) - 0.5) * 0.8;
      vec3 c = vec3(-CORRIDOR_SIDE - jx + 0.25, GROUND_Y + 0.1, cz + jz);
      float d = sdSphere(p - c, 0.22);
      d = opSmin(d, sdSphere(p - c - vec3( 0.22, 0.04, 0.08), 0.14), 0.1);
      d = opSmin(d, sdSphere(p - c - vec3(-0.15, 0.09, -0.1), 0.12), 0.1);
      if (d < dMin) { dMin = d; aux = hash11(seed + 5.0); }
    }
    // ---- right base cluster ----
    {
      float seed = cellZ * 11.71 + 83.0;
      float jx = hash11(seed) * 0.35;
      float jz = (hash11(seed + 2.1) - 0.5) * 0.8;
      vec3 c = vec3(CORRIDOR_SIDE + jx - 0.25, GROUND_Y + 0.1, cz + jz);
      float d = sdSphere(p - c, 0.2);
      d = opSmin(d, sdSphere(p - c - vec3(-0.2,  0.04, 0.08), 0.13), 0.1);
      d = opSmin(d, sdSphere(p - c - vec3( 0.15, 0.09, -0.1), 0.12), 0.1);
      if (d < dMin) { dMin = d; aux = hash11(seed + 5.0); }
    }
    // ---- occasional center sprout ----
    {
      float seed = cellZ * 5.33 + 191.0;
      if (hash11(seed) > 0.65) {
        float jx = (hash11(seed + 1.0) - 0.5) * 0.9;
        float jz = (hash11(seed + 2.0) - 0.5) * 0.7;
        vec3 c = vec3(jx, GROUND_Y + 0.05, cz + jz);
        float d = sdSphere(p - c, 0.11);
        d = opSmin(d, sdSphere(p - c - vec3(0.0, 0.08, 0.0), 0.08), 0.08);
        if (d < dMin) { dMin = d; aux = hash11(seed + 5.0); }
      }
    }
  }
  return vec3(dMin, aux, MAT_CLUSTER);
}
