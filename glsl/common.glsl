// ============================================================
// common.glsl
// Shader header + constants + hashes + rotations + SDF primitives.
// Must be concatenated first so every downstream module can see
// the uniforms, varying, #defines, and helper functions.
// ============================================================

precision highp float;

uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCamPos;     // driven by OrbitControls in JS
uniform vec3 uCamTarget;  // controls.target — usually the focal

varying vec2 vUv;

// ---------- march + fractal constants ----------
#define MAX_MARCH_STEPS 140
#define MAX_SHADOW_STEPS 36
#define MAX_DIST 32.0
#define SURF_EPS 0.0018
#define STEP_SAFETY 0.85
#define POWER 8.0
#define BAILOUT 6.0

// ---------- material ids ----------
#define MAT_GROUND  0.0
#define MAT_TRUNK   1.0
#define MAT_CANOPY  2.0
#define MAT_CLUSTER 3.0
#define MAT_FOCAL   4.0

// ---------- corridor layout ----------
#define CORRIDOR_SIDE 2.55
#define TRUNK_SPACING 2.65
#define TRUNK_Z_START -3.0
#define TRUNK_Z_END   20.0
#define FOCAL_POS vec3(0.0, 1.7, 22.5)
#define GROUND_Y -1.0

// ---------- deterministic per-cell variation ----------
float hash11(float n) {
  return fract(sin(n * 127.1) * 43758.5453);
}

// ---------- rotation ----------
void ry(inout vec3 p, float a) {
  float c = cos(a), s = sin(a);
  p = vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

// ---------- SDF primitives ----------
float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
  vec3 pa = p - a;
  vec3 ba = b - a;
  float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

// smooth union (quadratic polynomial)
float opSmin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}
