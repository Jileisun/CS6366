// ============================================================
// scene.fs.glsl
// The top-level fragment shader for the ecosystem corridor.
// Responsibilities:
//   - compose layer SDFs into mapScene
//   - raymarch, estimate normals, AO, soft shadow
//   - material-branched shading, fog, vignette, tonemap
// Layer/primitive modules (common, mandelbulb, layer_*) MUST be
// concatenated before this file by app.js.
// ============================================================

// ---------- scene composition ----------
vec3 unionScene(vec3 a, vec3 b) {
  return (a.x < b.x) ? a : b;
}

vec3 mapScene(vec3 p) {
  vec3 res = vec3(1e9, 0.0, 0.0);
  res = unionScene(res, layerGround(p));
  res = unionScene(res, layerTrunks(p));
  res = unionScene(res, layerCanopy(p));
  res = unionScene(res, layerClusters(p));
  res = unionScene(res, layerFocal(p));
  return res;
}

float map(vec3 p) {
  return mapScene(p).x;
}

// ---------- render utilities ----------
vec3 nor(vec3 p) {
  vec2 e = vec2(0.0018, 0.0);
  return normalize(vec3(
    map(p + e.xyy) - map(p - e.xyy),
    map(p + e.yxy) - map(p - e.yxy),
    map(p + e.yyx) - map(p - e.yyx)
  ));
}

float calcAO(vec3 p, vec3 n) {
  float occ = 0.0;
  float w = 1.0;
  for (int i = 0; i < 4; i++) {
    float h = 0.05 + 0.14 * float(i);
    float d = map(p + n * h);
    occ += (h - d) * w;
    w *= 0.7;
  }
  return clamp(1.0 - 1.4 * occ, 0.0, 1.0);
}

float softshadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  float t = mint;
  for (int i = 0; i < MAX_SHADOW_STEPS; i++) {
    float h = map(ro + rd * t);
    res = min(res, k * h / t);
    t += clamp(h, 0.03, 0.3);
    if (res < 0.002 || t > maxt) break;
  }
  return clamp(res, 0.0, 1.0);
}

// returns (t, shadingAux, matId, hitFlag)
vec4 intersect(vec3 ro, vec3 rd) {
  float t = 0.02;
  for (int i = 0; i < MAX_MARCH_STEPS; i++) {
    vec3 sc = mapScene(ro + rd * t);
    if (sc.x < SURF_EPS * (1.0 + 0.06 * t)) {
      return vec4(t, sc.y, sc.z, 1.0);
    }
    t += sc.x * STEP_SAFETY;
    if (t > MAX_DIST) break;
  }
  return vec4(t, 0.0, 0.0, 0.0);
}

vec3 background(vec3 rd) {
  float horizon = smoothstep(-0.25, 0.35, rd.y);
  vec3 skyA = vec3(0.015, 0.012, 0.022);
  vec3 skyB = vec3(0.09, 0.10, 0.15);
  vec3 col = mix(skyA, skyB, horizon);

  vec3 focalDir = normalize(FOCAL_POS - uCamPos);
  float haze = pow(max(dot(rd, focalDir), 0.0), 12.0);
  col += vec3(0.35, 0.12, 0.22) * haze * 0.35;
  return col;
}

vec3 tonemapACES(vec3 x) {
  return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

// ---------- main ----------
void main() {
  vec2 fragCoord = gl_FragCoord.xy;
  vec2 uv = (fragCoord - 0.5 * uResolution) / uResolution.y;

  // Camera is driven by JS-side OrbitControls; shader just consumes it.
  vec3 ro = uCamPos;
  vec3 ta = uCamTarget;

  vec3 ww = normalize(ta - ro);
  vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
  vec3 vv = normalize(cross(uu, ww));
  // 1.7 ≈ 1/tan(half_fov) for ~60° vertical FOV
  vec3 rd = normalize(uu * uv.x + vv * uv.y + ww * 1.7);

  vec3 bg = background(rd);
  vec4 hit = intersect(ro, rd);
  vec3 color = bg;

  if (hit.w > 0.5) {
    vec3 pos = ro + rd * hit.x;
    vec3 n = nor(pos);
    float mat = hit.z;
    float aux = hit.y;

    vec3 sunDir = normalize(vec3(-0.35, 0.75, -0.55));
    vec3 keyCol = vec3(1.05, 0.75, 0.6);
    vec3 skyCol = vec3(0.25, 0.35, 0.55);
    vec3 halfDir = normalize(sunDir - rd);

    float diff = max(dot(n, sunDir), 0.0);
    float spec = pow(max(dot(n, halfDir), 0.0), 40.0);
    float sha  = softshadow(pos + n * 0.015, sunDir, 0.04, 10.0, 10.0);
    float ao   = calcAO(pos, n);
    float fres = pow(clamp(1.0 + dot(n, rd), 0.0, 1.0), 3.0);
    float sky  = clamp(0.5 + 0.5 * n.y, 0.0, 1.0);

    vec3 baseColor = vec3(0.5);
    vec3 emissive  = vec3(0.0);
    float specStrength = 0.3;

    if (mat < 0.5) {
      // ground
      vec3 cA = vec3(0.04, 0.035, 0.055);
      vec3 cB = vec3(0.09, 0.06, 0.09);
      float n2 = 0.5 + 0.5 * sin(pos.x * 2.9) * cos(pos.z * 2.3);
      baseColor = mix(cA, cB, n2) * 0.9;
      specStrength = 0.1;
    } else if (mat < 1.5) {
      // trunk
      vec3 bone = vec3(0.78, 0.72, 0.64);
      vec3 dark = vec3(0.22, 0.19, 0.21);
      float stripe = 0.5 + 0.5 * sin(pos.y * 5.5 + aux * 7.0);
      baseColor = mix(dark, bone, stripe);
      float vein = smoothstep(0.25, 0.85, 1.0 - ao) * (0.4 + 0.8 * aux);
      emissive = vec3(1.0, 0.22, 0.32) * vein * 0.9;
      specStrength = 0.45;
    } else if (mat < 2.5) {
      // canopy
      baseColor = vec3(0.52, 0.5, 0.55);
      specStrength = 0.25;
    } else if (mat < 3.5) {
      // cluster
      baseColor = mix(vec3(0.09, 0.05, 0.07), vec3(0.35, 0.18, 0.22), aux);
      if (aux > 0.72) emissive = vec3(1.0, 0.35, 0.55) * (aux - 0.7) * 2.5;
      specStrength = 0.2;
    } else {
      // focal
      vec3 inner = vec3(1.0, 0.35, 0.55);
      vec3 outer = vec3(0.35, 0.05, 0.25);
      float t = exp(-3.2 * aux);
      baseColor = mix(outer, inner, t) * 0.35;
      emissive  = mix(outer, inner, t) * (1.6 + 2.6 * t);
      specStrength = 0.6;
    }

    vec3 lit = baseColor * (0.15 + 1.05 * diff * sha) * ao;
    lit += baseColor * skyCol * sky * 0.22 * ao;
    lit += keyCol * spec * sha * specStrength;
    lit += vec3(0.35, 0.5, 0.75) * fres * 0.18;
    lit += emissive;

    color = lit;

    float fog = 1.0 - exp(-0.06 * hit.x);
    vec3 fogCol = mix(bg, vec3(0.12, 0.04, 0.08), 0.45);
    color = mix(color, fogCol, fog);
  } else {
    vec3 glowDir = normalize(FOCAL_POS - ro);
    float glow = pow(max(dot(rd, glowDir), 0.0), 48.0);
    color += vec3(1.0, 0.3, 0.5) * glow * 0.6;
  }

  vec2 frameUv = (vUv * 2.0 - 1.0) * vec2(uResolution.x / max(uResolution.y, 1.0), 1.0);
  float vignette = 1.0 - smoothstep(0.85, 1.7, length(frameUv));
  color *= vignette;
  color = tonemapACES(color);
  color = pow(color, vec3(1.0 / 2.2));

  gl_FragColor = vec4(color, 1.0);
}
