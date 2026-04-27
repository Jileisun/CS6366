precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform float uZoom;
uniform float uMbPower;
uniform float uMbIterations;
uniform float uMbBailout;
uniform float uMbScale;
uniform float uMbSpinSpeed;
uniform float uMbPhaseStrength;
uniform float uMbPhaseSpeed;
uniform float uMbYaw;
uniform float uMbPitch;

varying vec2 vUv;

// Created by evilryu
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Adapted here as a standalone Mandelbulb scene with a fungal / spore palette.

float pixel_size = 0.0;
const int MAX_MB_ITER = 12;

void ry(inout vec3 p, float a) {
  float c = cos(a);
  float s = sin(a);
  vec3 q = p;
  p.x = c * q.x + s * q.z;
  p.z = -s * q.x + c * q.z;
}

/*
z = r*(sin(theta)cos(phi) + i cos(theta) + j sin(theta)sin(phi)

zn+1 = zn^8 + c

z^8 = r^8 * (sin(8*theta)*cos(8*phi) + i cos(8*theta) + j sin(8*theta)*sin(8*theta)

zn+1' = 8 * zn^7 * zn' + 1
*/

vec3 mb(vec3 p) {
  p.xyz = p.xzy;
  vec3 z = p;
  float power = uMbPower;
  float r = 0.0;
  float dr = 1.0;
  float t0 = 1.0;

  for (int i = 0; i < MAX_MB_ITER; ++i) {
    if (float(i) >= floor(uMbIterations + 0.5)) break;
    r = length(z);
    if (r > uMbBailout) break;

    float safeR = max(r, 1.0e-5);
    float theta = atan(z.y, z.x);
    float phi = asin(clamp(z.z / safeR, -1.0, 1.0));
    phi += uMbPhaseStrength * iTime * uMbPhaseSpeed;

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
  return vec3(0.5 * log(safeR) * safeR / dr, t0, 0.0);
}

vec3 mapScene(vec3 p) {
  float scale = max(uMbScale, 0.1);
  ry(p, iTime * uMbSpinSpeed);
  vec3 res = mb(p / scale);
  res.x *= scale;
  return res;
}

float softshadow(vec3 ro, vec3 rd, float k) {
  float shadow = 1.0;
  float t = 0.01;

  for (int i = 0; i < 50; ++i) {
    float h = mapScene(ro + rd * t).x;
    if (h < 0.001) return 0.02;
    shadow = min(shadow, k * h / t);
    t += clamp(h, 0.01, 2.0);
  }

  return shadow;
}

vec3 calcNormal(vec3 pos) {
  vec3 eps = vec3(0.001, 0.0, 0.0);
  return normalize(vec3(
    mapScene(pos + eps.xyy).x - mapScene(pos - eps.xyy).x,
    mapScene(pos + eps.yxy).x - mapScene(pos - eps.yxy).x,
    mapScene(pos + eps.yyx).x - mapScene(pos - eps.yyx).x
  ));
}

vec3 intersect(vec3 ro, vec3 rd) {
  float t = 1.0;
  float resT = 0.0;
  vec3 resC = vec3(0.0);
  float maxError = 1000.0;
  float pd = 100.0;
  float os = 0.0;
  float error = 1000.0;

  for (int i = 0; i < 48; i++) {
    if (error < pixel_size * 0.5 || t > 20.0) {
      continue;
    }

    vec3 c = mapScene(ro + rd * t);
    float d = c.x;
    float step;

    if (d > os) {
      os = 0.4 * d * d / pd;
      step = d + os;
      pd = d;
    } else {
      step = -os;
      os = 0.0;
      pd = 100.0;
      d = 1.0;
    }

    error = d / t;

    if (error < maxError) {
      maxError = error;
      resT = t;
      resC = c;
    }

    t += step;
  }

  if (t > 20.0) resT = -1.0;
  return vec3(resT, resC.y, resC.z);
}

float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec3 fungalPalette(float trap, vec3 p, vec3 n) {
  float colony = 0.5 + 0.5 * sin(p.x * 7.0 + p.y * 6.5 + p.z * 5.0);
  float pore = 0.5 + 0.5 * sin(p.x * 18.0 - p.z * 12.0 + p.y * 8.0);

  vec3 voidBlack = vec3(0.015, 0.006, 0.022);
  vec3 bruisePurple = vec3(0.170, 0.030, 0.220);
  vec3 arterialRed = vec3(0.470, 0.050, 0.100);
  vec3 magentaBloom = vec3(0.760, 0.180, 0.520);
  vec3 paleGlow = vec3(0.960, 0.620, 0.860);

  vec3 albedo = mix(voidBlack, bruisePurple, smoothstep(0.02, 0.18, trap));
  albedo = mix(albedo, arterialRed, smoothstep(0.14, 0.42, trap + colony * 0.18));
  albedo = mix(albedo, magentaBloom, smoothstep(0.36, 0.76, trap + pore * 0.10));

  albedo *= 0.84 + 0.16 * colony;
  albedo += paleGlow * pow(pore, 8.0) * 0.16;
  albedo += vec3(0.240, 0.020, 0.090) * pow(1.0 - trap, 2.4) * 0.25;

  float rim = pow(clamp(1.0 - max(dot(n, normalize(vec3(0.0, 1.0, 0.3))), 0.0), 0.0, 1.0), 1.8);
  albedo += vec3(0.300, 0.030, 0.160) * rim * 0.18;

  return albedo;
}

vec3 renderBackground(vec2 fragCoord, vec2 q, vec2 uv, vec3 rd, vec3 ro) {
  vec3 hazeLow = vec3(0.010, 0.000, 0.018);
  vec3 hazeHigh = vec3(0.120, 0.015, 0.090);
  vec3 bg = mix(hazeLow, hazeHigh, clamp(0.5 + 0.5 * rd.y, 0.0, 1.0));
  bg += exp(uv.y - 2.0) * vec3(0.180, 0.015, 0.060);

  float halo = clamp(dot(normalize(-ro), rd), 0.0, 1.0);
  bg += vec3(0.950, 0.180, 0.520) * pow(halo, 17.0) * 0.40;

  vec2 sporeCell = floor(fragCoord * 0.45 + vec2(iTime * 4.0, -iTime * 1.5));
  float mote = hash21(sporeCell);
  float flicker = 0.55 + 0.45 * sin(iTime * 3.0 + mote * 6.2831853);
  float spore = smoothstep(0.992, 1.0, mote) * flicker;
  bg += vec3(0.950, 0.250, 0.620) * spore * (0.08 + 0.16 * (1.0 - q.y));

  return bg;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord.xy / iResolution.xy;
  vec2 uv = -1.0 + 2.0 * q;
  uv.x *= iResolution.x / iResolution.y;

  pixel_size = 1.0 / (iResolution.x * 3.0);

  vec3 ta = vec3(0.0, 0.0, 0.0);
  float radius = mix(3.6, 1.75, clamp(uZoom, 0.0, 1.0));
  float cp = cos(uMbPitch);
  vec3 ro = radius * vec3(
    sin(uMbYaw) * cp,
    sin(uMbPitch),
    cos(uMbYaw) * cp
  );

  vec3 cf = normalize(ta - ro);
  vec3 cs = normalize(cross(cf, vec3(0.0, 1.0, 0.0)));
  vec3 cu = normalize(cross(cs, cf));
  vec3 rd = normalize(uv.x * cs + uv.y * cu + 3.0 * cf);

  vec3 sundir = normalize(vec3(0.18, 0.72, 0.62));
  vec3 sun = vec3(1.300, 0.320, 0.620);
  vec3 skycolor = vec3(0.380, 0.100, 0.320);

  vec3 bg = renderBackground(fragCoord, q, uv, rd, ro);
  vec3 col = bg;

  vec3 res = intersect(ro, rd);

  if (res.x > 0.0) {
    vec3 p = ro + res.x * rd;
    vec3 n = calcNormal(p);
    float shadow = softshadow(p, sundir, 10.0);

    float dif = max(0.0, dot(n, sundir));
    float sky = 0.6 + 0.4 * max(0.0, dot(n, vec3(0.0, 1.0, 0.0)));
    float bac = max(0.3 + 0.7 * dot(vec3(-sundir.x, -1.0, -sundir.z), n), 0.0);
    float spe = max(0.0, pow(clamp(dot(sundir, reflect(rd, n)), 0.0, 1.0), 10.0));
    float rim = pow(clamp(1.0 + dot(rd, n), 0.0, 1.0), 2.0);

    vec3 lin = 3.9 * sun * dif * shadow;
    lin += 0.8 * bac * vec3(0.210, 0.030, 0.070);
    lin += 1.0 * sky * skycolor * shadow;
    lin += 2.6 * spe * vec3(1.000, 0.520, 0.820) * shadow;
    lin += vec3(0.700, 0.120, 0.440) * rim * 0.40;

    float trap = pow(clamp(res.y, 0.0, 1.0), 0.42);
    vec3 albedo = fungalPalette(trap, p, n);

    col = lin * albedo;
    col = mix(col, bg, 1.0 - exp(-0.0012 * res.x * res.x));
  }

  // post
  col = pow(clamp(col, 0.0, 1.0), vec3(0.45));
  col = col * 0.72 + 0.28 * col * col * (3.0 - 2.0 * col);
  col = mix(col, vec3(dot(col, vec3(0.33))), -0.18);
  col *= 0.58 + 0.42 * pow(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.7);

  fragColor = vec4(col, 1.0);
}

void main() {
  mainImage(gl_FragColor, gl_FragCoord.xy);
}
