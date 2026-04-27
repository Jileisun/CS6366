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

varying vec2 vUv;

const float PI = 3.14159;

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
  return vec3(0.2, 0.3, 0.55) + 0.25 * pow(1.0 - max(rd.y, 0.0), 8.0);
}

vec3 SkyCol(vec3 ro, vec3 rd) {
  ro.xz += 0.5 * tCur;
  float skyT = (50.0 - ro.y) / max(rd.y, 0.05);
  float f = Fbm2(0.1 * (ro + rd * skyT).xz);
  return mix(
    SkyBg(rd) + 0.35 * pow(max(dot(rd, sunDir), 0.0), 16.0),
    vec3(0.85),
    clamp(0.8 * f * rd.y + 0.1, 0.0, 1.0)
  );
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

vec3 ShowScene(vec3 ro, vec3 rd) {
  float dstGrnd = GrndRay(ro, rd);
  if (dstGrnd < dstFar) {
    ro += dstGrnd * rd;
    vec3 vn = GrndNf(ro);
    float f = 0.2 + 0.8 * smoothstep(0.7, 1.1, Fbm2(1.7 * ro.xz));
    vec3 col = mix(
      mix(vec3(0.2, 0.35, 0.1), vec3(0.1, 0.3, 0.15), f),
      mix(vec3(0.3, 0.25, 0.2), vec3(0.35, 0.3, 0.3), f),
      smoothstep(1.0, 3.0, ro.y)
    );
    col = mix(vec3(0.4, 0.3, 0.2), col, smoothstep(0.2, 0.6, abs(vn.y)));
    col = mix(col, vec3(0.75, 0.7, 0.7), smoothstep(5.0, 8.0, ro.y));
    col = mix(col, vec3(0.9), smoothstep(7.0, 9.0, ro.y) * smoothstep(0.0, 0.5, abs(vn.y)));
    float spec = mix(0.1, 0.5, smoothstep(8.0, 9.0, ro.y));
    vn = VaryNf(2.0 * ro, vn, 1.5);
    float sh = (shType > 1) ? GrndSShadow(ro, sunDir) : 1.0;
    col *= 0.2 + 0.1 * vn.y + 0.7 * sh * max(0.0, dot(vn, sunDir))
      + spec * sh * pow(max(0.0, dot(sunDir, reflect(rd, vn))), 16.0);
    float fog = dstGrnd / dstFar;
    fog *= fog;
    col = mix(col, SkyBg(rd), clamp(fog * fog, 0.0, 1.0));
    return pow(clamp(col, 0.0, 1.0), vec3(0.8));
  }

  return pow(clamp(SkyCol(ro, rd), 0.0, 1.0), vec3(0.8));
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
  float dt = 1.0;
  vec3 fpF = TrackPath(mvTot + dt);
  vec3 fpB = TrackPath(mvTot - dt);
  mat3 flMat = EvalOri((fpF - fpB) / (2.0 * dt), (fpF - 2.0 * flPos + fpB) / (dt * dt));

  vec3 ro = vec3(flPos.x, 0.0, flPos.z);
  float hSum = 0.0;
  float nhSum = 0.0;
  dt = 0.3;
  for (int k = -2; k <= 10; ++k) {
    float fk = float(k);
    hSum += GrndHt(TrackPath(mvTot + fk * dt).xz);
    nhSum += 1.0;
  }
  ro.y = 4.0 * hFac + hSum / max(nhSum, 1.0);
  rd = rd * flMat;

  vec3 col = ShowScene(ro, rd);
  gl_FragColor = vec4(col, 1.0);
}
