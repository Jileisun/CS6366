// ============================================================
// layer_focal.glsl
// The single distant Mandelbulb-derived hero that anchors the
// corridor composition. A bounding sphere gates the expensive
// DE so rays far from the focal never pay for the fractal loop.
// Returns vec3(distance, shadingAux = orbit trap, MAT_FOCAL).
// ============================================================

vec3 layerFocal(vec3 p) {
  vec3 q = p - FOCAL_POS;
  float bound = length(q) - 2.6;
  if (bound > 1.2) {
    return vec3(bound, 0.0, MAT_FOCAL);
  }
  vec3 mq = q / 1.6;
  ry(mq, uTime * 0.12);
  vec2 mb = mbDE(mq);
  return vec3(mb.x * 1.6, mb.y, MAT_FOCAL);
}
