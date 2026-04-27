// ============================================================
// layer_ground.glsl
// Low-frequency sinusoidal heightfield.
// Attenuated near x = 0 so the walking path stays smoother than
// the edges, reinforcing the corridor composition.
// Returns vec3(distance, shadingAux, MAT_GROUND).
// ============================================================

vec3 layerGround(vec3 p) {
  float edge = smoothstep(0.0, 2.2, abs(p.x));
  float h = (sin(p.x * 0.45) * 0.08 +
             sin(p.z * 0.32) * 0.14 +
             sin(p.x * 1.35 + p.z * 0.9) * 0.06) * edge;
  float d = p.y - (GROUND_Y + h);
  // Multiply by 0.75 to stay conservative under the gradient of the heightfield.
  return vec3(d * 0.75, 0.0, MAT_GROUND);
}
