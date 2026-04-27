// =========================================================
// Ground Spore Plants Layer
//
// Cheap near-ground growth used to populate the terrain scene
// without paying for another true fractal. Each spawned plant
// is a capsule stem plus a smooth-unioned spore sac with a
// carved slit. A few tiny spores rise from the mouth over time.
// =========================================================

#define ENABLE_SPORE_PLANTS 0
#define ENABLE_SPORE_PLANT_SHOWCASE 0

#define SPORE_PLANT_CELL 4.8
#define SPORE_PLANT_SPAWN_THRESH 0.20

float sporePlantGroundHeight(vec2 anchorXZ, vec4 h)
{
	float waveA = sin(anchorXZ.x*0.16 + anchorXZ.y*0.11);
	float waveB = sin(anchorXZ.x*0.06 - anchorXZ.y*0.19 + 1.8);
	float waveC = sin(anchorXZ.x*0.025 + anchorXZ.y*0.031 + h.w*6.2831853);
	return 8.0 + waveA*1.35 + waveB*0.95 + waveC*0.70 + (h.x - 0.5)*1.3;
}

float sporePlantCellDE(vec2 cellId, vec3 pos)
{
	vec4 h = hash42(cellId + vec2(13.7, -4.2));
	bool showcaseCell =
		(ENABLE_SPORE_PLANT_SHOWCASE != 0) &&
		(abs(cellId.x) < 0.1) &&
		(abs(cellId.y) < 0.1);
	if (!showcaseCell && h.x < SPORE_PLANT_SPAWN_THRESH) return 1e8;

	vec2 jitter = showcaseCell ? vec2(0.0) : (h.yz - 0.5)*SPORE_PLANT_CELL*0.62;
	vec2 anchorXZ = showcaseCell ? vec2(0.0, 6.0) : (cellId + 0.5)*SPORE_PLANT_CELL + jitter;
	float groundY = sporePlantGroundHeight(anchorXZ, h) - 0.25;

	float stemH = mix(0.85, 2.25, h.y);
	float stemR = mix(0.08, 0.17, h.z);
	float sacR = mix(0.28, 0.76, h.w);
	if (showcaseCell) {
		stemH *= 1.35;
		stemR *= 1.18;
		sacR *= 1.42;
	}

	vec3 anchor = vec3(anchorXZ.x, groundY, anchorXZ.y);
	vec3 local = pos - anchor;

	vec3 boundCenter = vec3(0.0, stemH + sacR*0.55, 0.0);
	float bound = length(local - boundCenter) - (stemH + sacR*1.7);
	if (bound > 0.45) return bound;

	float stem = de_capsule(
		vec4(local.x, local.y - stemH*0.5, local.z, 1.0),
		stemH*0.5,
		stemR
	);

	vec3 sacLocal = local - vec3(0.0, stemH, 0.0);
	float sac = length(sacLocal) - sacR;
	sac = smoothmin(sac, length(sacLocal - vec3(sacR*0.44, -sacR*0.15, 0.0)) - sacR*0.70, sacR*0.26);
	sac = smoothmin(sac, length(sacLocal - vec3(-sacR*0.36, sacR*0.10, sacR*0.24)) - sacR*0.62, sacR*0.22);
	sac = smoothmin(sac, length(sacLocal - vec3(0.0, sacR*0.28, -sacR*0.32)) - sacR*0.54, sacR*0.20);

	float slit = de_capsule(
		vec4(sacLocal.x, sacLocal.y - sacR*0.05, sacLocal.z + sacR*0.08, 1.0),
		sacR*0.34,
		sacR*0.18
	);
	sac = max(sac, -slit);

	float plant = smoothmin(stem, sac, 0.18);

	float cycle = fract(iTime*mix(0.08, 0.14, h.x) + h.y*3.7);
	vec3 mouth = vec3(0.0, stemH + sacR*0.20, sacR*0.36);
	for (int i = 0; i < 3; i++) {
		if (!showcaseCell && i > 1) continue;
		float offset = float(i)*0.23;
		float t = fract(cycle + offset);
		float rise = t*t*mix(0.7, 2.8, h.z) + float(i)*0.12;
		vec2 swirl = vec2(
			cos(t*6.2831853 + h.w*6.2831853 + offset*9.0),
			sin(t*4.3982297 + h.z*4.8 + offset*6.0)
		)*(0.10 + 0.06*float(i));
		vec3 sporePos = mouth + vec3(swirl.x, rise, swirl.y);
		float sporeR = mix(0.06, 0.13, h.w)*mix(1.0, 0.65, t);
		plant = min(plant, length(local - sporePos) - sporeR);
	}

	return plant;
}

float sporePlantField(vec3 pos)
{
#if ENABLE_SPORE_PLANTS
	if (pos.y < 2.5 || pos.y > 18.5) return 1e8;

	vec2 cc = pos.xz/SPORE_PLANT_CELL;
	vec2 base = floor(cc) - 1.0;
	float d = 1e8;
	for (int ix = 0; ix < 3; ix++) {
		for (int iz = 0; iz < 3; iz++) {
			vec2 cell = base + vec2(float(ix), float(iz));
			d = min(d, sporePlantCellDE(cell, pos));
		}
	}
	return d;
#else
	return 1e8;
#endif
}
