// ============================================================
// scene_mandelbulb.fs.glsl
// Isolated Mandelbulb render styled after iquilezles' city demo:
// warm directional sun + cool sky dome, exp extinction fog along
// the primary ray, and stratified volumetric god-rays.
// NOT a path tracer — single-bounce approximation that runs
// realtime and tracks OrbitControls. All ecosystem layers are
// intentionally bypassed so we can see the bulb in isolation.
// Must be concatenated after common.glsl and mandelbulb.glsl.
// ============================================================

// ---------- scene: domain-repeated + warped Mandelbulb field ----------
// Two ideas borrowed from city:
//   (1) `mod()` domain repetition — one bulb per tile.
//   (2) domain warp — sinusoidal offset applied to the query point
//       before the fractal is evaluated, so the bulb silhouettes are
//       organically deformed instead of perfectly symmetric.
// Each tile also gets a deterministic rotation / Y offset / scale
// via hash11(cell). Scale is capped below 1.0 so a bulb never bleeds
// into the next tile (that would break the single-tile fold).
#define TILE_PERIOD 3.0

// Two-octave warp — g(p) in `f(p + g(p))`. Different swizzles per
// octave so the offset mixes axes the way city's recursive warp does.
vec3 domainWarp(vec3 p, float seed) {
  vec3 w  = 0.22 * sin(p.yzx * 1.60 + vec3(0.0, 2.1, 4.3) + seed * 3.17);
  w      += 0.08 * sin(p.zxy * 3.70 + vec3(1.5, 3.2, 0.9) + seed * 7.31);
  return w;
}

vec3 scene(vec3 p) {
  // (1a) gentle GLOBAL warp before the fold — tile grid becomes wavy
  p += 0.10 * sin(p.zxy * 0.35 + vec3(0.0, 1.3, 2.7));

  vec2 cell = floor((p.xz + TILE_PERIOD * 0.5) / TILE_PERIOD);
  float seed = dot(cell, vec2(7.131, 31.73));

  // (2) fold XZ into a tile centered at the origin
  vec3 q = p;
  q.xz = mod(p.xz + TILE_PERIOD * 0.5, TILE_PERIOD) - TILE_PERIOD * 0.5;

  // per-tile vertical offset so the field isn't a flat row
  float yOff = (hash11(seed + 2.31) - 0.5) * 0.8;
  q.y -= yOff;

  // per-tile rotation around Y so each bulb faces a different way
  float rot = hash11(seed + 1.17) * 6.2832;
  float cr = cos(rot), sr = sin(rot);
  q.xz = mat2(cr, -sr, sr, cr) * q.xz;

  // per-tile scale in [0.55, 0.95] — keeps radius < tile-half (1.5)
  float scl = 0.55 + hash11(seed + 3.71) * 0.40;

  // (1b) PER-TILE warp applied in the bulb's local (scaled) frame
  vec3 sq = q / scl;
  sq += domainWarp(sq, seed);

  vec2 mb = mbDE(sq);
  // Scale restores world-space distance; the 0.75 safety factor
  // compensates for the Lipschitz stretch introduced by the warp so
  // the raymarch doesn't overstep through bent surface sheets.
  return vec3(mb.x * scl * 0.75, mb.y, 0.0);
}

float map(vec3 p) {
  return scene(p).x;
}

// ---------- normal ----------
vec3 nor(vec3 p) {
  vec2 e = vec2(0.0015, 0.0);
  return normalize(vec3(
    map(p + e.xyy) - map(p - e.xyy),
    map(p + e.yxy) - map(p - e.yxy),
    map(p + e.yyx) - map(p - e.yyx)
  ));
}

// ---------- surface shadow ----------
float softshadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  float t = mint;
  for (int i = 0; i < MAX_SHADOW_STEPS; i++) {
    float h = map(ro + rd * t);
    res = min(res, k * h / t);
    t += clamp(h, 0.02, 0.25);
    if (res < 0.002 || t > maxt) break;
  }
  return clamp(res, 0.0, 1.0);
}

// ---------- cheap binary shadow for volumetric sampling ----------
// Reach ~8 units (≈ 2.5 tiles at TILE_PERIOD=3.0) so god-rays can
// be occluded by neighboring bulbs, not just the one in the current tile.
float shadowVol(vec3 ro, vec3 rd) {
  float t = 0.02;
  for (int i = 0; i < 22; i++) {
    float h = map(ro + rd * t);
    if (h < 0.002) return 0.0;
    t += clamp(h, 0.04, 0.5);
    if (t > 8.0) break;
  }
  return 1.0;
}

// ---------- primary raymarch ----------
vec4 intersect(vec3 ro, vec3 rd) {
  float t = 0.02;
  float trap = 0.0;
  for (int i = 0; i < MAX_MARCH_STEPS; i++) {
    vec3 sc = scene(ro + rd * t);
    trap = sc.y;
    if (sc.x < SURF_EPS * (1.0 + 0.06 * t)) {
      return vec4(t, trap, 0.0, 1.0);
    }
    t += sc.x * STEP_SAFETY;
    if (t > MAX_DIST) break;
  }
  return vec4(t, trap, 0.0, 0.0);
}

// ---------- lighting (city palette, scaled down for ACES) ----------
const vec3 SUN_DIR = normalize(vec3(0.2, 1.0, -0.5));
const vec3 SUN_COL = vec3(1.2, 0.9, 0.7) * 2.8;
const vec3 SKY_COL = vec3(0.3, 0.5, 0.7) * 0.95;

vec3 renderBackground(vec3 rd) {
  return mix(0.05 * vec3(0.9, 1.0, 1.0), SKY_COL, smoothstep(0.1, 0.25, rd.y));
}

vec3 tonemapACES(vec3 x) {
  return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
  vec2 fragCoord = gl_FragCoord.xy;
  vec2 uv = (fragCoord - 0.5 * uResolution) / uResolution.y;

  vec3 ro = uCamPos;
  vec3 ta = uCamTarget;

  vec3 ww = normalize(ta - ro);
  vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
  vec3 vv = normalize(cross(uu, ww));
  vec3 rd = normalize(uu * uv.x + vv * uv.y + ww * 1.7);

  vec3 bg = renderBackground(rd);
  vec4 hit = intersect(ro, rd);
  vec3 col;
  float fdis;

  if (hit.w > 0.5) {
    vec3 pos = ro + rd * hit.x;
    vec3 n = nor(pos);
    float trap = hit.y;

    // fractal-driven surface tint (orbit trap -> cool/warm blend)
    vec3 baseA = vec3(0.18, 0.16, 0.24);
    vec3 baseB = vec3(0.95, 0.55, 0.30);
    vec3 surface = mix(baseA, baseB, exp(-3.6 * trap));

    float diff = max(0.0, dot(n, SUN_DIR));
    float sha  = (diff > 0.001) ? softshadow(pos + n * 0.01, SUN_DIR, 0.02, 10.0, 12.0) : 0.0;
    float hemi = clamp(0.5 + 0.5 * n.y, 0.0, 1.0);
    vec3 halfDir = normalize(SUN_DIR - rd);
    float spec = pow(max(dot(n, halfDir), 0.0), 48.0);

    vec3 direct  = SUN_COL * diff * sha;
    vec3 ambient = SKY_COL * hemi * 0.6;

    col  = surface * (direct + ambient);
    col += SUN_COL * spec * sha * 0.15;

    fdis = hit.x;
    col *= exp(-0.22 * fdis); // exponential extinction along primary ray
  } else {
    col = bg;
    fdis = MAX_DIST * 0.4; // cap volumetric reach on misses
  }

  // ---- volumetric god-rays: 5 stratified samples along primary ray ----
  float jitter = fract(sin(dot(fragCoord, vec2(12.9898, 78.233))) * 43758.5453);
  float acc = 0.0;
  for (int i = 0; i < 5; i++) {
    float u = (float(i) + jitter) / 5.0;
    vec3 pv = ro + rd * (fdis * u);
    acc += 0.2 * shadowVol(pv, SUN_DIR);
  }
  col += vec3(0.12) * pow(acc, 2.0) * SUN_COL * 0.45;

  // vignette + tonemap + gamma
  vec2 frameUv = (vUv * 2.0 - 1.0) * vec2(uResolution.x / max(uResolution.y, 1.0), 1.0);
  float vignette = 1.0 - smoothstep(0.85, 1.7, length(frameUv));
  col *= vignette;
  col = tonemapACES(col);
  col = pow(col, vec3(1.0 / 2.2));

  gl_FragColor = vec4(col, 1.0);
}
