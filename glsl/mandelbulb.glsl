// ============================================================
// mandelbulb.glsl
// Standalone Mandelbulb distance estimator.
// Exposed as mbDE(p) -> (signed distance, orbit trap).
// Used only inside layer_focal (gated by a bounding sphere),
// kept small so the hero fractal stays the corridor's design
// element without paying its cost on every ray.
// ============================================================

vec2 mbDE(vec3 p) {
  vec3 z = p;
  float dr = 1.0;
  float r = 0.0;
  float trap = 1.0e10;

  for (int i = 0; i < 8; i++) {
    r = length(z);
    trap = min(trap, r);
    if (r > BAILOUT) break;

    float safeR = max(r, 1.0e-6);
    float theta = acos(clamp(z.z / safeR, -1.0, 1.0));
    float phi = atan(z.y, z.x);
    float zr = pow(safeR, POWER);

    dr = POWER * pow(safeR, POWER - 1.0) * dr + 1.0;
    theta *= POWER;
    phi *= POWER;

    z = zr * vec3(
      sin(theta) * cos(phi),
      sin(theta) * sin(phi),
      cos(theta)
    );
    z += p;
  }

  float safeR = max(r, 1.0e-6);
  float dist = 0.5 * log(safeR) * safeR / dr;
  return vec2(dist, trap);
}
