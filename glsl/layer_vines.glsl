// =========================================================
// Apollonian Buildings Layer
//
// Legacy filename retained for compatibility, but this layer now
// represents terrain-anchored Apollonian buildings rather than
// vines. Each spawned instance evaluates the reference Apollonian
// fractal in its own local space and lifts the building body so
// the mass reads as architecture above the terrain instead of a
// half-buried plant.
// =========================================================

#define ENABLE_VINES 1

#define VINE_CELL 200.0
#define VINE_SPAWN_THRESH 0.60     // ~40% of cells spawn
#define VINE_SEGMENTS 10
#define VINE_LENGTH 300.0          // world-units along grow dir
#define VINE_RADIUS_BASE 25.0
#define VINE_RADIUS_TIP 5.0

// 1 apollo-unit = 1/APOLLO_SCALE world units.
// Decrease to enlarge each structure; increase to shrink.
#define APOLLO_SCALE 0.046
#define APOLLO_CENTER_LIFT 0.92

// ---- Terrain-top proxy ----
// Analytic smooth height used only to anchor buildings. The real
// terrain is a 3D Menger-fold DE; we can't sample its top cheaply.
// Mismatch between this proxy and the real surface is absorbed by
// the smooth union in de_scene.
float vineTerrainHeight(vec2 xz)
{
	vec4 a = perlin4(xz*0.07 + vec2(3.1, -1.7));
	return 10.2 + a.x*1.4 + a.y*0.6;
}

// Legacy helper kept for compatibility while the file name stays
// unchanged. It is not part of the active building geometry.
vec3 vineCurve(float t, vec3 anchor, vec3 growDir, vec4 seed)
{
	vec3 p = anchor;
	p += growDir * (t * VINE_LENGTH);

	// sway amplitudes scale with VINE_LENGTH so proportions stay
	// organic when size changes
	float swayX = (seed.x - 0.5)*50.0;
	float swayZ = (seed.y - 0.5)*50.0;
	p.x += swayX * sin(2.0*t + seed.z*6.2831853);
	p.z += swayZ * sin(2.7*t + seed.w*6.2831853);
	p.y += (seed.x - 0.5)*30.0 * sin(1.3*t + seed.w*6.2831853);
	return p;
}

// Capsule SDF (point-to-segment distance minus radius).
float sdSegment(vec3 p, vec3 a, vec3 b, float r)
{
	vec3 pa = p - a;
	vec3 ba = b - a;
	float h = clamp(dot(pa, ba)/dot(ba, ba), 0.0, 1.0);
	return length(pa - ba*h) - r;
}

// Reference-accurate Apollonian map (6 iter, tube-lattice + plane geometry).
// Returns vec3(dist, adr, orb):
//   dist  SDF distance to the fractal surface
//   adr   color tier (0.7-spaced integers → drives green banding)
//   orb   orbit trap (brightness variation)
// Matches the original reference shader map() exactly.
vec3 apolloMap3(vec3 p)
{
	float scale = 1.0;
	float orb   = 10000.0;
	for (int i = 0; i < 6; i++) {
		p      = -1.0 + 2.0*fract(0.5*p + 0.5);
		p     -= sign(p)*0.04;                   // key trick from reference
		float r2 = dot(p, p);
		float k  = 0.95/max(r2, 1e-5);
		p     *= k;
		scale *= k;
		orb    = min(orb, r2);
	}
	// Tube lattice: min distance to three axis-aligned cylinder pairs
	float d1  = sqrt(min(min(dot(p.xy,p.xy), dot(p.yz,p.yz)), dot(p.zx,p.zx))) - 0.02;
	// Horizontal plane at folded y=0
	float d2  = abs(p.y);
	float adr = (d1 < d2) ? 0.0 : 0.7*floor((0.5*p.y+0.5)*8.0);
	return vec3(0.5*min(d1,d2)/scale, adr, orb);
}

// ---- One cell's building (Apollonian fractal geometry) ----
// The Apollonian fractal from the reference shader IS the structure.
// It is evaluated directly in building-local space and lifted so the
// main mass sits above the ground plane instead of being buried in it.
float vineCellDE(vec2 cellId, vec3 pos)
{
	vec4 h = hash42(cellId + vec2(41.7, -13.3));

	vec2 jitter   = (h.yz - 0.5)*VINE_CELL*0.40;
	vec2 anchorXZ = (cellId + 0.5)*VINE_CELL + jitter;
	float anchorY = vineTerrainHeight(anchorXZ);

	if (h.x < VINE_SPAWN_THRESH) return 1e8;

	float apolloEnv = 2.0 / APOLLO_SCALE;
	vec3 center = vec3(anchorXZ.x, anchorY + apolloEnv*APOLLO_CENTER_LIFT, anchorXZ.y);

	// Envelope pre-check sized to the lifted Apollonian structure.
	// +5 offset ensures returned value is never 0 at bounding surface → no phantom shell.
	float xzPre  = length(pos.xz - anchorXZ) - apolloEnv*0.95;
	float yPre   = max((center.y - apolloEnv*0.98) - pos.y,
	                    pos.y - (center.y + apolloEnv*1.02));
	float preDist = max(xzPre, yPre);
	if (preDist > 0.0) return preDist + 5.0;

	// Reference map() evaluated in building-local space.
	// seed.xyz*2.3 gives each instance a unique view of the fractal.
	vec4 seed = hash42(cellId + vec2(-7.9, 23.1));
	vec3 q    = (pos - center) * APOLLO_SCALE + seed.xyz * 2.3;
	vec3 aRes = apolloMap3(q);
	return aRes.x / APOLLO_SCALE;
}

// Returns Apollonian color info (adr, orb) for the nearest building,
// evaluated in building-local coordinates so the pattern is anchored to
// the structure body. Called only at surface-hit points.
vec2 vineColorInfo(vec3 pos)
{
#if ENABLE_VINES
	vec2 cc   = pos.xz/VINE_CELL;
	vec2 base = floor(cc) - 1.0;
	float bestD   = 1e8;
	vec2  bestAO  = vec2(0.0, 1.0);
	for (int ix = 0; ix < 3; ix++) {
		for (int iz = 0; iz < 3; iz++) {
			vec2 cell = base + vec2(float(ix), float(iz));
			vec4 h = hash42(cell + vec2(41.7, -13.3));
			if (h.x < VINE_SPAWN_THRESH) continue;
			vec2  jitter   = (h.yz - 0.5)*VINE_CELL*0.40;
			vec2  anchorXZ = (cell + 0.5)*VINE_CELL + jitter;
			float anchorY  = vineTerrainHeight(anchorXZ);
			float apolloEnv = 2.0 / APOLLO_SCALE;
			vec3  center   = vec3(anchorXZ.x, anchorY + apolloEnv*APOLLO_CENTER_LIFT, anchorXZ.y);
			vec4  seed     = hash42(cell + vec2(-7.9, 23.1));
			// Same transform as vineCellDE — color matches geometry exactly.
			vec3 q = (pos - center)*APOLLO_SCALE + seed.xyz*2.3;
			vec3 aRes = apolloMap3(q);
			if (aRes.x < bestD) {
				bestD  = aRes.x;
				bestAO = aRes.yz;  // (adr, orb)
			}
		}
	}
	return bestAO;
#else
	return vec2(0.0, 1.0);
#endif
}

// 3x3 neighborhood so vine envelopes never leak beyond sampled
// cells. Per-cell sphere early-out keeps the 16-seg loop off the
// hot path for most rays.
float vineField(vec3 pos)
{
#if ENABLE_VINES
	vec2 cc = pos.xz/VINE_CELL;
	vec2 base = floor(cc) - 1.0;
	float d = 1e8;
	for (int ix = 0; ix < 3; ix++) {
		for (int iz = 0; iz < 3; iz++) {
			vec2 cell = base + vec2(float(ix), float(iz));
			d = min(d, vineCellDE(cell, pos));
		}
	}
	// Cap to one cell span: if all 9 sampled cells happened to not
	// spawn (prob ~1% at 40% spawn), d is 1e8; cap ensures marcher
	// steps at most VINE_CELL before re-querying and catching a
	// vine in the new neighborhood.
	return min(d, VINE_CELL);
#else
	return 1e8;
#endif
}
