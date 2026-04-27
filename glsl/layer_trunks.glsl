// ============================================================
// layer_trunks.glsl
// Two rows of tall organic pillars along +z.
// Domain-repeated along z (period = TRUNK_SPACING). Every cell
// seeds an independent left and right trunk with per-instance
// height / radius / tilt / jitter / emissive factor via hash11.
// Cheap capsule + root-bulge + top-bulb — NOT a full Mandelbulb,
// so the corridor population stays real-time.
// Returns vec3(distance, shadingAux = emissive factor, MAT_TRUNK).
// ============================================================

vec3 layerTrunks(vec3 p) {
  float dMin = 1e9;
  float aux = 0.0;

  float cellBase = floor(p.z / TRUNK_SPACING);

  // search the 3-cell neighborhood so trunks read continuously
  for (int s = -1; s <= 1; s++) {
    float cellZ = cellBase + float(s);
    float cz = cellZ * TRUNK_SPACING;
    if (cz < TRUNK_Z_START - 1.0 || cz > TRUNK_Z_END + 1.0) continue;

    // ---- left trunk ----
    {
      float seed = cellZ * 7.131 + 13.0;
      float jz = (hash11(seed) - 0.5) * 0.9;
      float jx = hash11(seed + 1.7) * 0.45;
      float h  = 2.2 + hash11(seed + 2.3) * 1.9;
      float rB = 0.18 + hash11(seed + 3.1) * 0.10;
      float tx = (hash11(seed + 4.9) - 0.5) * 0.6;
      float em = hash11(seed + 5.4);

      vec3 base = vec3(-CORRIDOR_SIDE - jx, GROUND_Y, cz + jz);
      vec3 top  = base + vec3(tx, h, (hash11(seed + 6.3) - 0.5) * 0.3);

      float d = sdCapsule(p, base, top, rB);
      d = opSmin(d, sdSphere(p - base - vec3(0.0, 0.05, 0.0), rB * 1.7), 0.22);
      float rTop = rB * (1.3 + em * 0.7);
      d = opSmin(d, sdSphere(p - top, rTop), 0.32);

      if (d < dMin) { dMin = d; aux = em; }
    }

    // ---- right trunk (independent seed so the corridor is not mirrored) ----
    {
      float seed = cellZ * 11.71 + 97.0;
      float jz = (hash11(seed) - 0.5) * 0.9;
      float jx = hash11(seed + 1.7) * 0.45;
      float h  = 2.2 + hash11(seed + 2.3) * 1.9;
      float rB = 0.18 + hash11(seed + 3.1) * 0.10;
      float tx = (hash11(seed + 4.9) - 0.5) * 0.6;
      float em = hash11(seed + 5.4);

      vec3 base = vec3(CORRIDOR_SIDE + jx, GROUND_Y, cz + jz);
      vec3 top  = base + vec3(-tx, h, (hash11(seed + 6.3) - 0.5) * 0.3);

      float d = sdCapsule(p, base, top, rB);
      d = opSmin(d, sdSphere(p - base - vec3(0.0, 0.05, 0.0), rB * 1.7), 0.22);
      float rTop = rB * (1.3 + em * 0.7);
      d = opSmin(d, sdSphere(p - top, rTop), 0.32);

      if (d < dMin) { dMin = d; aux = em; }
    }
  }

  return vec3(dMin, aux, MAT_TRUNK);
}
