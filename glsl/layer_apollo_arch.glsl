// =========================================================
// Apollonian Architecture Layer
//
// Each building is an Apollonian fractal (6-iter, tube-lattice)
// INTERSECTED with a tall box container: max(apollo, box).
// The box defines the silhouette; the fractal fills it with
// organic lattice detail. Beyond the box the fractal is
// invisible, so it does not bleed into the rest of the scene.
//
// Distribution: left/right tower pairs repeat every ARCH_CELL
// units along Z. Per-instance hash varies height, width, X-jitter,
// and fractal phase so no two towers look identical.
//
// ALL functions are wrapped in #if ENABLE_ARCH so that when the
// layer is disabled the GLSL compiler sees only trivial stubs —
// the heavy Apollonian loops are not compiled at all.
// =========================================================

#define ENABLE_ARCH 0

#define ARCH_CELL    50.0
#define ARCH_X_MID   22.0
#define ARCH_SPAWN_T  0.25
#define ARCH_AS       0.18

#if ENABLE_ARCH

// Terrain height proxy. Different seed from vineTerrainHeight
// so both layers can coexist without duplicate symbol errors.
float archTerrainBase(vec2 xz) {
    vec4 a = perlin4(xz * 0.07 + vec2(1.5, -3.2));
    return 10.2 + a.x * 1.4 + a.y * 0.6;
}

// Axis-aligned box SDF (exact).
float arch_sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Apollonian DE — distance only, 6 iterations, tube-lattice geometry.
float archApolloDE(vec3 p) {
    float sc = 1.0;
    for (int i = 0; i < 6; i++) {
        p  = -1.0 + 2.0 * fract(0.5 * p + 0.5);
        p -= sign(p) * 0.04;
        float r2 = dot(p, p);
        float k  = 0.95 / max(r2, 1e-5);
        p *= k; sc *= k;
    }
    float d1 = sqrt(min(min(dot(p.xy, p.xy), dot(p.yz, p.yz)), dot(p.zx, p.zx))) - 0.02;
    float d2 = abs(p.y);
    return 0.5 * min(d1, d2) / sc;
}

// Apollonian map with color info (dist, adr, orb). Used at surface hits only.
vec3 archApolloMap(vec3 p) {
    float sc = 1.0;
    float orb = 1e5;
    for (int i = 0; i < 6; i++) {
        p  = -1.0 + 2.0 * fract(0.5 * p + 0.5);
        p -= sign(p) * 0.04;
        float r2 = dot(p, p);
        float k  = 0.95 / max(r2, 1e-5);
        p *= k; sc *= k; orb = min(orb, r2);
    }
    float d1  = sqrt(min(min(dot(p.xy, p.xy), dot(p.yz, p.yz)), dot(p.zx, p.zx))) - 0.02;
    float d2  = abs(p.y);
    float adr = (d1 < d2) ? 0.0 : 0.7 * floor((0.5 * p.y + 0.5) * 8.0);
    return vec3(0.5 * min(d1, d2) / sc, adr, orb);
}

// One tower: Apollonian fractal intersected with a box container.
// zi = Z-row index (float), side = -1.0 left / +1.0 right
float archTowerDE(float zi, float side, vec3 pos) {
    vec4 h = hash42(vec2(zi, side * 0.5 + 1.0));
    if (h.x < ARCH_SPAWN_T) return 1e8;

    float xb = side * (ARCH_X_MID + h.y * 10.0 + 2.0);
    float zb = zi * ARCH_CELL + (h.z - 0.5) * ARCH_CELL * 0.4;
    vec2  a2 = vec2(xb, zb);

    float hw = 2.5 + h.w * 2.0;
    float hh = 10.0 + h.x * 14.0;
    vec3  hs = vec3(hw, hh, hw * (0.8 + h.z * 0.4));

    vec3 ctr = vec3(a2.x, archTerrainBase(a2) + hh, a2.y);
    vec3 d3  = pos - ctr;

    float box = arch_sdBox(d3, hs);
    if (box > 5.0) return box;

    vec3  q  = d3 * ARCH_AS + h.yzw * 1.9;
    float ap = archApolloDE(q) / ARCH_AS;
    return max(ap, box);
}

// 3 Z-cells x 2 sides = 6 tower queries per march step.
float apolloArchField(vec3 pos) {
    float d    = 1e8;
    float base = floor(pos.z / ARCH_CELL) - 1.0;
    for (int i = 0; i < 3; i++) {
        float zi = base + float(i);
        d = min(d, archTowerDE(zi, -1.0, pos));
        d = min(d, archTowerDE(zi,  1.0, pos));
    }
    return min(d, ARCH_CELL);
}

// Color info for arch surface: returns vec3(dist, adr, orb).
// Called only at surface-hit pixels, not per march step.
vec3 apolloArchColorInfo(vec3 pos) {
    vec3  best = vec3(1e8, 0.0, 1.0);
    float base = floor(pos.z / ARCH_CELL) - 1.0;
    for (int i = 0; i < 3; i++) {
        float zi = base + float(i);

        vec4 hL = hash42(vec2(zi, 0.5));
        if (hL.x >= ARCH_SPAWN_T) {
            float xL  = -(ARCH_X_MID + hL.y * 10.0 + 2.0);
            float zL  = zi * ARCH_CELL + (hL.z - 0.5) * ARCH_CELL * 0.4;
            float hhL = 10.0 + hL.x * 14.0;
            vec3  cL  = vec3(xL, archTerrainBase(vec2(xL, zL)) + hhL, zL);
            vec3  qL  = (pos - cL) * ARCH_AS + hL.yzw * 1.9;
            vec3  rL  = archApolloMap(qL);
            if (rL.x < best.x) best = rL;
        }

        vec4 hR = hash42(vec2(zi, 1.5));
        if (hR.x >= ARCH_SPAWN_T) {
            float xR  = ARCH_X_MID + hR.y * 10.0 + 2.0;
            float zR  = zi * ARCH_CELL + (hR.z - 0.5) * ARCH_CELL * 0.4;
            float hhR = 10.0 + hR.x * 14.0;
            vec3  cR  = vec3(xR, archTerrainBase(vec2(xR, zR)) + hhR, zR);
            vec3  qR  = (pos - cR) * ARCH_AS + hR.yzw * 1.9;
            vec3  rR  = archApolloMap(qR);
            if (rR.x < best.x) best = rR;
        }
    }
    return best;
}

#else

// Disabled stubs — trivially compiled, never reached.
float apolloArchField(vec3 pos)     { return 1e8; }
vec3  apolloArchColorInfo(vec3 pos) { return vec3(1e8, 0.0, 1.0); }

#endif
