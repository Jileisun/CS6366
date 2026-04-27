const vec3 PAL_MAT_DARK = vec3(0.022, 0.082, 0.034);
const vec3 PAL_MAT_WET = vec3(0.064, 0.190, 0.085);
const vec3 PAL_MAT_YELLOW = vec3(0.150, 0.255, 0.070);

vec2 domainWarp(vec2 p)
{
	vec4 n1 = perlin4(p*0.35 + vec2(1.7, -2.4));
	vec4 n2 = perlin4(p*0.35 + vec2(-4.1, 3.2));
	return vec2(n1.x + 0.45*n2.z, n2.y + 0.35*n1.w)*1.15;
}

float microbialMatPatch(vec3 pos)
{
	vec2 wp = pos.xz*0.12;
	wp += domainWarp(wp);
	vec4 matNoise = perlin4(wp + vec2(6.3, -4.1));
	return smoothstep(-0.20, 0.50, matNoise.x + 0.35*matNoise.y);
}

float microbialMatMask(vec3 pos, vec4 fractalInfo, float boneMask)
{
	float lowZone = 1.0 - smoothstep(7.5, 12.5, pos.y);
	float ridge = 1.0 - smoothstep(0.08, 1.15, abs(fractalInfo.w));
	float boneEdge = 4.0*boneMask*(1.0 - boneMask);
	float matPatch = microbialMatPatch(pos);

	float matAmt = clamp(
		lowZone*0.35 +
		ridge*0.25 +
		boneEdge*0.45 +
		matPatch*0.20,
		0.0,
		1.0
	);

	return smoothstep(0.35, 0.80, matAmt)*matPatch;
}

vec3 microbialMatColor(vec3 pos, float matMask)
{
	vec2 wp = pos.xz*0.18;
	wp += domainWarp(wp)*0.65;
	vec4 n = perlin4(wp + vec2(-2.2, 7.4));

	float wet = smoothstep(-0.15, 0.65, n.x + n.z*0.35);
	float breath = 0.5 + 0.5*sin(iTime*0.13 + n.w*4.2 + pos.x*0.025);
	vec3 matCol = mix(PAL_MAT_DARK, PAL_MAT_WET, wet);
	matCol = mix(matCol, PAL_MAT_YELLOW, smoothstep(0.52, 0.92, n.y)*0.22);
	matCol += PAL_PALE_GLOW*matMask*(0.015 + 0.025*breath);

	return clamp(matCol, 0.0, 0.42);
}
