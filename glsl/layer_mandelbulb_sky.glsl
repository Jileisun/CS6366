// =========================================================
// Air Spore Mandelbulb Layer
//
// Sparse floating Mandelbulbs used as the airborne "spore
// balloons" above the terrain. Each instance stays inside its
// own bounding sphere, drifts laterally, rises through a slow
// life cycle, and grows as it climbs. Iteration count is kept
// low so this layer reads clearly without dominating cost.
// =========================================================

#define ENABLE_SKYBULBS 0

#define SKYBULB_CELL 18.0
#define SKYBULB_SPAWN_THRESH 0.10
#define SKYBULB_ITER 5
#define SKYBULB_Y_MIN 15.0
#define SKYBULB_Y_RANGE 5.0

float mandelbulbSkyDE(vec3 p)
{
	vec3 z = p;
	float dr = 1.0;
	float r = 0.0;
	for (int i = 0; i < SKYBULB_ITER; i++) {
		r = length(z);
		if (r > 4.0) break;
		float safeR = max(r, 1.0e-6);
		float theta = acos(clamp(z.z/safeR, -1.0, 1.0))*8.0;
		float phi = atan(z.y, z.x)*8.0;
		float zr = pow(safeR, 8.0);
		dr = 8.0*pow(safeR, 7.0)*dr + 1.0;
		z = zr*vec3(sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta)) + p;
	}
	float safeR = max(r, 1.0e-6);
	return 0.5*log(safeR)*safeR/dr;
}

float skybulbCellDE(vec2 cellId, vec3 pos)
{
	vec4 h = hash42(cellId + vec2(11.7, 3.1));
	if (h.x < SKYBULB_SPAWN_THRESH) return 1e8;

	vec2 jitter = (h.yz - 0.5)*SKYBULB_CELL*0.38;
	vec2 anchorXZ = (cellId + 0.5)*SKYBULB_CELL + jitter;

	float scale = mix(0.52, 1.05, h.w);
	float baseY = SKYBULB_Y_MIN + hash(dot(cellId, vec2(17.0, 29.0)))*SKYBULB_Y_RANGE;

	vec4 motion = hash42(cellId + vec2(17.4, -5.8));
	float life = fract(iTime*mix(0.012, 0.024, motion.x) + motion.y*5.0);
	float rise = mix(-1.8, 5.2, life);
	float grow = mix(0.84, 1.05, smoothstep(0.0, 0.92, life));

	float orbitR = 0.16 + motion.z*0.42;
	float orbitW = mix(0.08, 0.20, motion.w);
	float orbitPh = h.y*6.2831853;
	vec3 drift = vec3(
		cos(iTime*orbitW + orbitPh)*orbitR,
		sin(iTime*(orbitW*0.7) + motion.x*6.2831853)*(0.16 + motion.y*0.24),
		sin(iTime*orbitW + orbitPh)*orbitR
	);

	vec3 anchor = vec3(anchorXZ.x, baseY + rise, anchorXZ.y) + drift;
	float liveScale = scale*grow;

	float clusterR = liveScale*1.08 + 0.18;
	float bound = length(pos - anchor) - clusterR;
	if (bound > 0.04 + liveScale*0.03) return bound;

	vec4 tiltHash = hash42(cellId + vec2(51.2, 19.6));
	vec3 up = normalize(vec3((tiltHash.x - 0.5)*1.4, 1.0, (tiltHash.y - 0.5)*1.4));
	float twist = tiltHash.z*6.2831853 + iTime*mix(0.18, 0.42, tiltHash.w)*(tiltHash.x > 0.5 ? 1.0 : -1.0);

	vec3 ref = abs(up.y) < 0.98 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tang = normalize(cross(ref, up));
	vec3 bitang = cross(up, tang);
	vec3 t2 = cos(twist)*tang + sin(twist)*bitang;
	vec3 b2 = -sin(twist)*tang + cos(twist)*bitang;
	mat3 worldToLocal = mat3(
		vec3(t2.x, up.x, b2.x),
		vec3(t2.y, up.y, b2.y),
		vec3(t2.z, up.z, b2.z)
	);

	vec3 qMain = worldToLocal*(pos - anchor);
	float dMain = mandelbulbSkyDE(qMain/liveScale)*liveScale;
	return dMain;
}

float skybulbField(vec3 pos)
{
#if ENABLE_SKYBULBS
	if (pos.y < 10.0 || pos.y > 28.0) return 1e8;
	if (length(pos.xz) > 32.0) return 1e8;

	vec2 cc = pos.xz/SKYBULB_CELL;
	vec2 base = floor(cc) - 1.0;
	float d = 1e8;
	for (int ix = 0; ix < 3; ix++) {
		for (int iz = 0; iz < 3; iz++) {
			vec2 cell = base + vec2(float(ix), float(iz));
			d = min(d, skybulbCellDE(cell, pos));
		}
	}
	return d;
#else
	return 1e8;
#endif
}
