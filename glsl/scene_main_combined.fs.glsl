precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform vec4 iMouse;

uniform float uViewAz;
uniform float uViewEl;
uniform float uViewZoom;

uniform float uTerrHeight;
uniform float uTerrLacunarity;
uniform float uTerrPersistence;
uniform float uTerrShape;
uniform float uTerrFlightSpeed;
uniform float uTerrGroundMode;
uniform float uTerrQualityMode;
uniform float uTerrSunMode;

uniform float uApolloTreeScale;
uniform float uApolloTreeLift;
uniform float uApolloTreeGap;
uniform float uApolloTreeGain;
uniform float uApolloTreeDrift;

varying vec2 vUv;

const float PI = 3.14159;
const float TAU = 6.28318530718;

vec3 sunDir;
float tCur;
float dstFar;
float hFac;
float fWav;
float aWav;
float smFac;
float stepFac;
int grType;
int qType;
int shType;
int stepLim;

const mat2 qRot = mat2(0.8, -0.6, 0.6, 0.8);
const vec4 cHashA4 = vec4(0.0, 1.0, 57.0, 58.0);
const vec3 cHashA3 = vec3(1.0, 57.0, 113.0);
const float cHashM = 43758.54;

mat2 ROT(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, s, -s, c);
}

vec4 Hashv4f(float p) {
  return fract(sin(p + cHashA4) * cHashM);
}

float Noisefv2(vec2 p) {
  vec2 ip = floor(p);
  vec2 fp = fract(p);
  fp = fp * fp * (3.0 - 2.0 * fp);
  vec4 t = Hashv4f(dot(ip, cHashA3.xy));
  return mix(mix(t.x, t.y, fp.x), mix(t.z, t.w, fp.x), fp.y);
}

float Fbm2(vec2 p) {
  float f = 0.0;
  float a = 1.0;
  for (int i = 0; i <= 4; ++i) {
    f += a * Noisefv2(p);
    a *= 0.5;
    p *= 2.0;
  }
  return f;
}

vec3 Noisev3v2(vec2 p) {
  vec2 ip = floor(p);
  vec2 fp = fract(p);
  vec2 u = fp * fp * (3.0 - 2.0 * fp);
  vec4 t = Hashv4f(dot(ip, cHashA3.xy));
  vec4 s = vec4(t.y - t.x, t.w - t.z, t.z - t.x, t.x - t.y + t.w - t.z);
  return vec3(
    t.x + s.x * u.x + s.z * u.y + s.w * u.x * u.y,
    30.0 * fp * fp * (fp * fp - 2.0 * fp + 1.0) * (s.xz + s.w * u.yx)
  );
}

float Fbmn(vec3 p, vec3 n) {
  vec3 s = vec3(0.0);
  float a = 1.0;
  for (int i = 0; i <= 4; ++i) {
    s += a * vec3(Noisefv2(p.yz), Noisefv2(p.zx), Noisefv2(p.xy));
    a *= 0.5;
    p *= 2.0;
  }
  return dot(s, abs(n));
}

vec3 VaryNf(vec3 p, vec3 n, float f) {
  vec3 e = vec3(0.1, 0.0, 0.0);
  float s = Fbmn(p, n);
  vec3 g = vec3(
    Fbmn(p + e.xyy, n) - s,
    Fbmn(p + e.yxy, n) - s,
    Fbmn(p + e.yyx, n) - s
  );
  return normalize(n + f * (g - n * dot(n, g)));
}

mat3 AxToRMat(vec3 vz, vec3 vy) {
  vec3 vx = normalize(cross(vy, vz));
  vy = cross(vz, vx);
  return mat3(
    vec3(vx.x, vy.x, vz.x),
    vec3(vx.y, vy.y, vz.y),
    vec3(vx.z, vy.z, vz.z)
  );
}

vec3 SkyBg(vec3 rd) {
  return vec3(0.16, 0.22, 0.42) + 0.3 * pow(1.0 - max(rd.y, 0.0), 8.0);
}

vec3 sunLightColor() {
  return vec3(1.72, 0.44, 0.12);
}

float cloudFieldRaw(vec2 cloudUv) {
  float broad = Fbm2(cloudUv);
  float wisps = 0.65 * Fbm2(cloudUv * 1.9 + vec2(5.3, -2.1))
    + 0.35 * Noisefv2(cloudUv * 3.4 + vec2(1.7, 8.3));
  return smoothstep(0.64, 0.82, mix(broad, wisps, 0.45));
}

vec2 sunMandelbulbInfo(vec3 p) {
  vec3 z = p.xzy;
  float dr = 1.0;
  float trap = 1.0;
  float r = 0.0;
  const float power = 8.0;

  for (int i = 0; i < 5; ++i) {
    r = length(z);
    if (r > 2.0) break;

    float safeR = max(r, 1.0e-5);
    float theta = atan(z.y, z.x);
    float phi = asin(clamp(z.z / safeR, -1.0, 1.0));
    phi += 0.05 * sin(0.45 * tCur + 4.0 * safeR);

    dr = pow(safeR, power - 1.0) * dr * power + 1.0;

    float zr = pow(safeR, power);
    theta *= power;
    phi *= power;

    z = zr * vec3(
      cos(theta) * cos(phi),
      sin(theta) * cos(phi),
      sin(phi)
    ) + p;

    trap = min(trap, zr);
  }

  float safeR = max(r, 1.0e-5);
  return vec2(0.5 * log(safeR) * safeR / dr, trap);
}

vec3 sunMandelbulbNormal(vec3 p) {
  vec3 eps = vec3(0.012, 0.0, 0.0);
  return normalize(vec3(
    sunMandelbulbInfo(p + eps.xyy).x - sunMandelbulbInfo(p - eps.xyy).x,
    sunMandelbulbInfo(p + eps.yxy).x - sunMandelbulbInfo(p - eps.yxy).x,
    sunMandelbulbInfo(p + eps.yyx).x - sunMandelbulbInfo(p - eps.yyx).x
  ));
}

float sunFractalLightFactor() {
  vec3 ro = vec3(0.0, 0.0, -1.55);
  vec3 rd = normalize(vec3(0.08 * sin(0.21 * tCur), 0.04 * cos(0.17 * tCur), 1.0));
  float t = 0.0;
  float occ = 0.0;
  for (int i = 0; i < 18; ++i) {
    vec3 p = ro + rd * t;
    vec2 info = sunMandelbulbInfo(p);
    occ += exp(-16.0 * abs(info.x)) * 0.085;
    t += 0.18;
  }
  return clamp(1.10 - 0.55 * occ, 0.62, 1.08);
}

float cloudShadowFactor(vec3 pos) {
  float denom = max(sunDir.y, 0.16);
  float cloudT = (50.0 - pos.y) / denom;
  vec3 q = pos + sunDir * cloudT;
  vec2 cloudUv = 0.1 * (q.xz + vec2(0.5 * tCur));
  float cloud = cloudFieldRaw(cloudUv);
  return mix(1.0, 0.64, cloud);
}

vec3 SkySunMandelbulb(vec3 ro, vec3 rd) {
  float sunDot = max(dot(rd, sunDir), 0.0);
  vec3 halo = vec3(0.86, 0.10, 0.05) * pow(sunDot, 40.0);
  halo += vec3(1.70, 0.38, 0.08) * pow(sunDot, 118.0);

  vec3 center = ro + sunDir * 145.0;
  float radius = 14.0;
  vec3 oc = ro - center;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - radius * radius;
  float h = b * b - c;
  if (h < 0.0) return halo;

  h = sqrt(h);
  float t = max(-b - h, 0.0);
  float tFar = -b + h;
  float trap = 1.0;
  bool hit = false;

  for (int i = 0; i < 40; ++i) {
    if (t > tFar) break;
    vec3 p = (ro + rd * t - center) / radius;
    vec2 info = sunMandelbulbInfo(p);
    float d = info.x * radius;
    if (d < max(0.02, 0.0012 * t)) {
      trap = info.y;
      hit = true;
      break;
    }
    t += clamp(d, 0.08, 1.10);
  }

  if (!hit) {
    return halo + vec3(0.95, 0.08, 0.03) * pow(sunDot, 72.0) * 0.28;
  }

  vec3 localPos = (ro + rd * t - center) / radius;
  vec3 nor = sunMandelbulbNormal(localPos);
  float dif = max(dot(nor, normalize(vec3(-0.45, 0.76, 0.44))), 0.0);
  float rim = pow(clamp(1.0 + dot(rd, nor), 0.0, 1.0), 2.8);

  vec3 core = mix(vec3(0.20, 0.01, 0.01), vec3(0.68, 0.04, 0.02), smoothstep(0.02, 0.34, trap));
  core = mix(core, vec3(1.05, 0.12, 0.03), smoothstep(0.20, 0.60, trap));
  core = mix(core, vec3(1.72, 0.54, 0.10), smoothstep(0.52, 0.92, trap));
  core += vec3(2.00, 1.04, 0.70) * pow(max(1.0 - trap, 0.0), 4.5) * 0.24;

  vec3 lin = vec3(0.16, 0.02, 0.01);
  lin += vec3(1.30, 0.16, 0.04) * dif;
  lin += vec3(1.55, 0.70, 0.22) * rim;

  return halo + core * lin * 1.45;
}

vec3 SkyCol(vec3 ro, vec3 rd) {
  ro.xz += 0.5 * tCur;
  float skyT = (50.0 - ro.y) / max(rd.y, 0.05);
  vec2 cloudUv = 0.1 * (ro + rd * skyT).xz;
  float cloudMask = cloudFieldRaw(cloudUv);
  cloudMask *= smoothstep(0.05, 0.40, rd.y);
  cloudMask *= 1.0 - 0.88 * smoothstep(0.90, 0.995, max(dot(rd, sunDir), 0.0));
  vec3 sky = mix(
    SkyBg(rd),
    vec3(0.83, 0.84, 0.87),
    clamp(cloudMask, 0.0, 1.0)
  );
  sky += vec3(0.10, 0.05, 0.08) * cloudMask * pow(max(dot(rd, sunDir), 0.0), 1.7);
  return sky + SkySunMandelbulb(ro, rd);
}

vec3 TrackPath(float t) {
  return vec3(
    20.0 * sin(0.07 * t) * sin(0.022 * t) * cos(0.018 * t) + 13.0 * sin(0.0061 * t),
    0.0,
    t
  );
}

float GrndHt1(vec2 p) {
  vec2 q = 0.1 * p;
  float f = 0.0;
  float wAmp = 1.0;
  for (int j = 0; j <= 4; ++j) {
    f += wAmp * Noisefv2(q);
    wAmp *= aWav;
    q *= fWav * qRot;
  }
  return min(5.0 * Noisefv2(0.033 * smFac * p) + 0.5, 4.0) * f;
}

float GrndHt2(vec2 p) {
  vec2 q = 0.1 * p;
  vec2 t = vec2(0.0);
  float wAmp = 1.0;
  float f = 0.0;
  for (int j = 0; j <= 3; ++j) {
    vec3 v = Noisev3v2(q);
    t += v.yz;
    f += wAmp * v.x / (1.0 + dot(t, t));
    wAmp *= aWav;
    q *= fWav * qRot;
  }
  return min(5.0 * Noisefv2(0.033 * smFac * p) + 0.5, 4.0) * f;
}

float GrndHt3(vec2 p) {
  vec2 q = 0.1 * p;
  float wAmp = 0.3;
  float pRough = 1.0;
  float f = 0.0;
  for (int j = 0; j <= 2; ++j) {
    vec2 t = q + 2.0 * Noisefv2(q) - 1.0;
    vec2 ta = abs(sin(t));
    vec2 v = (1.0 - ta) * (ta + abs(cos(t)));
    v = pow(1.0 - v, vec2(pRough));
    f += (v.x + v.y) * wAmp;
    q *= fWav * qRot;
    wAmp *= aWav;
    pRough = smFac * pRough + 0.2;
  }
  return min(5.0 * Noisefv2(0.033 * p) + 0.5, 4.0) * f;
}

float GrndHt4(vec2 p) {
  vec2 q = 0.1 * p;
  vec2 t = vec2(0.0);
  float wAmp = 1.0;
  float f = 0.0;
  float sp = 0.0;
  for (int j = 0; j <= 3; ++j) {
    vec3 v = Noisev3v2(q);
    t += pow(abs(v.yz), vec2(5.0 - 0.5 * sp)) - smoothstep(0.0, 1.0, v.yz);
    f += wAmp * v.x / (1.0 + dot(t, t));
    wAmp *= -aWav * pow(smFac, sp);
    q *= fWav * qRot;
    sp += 1.0;
  }
  float b = 0.5 * (0.5 + clamp(f, -0.5, 1.5));
  return 3.0 * f / (b * b * (3.0 - 2.0 * b) + 0.5) + 1.0;
}

float GrndHt(vec2 p) {
  float ht = GrndHt1(p);
  if (grType == 2) ht = GrndHt2(p);
  else if (grType == 3) ht = GrndHt3(p);
  else if (grType == 4) ht = GrndHt4(p);
  return hFac * ht;
}

float GrndRay(vec3 ro, vec3 rd) {
  float s = 0.0;
  float sLo = 0.0;
  float dHit = dstFar;
  float h = 0.0;
  for (int j = 0; j <= 300; ++j) {
    vec3 p = ro + s * rd;
    h = p.y - GrndHt(p.xz);
    if (h < 0.0) break;
    sLo = s;
    s += stepFac * (max(0.4, 0.6 * h) + 0.008 * s);
    if (s > dstFar || j == stepLim) break;
  }

  if (h < 0.0) {
    float sHi = s;
    for (int j = 0; j <= 4; ++j) {
      s = 0.5 * (sLo + sHi);
      vec3 p = ro + s * rd;
      float side = step(0.0, p.y - GrndHt(p.xz));
      sLo += side * (s - sLo);
      sHi += (1.0 - side) * (s - sHi);
    }
    dHit = sHi;
  }

  return dHit;
}

vec3 GrndNf(vec3 p) {
  vec2 e = vec2(0.01, 0.0);
  float ht = GrndHt(p.xz);
  return normalize(vec3(
    ht - GrndHt(p.xz + e.xy),
    e.x,
    ht - GrndHt(p.xz + e.yx)
  ));
}

float GrndSShadow(vec3 p, vec3 vs) {
  float sh = 1.0;
  float d = 0.4;
  for (int j = 0; j <= 25; ++j) {
    vec3 q = p + vs * d;
    sh = min(sh, smoothstep(0.0, 0.02 * d, q.y - GrndHt(q.xz)));
    d += max(0.4, 0.1 * d);
    if (sh < 0.05) break;
  }
  return 0.5 + 0.5 * sh;
}

float box(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

bool raySphere(vec3 ro, vec3 rd, vec3 center, float radius, out float tNear, out float tFar) {
  vec3 oc = ro - center;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - radius * radius;
  float h = b * b - c;
  if (h < 0.0) {
    tNear = 1.0e9;
    tFar = -1.0e9;
    return false;
  }

  h = sqrt(h);
  tNear = -b - h;
  tFar = -b + h;
  return tFar > 0.0;
}

float mod1(inout float p, float size) {
  float halfsize = size * 0.5;
  float c = floor((p + halfsize) / size);
  p = mod(p + halfsize, size) - halfsize;
  return c;
}

vec2 modMirror2(inout vec2 p, vec2 size) {
  vec2 halfsize = size * 0.5;
  vec2 c = floor((p + halfsize) / size);
  p = mod(p + halfsize, size) - halfsize;
  p *= mod(c, vec2(2.0)) * 2.0 - vec2(1.0);
  return c;
}

vec3 shadeTerrain(vec3 ro, vec3 rd, float dstGrnd, vec3 bg) {
  vec3 hit = ro + dstGrnd * rd;
  vec3 vn = GrndNf(hit);
  float f = 0.2 + 0.8 * smoothstep(0.7, 1.1, Fbm2(1.7 * hit.xz));
  float slope = 1.0 - clamp(abs(vn.y), 0.0, 1.0);
  float meadow = smoothstep(0.18, 0.92, vn.y);
  float canopy = smoothstep(0.24, 0.88, f);
  float lowlands = 1.0 - smoothstep(3.8, 8.8, hit.y);
  float ridge = smoothstep(5.8, 9.2, hit.y);

  vec3 soil = mix(vec3(0.16, 0.11, 0.07), vec3(0.22, 0.16, 0.09), canopy);
  vec3 moss = mix(vec3(0.09, 0.23, 0.08), vec3(0.13, 0.34, 0.10), canopy);
  vec3 leaf = mix(vec3(0.24, 0.44, 0.14), vec3(0.44, 0.66, 0.18), canopy);
  vec3 ridgeGreen = vec3(0.56, 0.64, 0.40);
  vec3 sunGrass = vec3(0.76, 0.84, 0.48);

  vec3 col = mix(soil, moss, 0.45 + 0.30 * lowlands);
  col = mix(col, leaf, meadow * (0.50 + 0.35 * lowlands));
  col = mix(col, vec3(0.26, 0.22, 0.12), smoothstep(0.30, 0.82, slope));
  col = mix(col, ridgeGreen, ridge * (0.20 + 0.50 * meadow));
  col = mix(col, sunGrass, ridge * meadow * smoothstep(0.0, 0.40, 1.0 - slope));
  float spec = mix(0.08, 0.26, smoothstep(5.5, 9.0, hit.y));
  vn = VaryNf(2.0 * hit, vn, 1.5);
  float ndl = max(0.0, dot(vn, sunDir));
  float sunShadow = (shType > 1) ? GrndSShadow(hit, sunDir) : 1.0;
  float sunFactor = sunFractalLightFactor() * cloudShadowFactor(hit);
  vec3 sunCol = sunLightColor() * sunFactor;
  vec3 light = vec3(0.28, 0.30, 0.24) + 0.14 * vn.y * vec3(1.0, 1.0, 0.95);
  light += 0.92 * sunShadow * ndl * sunCol;
  light += 0.62 * spec * sunShadow * pow(max(0.0, dot(sunDir, reflect(rd, vn))), 16.0) * mix(vec3(1.0), sunCol, 0.75);
  col *= light;
  float fog = dstGrnd / dstFar;
  fog *= fog;
  col = mix(col, bg, clamp(fog * fog, 0.0, 1.0));
  return pow(clamp(col, 0.0, 1.0), vec3(0.8));
}

float apolloInstanceSize(vec3 center) {
  float coarse = Noisefv2(center.xz * 0.033 + vec2(6.1, 2.3));
  float fine = Noisefv2(center.zx * 0.079 + vec2(1.7, 8.2));
  return mix(0.56, 2.08, 0.72 * coarse + 0.28 * fine);
}

vec3 apolloInstanceCenter(float cellZ, float side) {
  float seedA = Noisefv2(vec2(cellZ * 0.13, side * 2.1));
  float seedB = Noisefv2(vec2(cellZ * 0.29 + side * 1.7, 8.4));
  float seedC = Noisefv2(vec2(cellZ * 0.41 - side * 0.9, 3.6));

  float laneScale = mix(0.62, 1.46, seedA);
  float laneJitter = (seedB - 0.5) * 9.5 + 3.4 * sin(cellZ * 0.91 + side * 1.8);
  float x = side * (uApolloTreeGap * laneScale + 4.2) + laneJitter;

  float z = cellZ * 18.0;
  z += (seedC - 0.5) * 15.0;
  z += 6.8 * sin(cellZ * 0.73 + 6.2831 * seedA);
  z += 3.1 * sin(cellZ * 1.37 + side * 2.3);

  float sizeFactor = apolloInstanceSize(vec3(x, 0.0, z));
  float liftJitter = mix(-0.35, 1.15, Noisefv2(vec2(cellZ * 0.17 + side * 5.1, 6.2)));
  float groundY = GrndHt(vec2(x, z));
  float anchorLift = 0.55 + 0.95 * sizeFactor + 0.32 * liftJitter + 0.14 * uApolloTreeLift;
  float y = groundY + anchorLift;
  return vec3(x, y, z);
}

float apolloInstanceRadius(vec3 center) {
  float sizeFactor = apolloInstanceSize(center);
  float coarse = Noisefv2(center.xz * 0.029 + vec2(3.1, 7.9));
  float fine = Noisefv2(center.zx * 0.061 + vec2(5.6, 1.4));
  float baseRadius = mix(3.9, 7.8, 0.64 * coarse + 0.36 * fine);
  return baseRadius * mix(0.78, 1.26, clamp(sizeFactor * 0.52, 0.0, 1.0));
}

bool apolloInstanceEnabled(float cellZ, float side) {
  float presence = Noisefv2(vec2(cellZ * 0.23 + side * 4.7, 2.6));
  float breakup = Noisefv2(vec2(cellZ * 0.41 - side * 3.3, 9.8));
  return presence > mix(0.24, 0.44, breakup);
}

float apolloMainInset(vec3 center) {
  return clamp(
    0.036
      + 0.020 * sin(0.29 * tCur + 0.07 * center.z)
      + 0.010 * sin(0.61 * tCur + 0.05 * center.x + 1.3),
    0.006,
    0.098
  );
}

float apolloMainInversion(vec3 center) {
  return clamp(
    0.42
      + 0.10 * sin(0.23 * tCur + 0.06 * center.z + 0.7)
      + 0.035 * sin(0.57 * tCur + 0.04 * center.x),
    0.18,
    0.58
  );
}

float apolloMainIterations(vec3 center) {
  return clamp(
    floor(5.0 + 3.0 * (0.5 + 0.5 * sin(0.17 * tCur + 0.05 * center.z + 0.3))),
    5.0,
    8.0
  );
}

float apolloMainScalePulse(vec3 center) {
  return clamp(
    1.0
      + 0.06 * sin(0.21 * tCur + 0.09 * center.z)
      + 0.02 * sin(0.49 * tCur + 0.07 * center.x),
    0.90,
    1.10
  );
}

vec3 apolloWorldInfo(vec3 pWorld, vec3 center) {
  vec3 p = pWorld - center;
  p.xz *= ROT(0.12 * sin(0.07 * center.z + 0.9 * uApolloTreeDrift));
  p.z *= 0.82;

  float actorScale = uApolloTreeScale * 1.15 * apolloMainScalePulse(center) / apolloInstanceSize(center);
  float apolloInset = apolloMainInset(center);
  float apolloInversion = apolloMainInversion(center);
  float apolloIterations = apolloMainIterations(center);
  p *= actorScale;
  float scale = 1.0;
  float orb = 10000.0;

  for (int i = 0; i < 8; ++i) {
    if (float(i) >= apolloIterations) break;
    p = -1.0 + 2.0 * fract(0.5 * p + 0.5);
    p -= sign(p) * apolloInset;
    float r2 = max(dot(p, p), 0.04);
    float k = apolloInversion / r2;
    p *= k;
    scale *= k;
    orb = min(orb, r2);
  }

  float d1 = sqrt(min(min(dot(p.xy, p.xy), dot(p.yz, p.yz)), dot(p.zx, p.zx))) - 0.02;
  float d2 = abs(p.y);
  float dmi = d2;
  float band = 0.7 * floor((0.5 * p.y + 0.5) * 8.0);
  if (d1 < d2) {
    dmi = d1;
    band = 0.0;
  }

  return vec3(0.5 * dmi / (scale * actorScale), band, orb);
}

vec3 calcApolloNormal(vec3 pos, vec3 center) {
  vec3 eps = vec3(0.02, 0.0, 0.0);
  return normalize(vec3(
    apolloWorldInfo(pos + eps.xyy, center).x - apolloWorldInfo(pos - eps.xyy, center).x,
    apolloWorldInfo(pos + eps.yxy, center).x - apolloWorldInfo(pos - eps.yxy, center).x,
    apolloWorldInfo(pos + eps.yyx, center).x - apolloWorldInfo(pos - eps.yyx, center).x
  ));
}

float calcApolloAO(vec3 pos, vec3 nor, vec3 center) {
  float ao = 0.0;
  for (int i = 0; i < 6; ++i) {
    float h = 0.03 + 0.12 * float(i) / 5.0;
    ao += clamp(apolloWorldInfo(pos + nor * h, center).x / h, 0.0, 1.0);
  }
  return clamp(ao / 6.0, 0.0, 1.0);
}

vec3 apolloPlantTexture2D(vec2 uv, float band, float upMask) {
  vec2 p = uv * 1.9;
  float barkMask = Fbm2(p * 1.4);
  float leafMask = Fbm2(p * 2.8 + vec2(4.0, 1.7));
  float blossom = Fbm2(p * 7.0 + vec2(2.3, 6.1));
  float ribs = abs(sin(p.x * 2.8 + 2.2 * Fbm2(p * 0.9)) * cos(p.y * 2.0 - 1.8 * Fbm2(p * 1.4)));
  float vein = 1.0 - smoothstep(0.18, 0.72, ribs);
  float crest = 0.5 + 0.5 * cos(6.2831 * band + 2.0 * barkMask);

  vec3 barkDark = vec3(0.24, 0.16, 0.08);
  vec3 barkWarm = vec3(0.42, 0.28, 0.12);
  vec3 leafShade = vec3(0.18, 0.36, 0.12);
  vec3 leafMid = vec3(0.40, 0.66, 0.22);
  vec3 leafSun = vec3(0.72, 0.88, 0.34);

  vec3 base = mix(barkDark, barkWarm, smoothstep(0.12, 0.62, barkMask));
  base = mix(base, leafShade, smoothstep(0.34, 0.78, leafMask) * (0.40 + 0.60 * upMask));
  base = mix(base, leafMid, vein * (0.30 + 0.70 * upMask));
  base = mix(base, leafSun, smoothstep(0.74, 0.96, blossom) * smoothstep(0.32, 1.0, upMask));
  base *= mix(0.92, 1.30, crest);
  return base;
}

vec3 apolloPlantTextureBox(vec3 pos, vec3 nor, float band) {
  vec3 w = abs(nor);
  w = w * w * w;
  w /= (w.x + w.y + w.z + 1.0e-4);

  vec3 txX = apolloPlantTexture2D(pos.yz, band, smoothstep(-0.15, 0.65, nor.x));
  vec3 txY = apolloPlantTexture2D(pos.zx, band + 0.17, smoothstep(-0.15, 0.65, nor.y));
  vec3 txZ = apolloPlantTexture2D(pos.xy, band + 0.31, smoothstep(-0.15, 0.65, nor.z));
  return (w.x * txX + w.y * txY + w.z * txZ) / (w.x + w.y + w.z);
}

bool traceApolloInstance(vec3 ro, vec3 rd, vec3 center, float radius, float tLimit, out float tHit, out vec2 info) {
  float tNear;
  float tFar;
  if (!raySphere(ro, rd, center, radius, tNear, tFar)) return false;
  if (tNear > tLimit) return false;

  float t = max(tNear, 0.05);
  float maxT = min(tFar, tLimit);
  for (int i = 0; i < 144; ++i) {
    if (t > maxT) break;
    vec3 sampleInfo = apolloWorldInfo(ro + rd * t, center);
    float d = sampleInfo.x;
    if (d < max(0.0012, 0.00055 * t)) {
      tHit = t;
      info = sampleInfo.yz;
      return true;
    }
    t += clamp(d, 0.015, 0.66);
  }
  return false;
}

bool traceApolloWorld(vec3 ro, vec3 rd, float tLimit, out float bestT, out vec3 bestCenter, out vec2 bestInfo) {
  bool found = false;
  bestT = 1.0e9;
  float baseCell = floor(ro.z / 18.0);

  vec3 heroLeft = apolloInstanceCenter(floor((ro.z + 16.0) / 18.0), -1.0);
  vec3 heroRight = apolloInstanceCenter(floor((ro.z + 10.0) / 18.0), 1.0);

  float heroTHit;
  vec2 heroInfo;
  if (traceApolloInstance(ro, rd, heroLeft, apolloInstanceRadius(heroLeft), min(tLimit, bestT), heroTHit, heroInfo)) {
    found = true;
    bestT = heroTHit;
    bestCenter = heroLeft;
    bestInfo = heroInfo;
  }
  if (traceApolloInstance(ro, rd, heroRight, apolloInstanceRadius(heroRight), min(tLimit, bestT), heroTHit, heroInfo)) {
    found = true;
    bestT = heroTHit;
    bestCenter = heroRight;
    bestInfo = heroInfo;
  }

  for (int k = -14; k <= 14; ++k) {
    float cellZ = baseCell + float(k);
    for (int sideIdx = 0; sideIdx < 2; ++sideIdx) {
      float side = (sideIdx == 0) ? -1.0 : 1.0;
      if (!apolloInstanceEnabled(cellZ, side)) continue;
      vec3 center = apolloInstanceCenter(cellZ, side);
      float radius = apolloInstanceRadius(center);
      if (distance(center.xz, ro.xz) > 152.0) continue;

      float tHit;
      vec2 info;
      if (traceApolloInstance(ro, rd, center, radius, min(tLimit, bestT), tHit, info)) {
        found = true;
        bestT = tHit;
        bestCenter = center;
        bestInfo = info;
      }
    }
  }

  return found;
}

vec3 shadeApollo(vec3 ro, vec3 rd, float tHit, vec3 center, vec2 info, vec3 bg) {
  vec3 pos = ro + rd * tHit;
  vec3 nor = calcApolloNormal(pos, center);
  float fre = clamp(1.0 + dot(rd, nor), 0.0, 1.0);
  float ao = calcApolloAO(pos, nor, center);
  float terrShadow = GrndSShadow(pos + nor * 0.04, sunDir);
  float sunFactor = sunFractalLightFactor() * cloudShadowFactor(pos);
  vec3 sunCol = sunLightColor() * sunFactor;
  float dif = max(dot(nor, sunDir), 0.0);
  float sky = 0.55 + 0.45 * max(dot(nor, vec3(0.0, 1.0, 0.0)), 0.0);
  float bac = max(0.3 + 0.7 * dot(vec3(-sunDir.x, -1.0, -sunDir.z), nor), 0.0);
  float spe = pow(max(dot(sunDir, reflect(rd, nor)), 0.0), 12.0);

  vec3 base = apolloPlantTextureBox((pos - center) * 0.65, nor, info.x);
  base *= 0.78 + 0.22 * pow(clamp(info.y * 2.0, 0.0, 1.0), 0.6);

  vec3 lin = 2.9 * sunCol * dif * terrShadow;
  lin += 1.18 * vec3(0.24, 0.42, 0.22) * sky * ao;
  lin += 0.72 * vec3(0.38, 0.28, 0.18) * bac * ao;
  lin += 1.55 * mix(vec3(1.0), sunCol, 0.75) * spe * terrShadow;
  lin += 0.28 * pow(1.0 - fre, 24.0) * mix(vec3(0.78, 0.96, 0.54), sunCol, 0.35);

  vec3 col = base * lin * (0.55 + 0.45 * ao) * (0.82 + 0.18 * uApolloTreeGain);
  float farRim = pow(1.0 - fre, 8.0) * smoothstep(24.0, 150.0, tHit);
  col += 0.20 * farRim * mix(base, sunCol, 0.24);
  col = mix(col, bg, 1.0 - exp(-0.00010 * tHit * tHit));
  return pow(clamp(col, 0.0, 1.0), vec3(0.8));
}

vec3 sporeInstanceCenter(float cellZ) {
  float seedA = Noisefv2(vec2(cellZ * 0.12, 5.4));
  float seedB = Noisefv2(vec2(cellZ * 0.17, 1.9));
  float seedC = Noisefv2(vec2(cellZ * 0.27, 7.6));

  float z = cellZ * 22.0;
  z += (seedA - 0.5) * 16.0;
  z += 8.5 * sin(cellZ * 0.81 + 6.2831 * seedB);
  z += 4.2 * sin(cellZ * 1.43 + 3.7 * seedC);

  float x = mix(-16.0, 16.0, seedB) + (seedC - 0.5) * 8.0;
  float terrainY = GrndHt(vec2(x, z));
  float loft = mix(12.0, 20.2, seedA);
  float stray = 1.9 * sin(cellZ * 1.31 + 4.0 * seedC);
  float baseY = max(terrainY + loft, 15.8 + 8.6 * seedC + stray);
  float bobAmp = 0.9 + 2.4 * Noisefv2(vec2(cellZ * 0.21, 4.7));
  float bob = bobAmp * sin(0.42 * tCur + 0.73 * cellZ + 0.11 * x + 6.2831 * seedA);
  float y = baseY + bob;
  return vec3(x, y, z);
}

float sporeInstanceRadius(float cellZ) {
  float coarse = Noisefv2(vec2(cellZ * 0.15, 7.7));
  float mid = Noisefv2(vec2(cellZ * 0.23, 4.1));
  float fine = Noisefv2(vec2(cellZ * 0.31, 2.9));
  return mix(1.25, 7.35, 0.50 * coarse + 0.28 * mid + 0.22 * fine);
}

float sporeMainPower(vec3 center) {
  return clamp(
    7.6
      + 0.90 * sin(0.24 * tCur + 0.06 * center.z)
      + 0.35 * sin(0.58 * tCur + 0.04 * center.x + 0.8),
    6.2,
    10.2
  );
}

float sporeMainPhase(vec3 center) {
  return 0.22 * sin(0.28 * tCur + 0.05 * center.z)
    + 0.08 * sin(0.71 * tCur + 0.03 * center.x);
}

vec3 sporeWorldInfo(vec3 pWorld, vec3 center, float radius) {
  vec3 p = pWorld - center;
  p.xz *= ROT(0.07 * center.z);
  p /= radius;
  p = p.xzy;

  vec3 z = p;
  float dr = 1.0;
  float t0 = 1.0;
  float r = 0.0;
  float power = sporeMainPower(center);
  float phase = sporeMainPhase(center);
  const float bailout = 2.0;

  for (int i = 0; i < 6; ++i) {
    r = length(z);
    if (r > bailout) break;
    float safeR = max(r, 1.0e-5);
    float theta = atan(z.y, z.x);
    float phi = asin(clamp(z.z / safeR, -1.0, 1.0)) + phase;

    dr = pow(safeR, power - 1.0) * dr * power + 1.0;

    float zr = pow(safeR, power);
    theta *= power;
    phi *= power;

    z = zr * vec3(
      cos(theta) * cos(phi),
      sin(theta) * cos(phi),
      sin(phi)
    ) + p;

    t0 = min(t0, zr);
  }

  float safeR = max(r, 1.0e-5);
  return vec3(0.5 * log(safeR) * safeR / dr * radius, t0, 0.0);
}

vec3 calcSporeNormal(vec3 pos, vec3 center, float radius) {
  vec3 eps = vec3(0.015, 0.0, 0.0);
  return normalize(vec3(
    sporeWorldInfo(pos + eps.xyy, center, radius).x - sporeWorldInfo(pos - eps.xyy, center, radius).x,
    sporeWorldInfo(pos + eps.yxy, center, radius).x - sporeWorldInfo(pos - eps.yxy, center, radius).x,
    sporeWorldInfo(pos + eps.yyx, center, radius).x - sporeWorldInfo(pos - eps.yyx, center, radius).x
  ));
}

vec3 fungalPalette(float trap, vec3 p, vec3 n) {
  float colony = 0.5 + 0.5 * sin(p.x * 7.0 + p.y * 6.5 + p.z * 5.0);
  float pore = 0.5 + 0.5 * sin(p.x * 18.0 - p.z * 12.0 + p.y * 8.0);

  vec3 abyss = vec3(0.012, 0.024, 0.018);
  vec3 mossDark = vec3(0.026, 0.108, 0.060);
  vec3 mossMid = vec3(0.060, 0.240, 0.110);
  vec3 leafGlow = vec3(0.180, 0.520, 0.220);
  vec3 paleSage = vec3(0.720, 0.900, 0.740);

  vec3 albedo = mix(abyss, mossDark, smoothstep(0.02, 0.18, trap));
  albedo = mix(albedo, mossMid, smoothstep(0.14, 0.42, trap + colony * 0.18));
  albedo = mix(albedo, leafGlow, smoothstep(0.36, 0.76, trap + pore * 0.10));

  albedo *= 0.84 + 0.16 * colony;
  albedo += paleSage * pow(pore, 8.0) * 0.12;
  albedo += vec3(0.070, 0.210, 0.120) * pow(1.0 - trap, 2.4) * 0.18;

  float rim = pow(clamp(1.0 - max(dot(n, normalize(vec3(0.0, 1.0, 0.3))), 0.0), 0.0, 1.0), 1.8);
  albedo += vec3(0.120, 0.320, 0.180) * rim * 0.14;
  return albedo;
}

vec3 sporeHaloTint(float cellSeed) {
  float hueNoise = Noisefv2(vec2(cellSeed * 0.13, 3.7));
  vec3 deep = vec3(0.035, 0.100, 0.060);
  vec3 mid = vec3(0.090, 0.250, 0.120);
  vec3 light = vec3(0.220, 0.520, 0.260);
  return mix(mix(deep, mid, 0.62), light, 0.28 + 0.34 * hueNoise);
}

vec3 sporeHaloAt(vec3 ro, vec3 rd, vec3 center, float radius, float tLimit, float cellSeed) {
  vec3 toCenter = center - ro;
  float tProj = dot(toCenter, rd);
  if (tProj <= 0.0 || tProj >= tLimit) return vec3(0.0);

  vec3 closest = ro + rd * tProj;
  float miss = length(center - closest) / max(radius, 1.0e-4);
  if (miss > 2.8) return vec3(0.0);

  float outer = exp(-3.1 * max(miss - 1.0, 0.0));
  float core = smoothstep(1.10, 0.14, miss);
  float halo = max(0.38 * outer, core);
  float distBoost = smoothstep(34.0, 150.0, tProj);
  float airFade = exp(-0.000045 * tProj * tProj);
  float intensity = (0.08 + 0.018 * radius) * mix(0.18, 1.0, distBoost) * airFade;

  return sporeHaloTint(cellSeed) * halo * intensity;
}

vec3 sporeFarGlow(vec3 ro, vec3 rd, float tLimit) {
  vec3 glow = vec3(0.0);
  float baseCell = floor(ro.z / 22.0);

  float heroBaseY = max(GrndHt(vec2(0.0, ro.z + 18.0)) + 13.2, 16.4);
  float heroBob = 1.9 * sin(0.48 * tCur + 0.6);
  vec3 heroCenter = vec3(0.0, heroBaseY + heroBob, ro.z + 18.0);
  glow += sporeHaloAt(ro, rd, heroCenter, 5.4, tLimit, 0.0);

  float rearBaseY = max(GrndHt(vec2(0.0, ro.z - 18.0)) + 12.8, 16.2);
  float rearBob = 1.7 * sin(0.44 * tCur + 2.1);
  vec3 rearCenter = vec3(0.0, rearBaseY + rearBob, ro.z - 18.0);
  glow += sporeHaloAt(ro, rd, rearCenter, 4.9, tLimit, -9.0);

  for (int k = -12; k <= 13; ++k) {
    float cellZ = baseCell + float(k);
    if (Noisefv2(vec2(cellZ * 0.19, 9.1)) < 0.26) continue;

    vec3 center = sporeInstanceCenter(cellZ);
    float radius = sporeInstanceRadius(cellZ);
    if (distance(center.xz, ro.xz) > 188.0) continue;
    glow += sporeHaloAt(ro, rd, center, radius, tLimit, cellZ + 13.0);
  }

  return clamp(glow, 0.0, 0.40);
}

bool traceSporeInstance(vec3 ro, vec3 rd, vec3 center, float radius, float tLimit, out float tHit, out float trap) {
  float tNear;
  float tFar;
  if (!raySphere(ro, rd, center, radius * 1.18, tNear, tFar)) return false;
  if (tNear > tLimit) return false;

  float t = max(tNear, 0.05);
  float maxT = min(tFar, tLimit);
  for (int i = 0; i < 120; ++i) {
    if (t > maxT) break;
    vec3 sampleInfo = sporeWorldInfo(ro + rd * t, center, radius);
    float d = sampleInfo.x;
    if (d < max(0.0014, 0.00065 * t)) {
      tHit = t;
      trap = sampleInfo.y;
      return true;
    }
    t += clamp(d, 0.018, 0.62);
  }
  return false;
}

bool traceSporeWorld(vec3 ro, vec3 rd, float tLimit, out float bestT, out vec3 bestCenter, out float bestRadius, out float bestTrap) {
  bool found = false;
  bestT = 1.0e9;
  float baseCell = floor(ro.z / 22.0);

  float heroBaseY = max(GrndHt(vec2(0.0, ro.z + 18.0)) + 13.2, 16.4);
  float heroBob = 1.9 * sin(0.48 * tCur + 0.6);
  vec3 heroCenter = vec3(0.0, heroBaseY + heroBob, ro.z + 18.0);
  float heroRadius = 5.4;
  float heroTHit;
  float heroTrap;
  if (traceSporeInstance(ro, rd, heroCenter, heroRadius, min(tLimit, bestT), heroTHit, heroTrap)) {
    found = true;
    bestT = heroTHit;
    bestCenter = heroCenter;
    bestRadius = heroRadius;
    bestTrap = heroTrap;
  }

  float rearBaseY = max(GrndHt(vec2(0.0, ro.z - 18.0)) + 12.8, 16.2);
  float rearBob = 1.7 * sin(0.44 * tCur + 2.1);
  vec3 rearCenter = vec3(0.0, rearBaseY + rearBob, ro.z - 18.0);
  float rearRadius = 4.9;
  float rearTHit;
  float rearTrap;
  if (traceSporeInstance(ro, rd, rearCenter, rearRadius, min(tLimit, bestT), rearTHit, rearTrap)) {
    found = true;
    bestT = rearTHit;
    bestCenter = rearCenter;
    bestRadius = rearRadius;
    bestTrap = rearTrap;
  }

  for (int k = -12; k <= 13; ++k) {
    float cellZ = baseCell + float(k);
    if (Noisefv2(vec2(cellZ * 0.19, 9.1)) < 0.26) continue;

    vec3 center = sporeInstanceCenter(cellZ);
    float radius = sporeInstanceRadius(cellZ);
    if (distance(center.xz, ro.xz) > 188.0) continue;

    float tHit;
    float trap;
    if (traceSporeInstance(ro, rd, center, radius, min(tLimit, bestT), tHit, trap)) {
      found = true;
      bestT = tHit;
      bestCenter = center;
      bestRadius = radius;
      bestTrap = trap;
    }
  }

  return found;
}

vec3 shadeSpore(vec3 ro, vec3 rd, float tHit, vec3 center, float radius, float trap, vec3 bg) {
  vec3 pos = ro + rd * tHit;
  vec3 nor = calcSporeNormal(pos, center, radius);
  float terrShadow = GrndSShadow(pos + nor * 0.03, sunDir);
  float sunFactor = sunFractalLightFactor() * cloudShadowFactor(pos);
  vec3 sunCol = sunLightColor() * sunFactor;
  float dif = max(dot(nor, sunDir), 0.0);
  float sky = 0.6 + 0.4 * max(dot(nor, vec3(0.0, 1.0, 0.0)), 0.0);
  float bac = max(0.3 + 0.7 * dot(vec3(-sunDir.x, -1.0, -sunDir.z), nor), 0.0);
  float spe = pow(max(dot(sunDir, reflect(rd, nor)), 0.0), 10.0);
  float rim = pow(clamp(1.0 + dot(rd, nor), 0.0, 1.0), 2.0);

  vec3 lin = 3.05 * mix(sunCol, vec3(0.250, 0.620, 0.320), 0.28) * dif * terrShadow;
  lin += 0.76 * bac * vec3(0.050, 0.150, 0.080);
  lin += 1.02 * sky * vec3(0.140, 0.380, 0.220) * terrShadow;
  lin += 1.42 * mix(vec3(0.860, 0.960, 0.880), sunCol, 0.34) * spe * terrShadow;
  lin += mix(vec3(0.180, 0.520, 0.280), sunCol, 0.16) * rim * 0.34;

  vec3 albedo = fungalPalette(pow(clamp(trap, 0.0, 1.0), 0.42), pos - center, nor);
  vec3 col = lin * albedo;
  float farRim = rim * smoothstep(34.0, 155.0, tHit);
  col += 0.16 * farRim * mix(albedo, vec3(0.220, 0.540, 0.300), 0.35);
  col = mix(col, bg, 1.0 - exp(-0.000080 * tHit * tHit));
  return pow(clamp(col, 0.0, 1.0), vec3(0.8));
}

vec3 ComposeScene(vec3 ro, vec3 rd) {
  float terrainT = GrndRay(ro, rd);
  float actorLimit = (terrainT < dstFar) ? terrainT : dstFar;
  vec3 bg = SkyCol(ro, rd);
  bg += sporeFarGlow(ro, rd, actorLimit);

  float apolloT;
  vec3 apolloCenter;
  vec2 apolloInfo;
  bool hasApollo = traceApolloWorld(ro, rd, actorLimit, apolloT, apolloCenter, apolloInfo);

  float sporeT;
  vec3 sporeCenter;
  float sporeRadius;
  float sporeTrap;
  bool hasSpore = traceSporeWorld(ro, rd, actorLimit, sporeT, sporeCenter, sporeRadius, sporeTrap);

  float nearestActor = 1.0e9;
  if (hasApollo) nearestActor = min(nearestActor, apolloT);
  if (hasSpore) nearestActor = min(nearestActor, sporeT);

  if (hasApollo && apolloT <= nearestActor && apolloT < actorLimit + 1.0e-4) {
    return shadeApollo(ro, rd, apolloT, apolloCenter, apolloInfo, bg);
  }

  if (hasSpore && sporeT <= nearestActor && sporeT < actorLimit + 1.0e-4) {
    return shadeSpore(ro, rd, sporeT, sporeCenter, sporeRadius, sporeTrap, bg);
  }

  if (terrainT < dstFar) {
    return shadeTerrain(ro, rd, terrainT, bg);
  }

  return pow(clamp(bg, 0.0, 1.0), vec3(0.8));
}

vec3 liftMainExposure(vec3 col) {
  vec3 lifted = col * 1.16;
  lifted += 0.04 * sqrt(clamp(col, 0.0, 1.0));
  return clamp(lifted, 0.0, 1.0);
}

mat3 EvalOri(vec3 v, vec3 a) {
  v = normalize(v);
  vec3 g = cross(v, vec3(0.0, 1.0, 0.0));
  vec3 w;
  if (g.y != 0.0) {
    g.y = 0.0;
    w = normalize(cross(g, v));
  } else {
    w = vec3(0.0, 1.0, 0.0);
  }

  float f = v.z * a.x - v.x * a.z;
  f = -clamp(2.0 * f, -0.2 * PI, 0.2 * PI);
  float c = cos(f);
  float s = sin(f);

  return mat3(
    c, -s, 0.0,
    s,  c, 0.0,
    0.0, 0.0, 1.0
  ) * AxToRMat(v, w);
}

void main() {
  vec2 fragCoord = vUv * iResolution.xy;
  vec2 canvas = iResolution.xy;
  vec2 uv = 2.0 * fragCoord / canvas - 1.0;
  uv.x *= canvas.x / canvas.y;

  tCur = iTime;
  hFac = 1.0 + uTerrHeight;
  fWav = 1.5 + 0.7 * uTerrLacunarity;
  aWav = 0.1 + 0.5 * uTerrPersistence;
  smFac = 0.3 + 0.7 * uTerrShape;
  grType = int(floor(uTerrGroundMode + 0.5));
  qType = int(floor(uTerrQualityMode + 0.5));
  shType = int(floor(uTerrSunMode + 0.5));

  if (qType == 1) {
    dstFar = 170.0;
    stepLim = 100;
    stepFac = 1.0;
  } else if (qType == 2) {
    dstFar = 200.0;
    stepLim = 200;
    stepFac = 0.5;
  } else {
    dstFar = 240.0;
    stepLim = 300;
    stepFac = 0.33;
  }

  if (shType == 1) {
    sunDir = normalize(vec3(1.0, 2.0, 1.0));
  } else if (shType == 2) {
    sunDir = normalize(vec3(1.0, 1.5, 1.0));
  } else {
    sunDir = normalize(vec3(1.0, 1.0, 1.0));
  }

  vec2 ori = vec2(uViewEl, uViewAz);
  vec2 ca = cos(ori);
  vec2 sa = sin(ori);
  mat3 vuMat = mat3(
    ca.y, 0.0, -sa.y,
    0.0, 1.0, 0.0,
    sa.y, 0.0, ca.y
  ) * mat3(
    1.0, 0.0, 0.0,
    0.0, ca.x, -sa.x,
    0.0, sa.x,  ca.x
  );

  vec3 rd = vuMat * normalize(vec3(uv, 3.0 * uViewZoom));

  float mvTot = 8.0 * uTerrFlightSpeed * tCur;
  vec3 flPos = TrackPath(mvTot);

  vec3 ro = vec3(flPos.x, 0.0, flPos.z);
  float hSum = 0.0;
  float nhSum = 0.0;
  float dt = 0.3;
  for (int k = -2; k <= 10; ++k) {
    float fk = float(k);
    hSum += GrndHt(TrackPath(mvTot + fk * dt).xz);
    nhSum += 1.0;
  }
  ro.y = 4.0 * hFac + hSum / max(nhSum, 1.0);

  vec3 col = liftMainExposure(ComposeScene(ro, rd));
  gl_FragColor = vec4(col, 1.0);
}
