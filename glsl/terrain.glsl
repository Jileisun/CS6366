precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform vec4 iMouse;
uniform float uZoom;
uniform float uTerrainFracScale;
uniform float uTerrainAng1;
uniform float uTerrainAng2;
uniform vec3 uTerrainShift;
uniform float uTerrainFoldK;
uniform vec2 uTerrainGridOffset;
uniform vec3 uCameraOrigin;

varying vec2 vUv;

#define PI 3.14159265
#define SQRT2 1.4142135
#define SQRT3 1.7320508
#define SQRT5 2.2360679
#define FOV 2.5

#define MAX_DIST 500.
#define MIN_DIST 1e-5
#define MAX_MARCHES 512.
#define LIGHT_ANGLE 0.04

#define ENABLE_BASE_TERRAIN 1

//how much does the terrain change in large scale
#define PERLIN_SCALE 2

//coefficients are fine-tuned
//you can get all kinds of weird terrain by carefully setting the coefficients,
//even forests are possible, but they may look not as realistic as the rock fractals
const int FRACTAL_ITER = 14;
const vec3 iFracCol = vec3(0.16, 0.23, 0.11);

float PBR_METALLIC = 0.0;
float PBR_ROUGHNESS = 0.7;

vec3 BACKGROUND_COLOR = vec3(0.);
vec3 LIGHT_DIRECTION = normalize(vec3(-1.,1.,0.68));
vec3 LIGHT_COLOR = vec3(1., 0.95, 0.8);
bool SHADOWS_ENABLED = true;

float gamma_material = 1.0;
float gamma_sky = 0.76;
float gamma_camera = 2.2;

const vec3 PAL_DEEP_MOSS = vec3(0.018, 0.070, 0.034);
const vec3 PAL_MUTED_TEAL = vec3(0.055, 0.165, 0.125);
const vec3 PAL_YELLOW_GREEN = vec3(0.240, 0.360, 0.115);
const vec3 PAL_PALE_GLOW = vec3(0.520, 0.700, 0.410);
const vec3 PAL_COLD_HIGHLIGHT = vec3(0.360, 0.620, 0.540);
const vec3 PAL_BONE_WHITE = vec3(0.720, 0.760, 0.680);
const vec3 PAL_COOL_BONE = vec3(0.560, 0.680, 0.650);

float LOD;

float hash(float p)
{
   p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec4 hash41(float p)
{
	vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);

}

vec4 hash42(vec2 p)
{
	vec4 p4 = fract(vec4(p.xyxy) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);

}


//normally distributed random numbers
vec3 randn(float p)
{
    vec4 rand = hash41(p);
    vec3 box_muller = sqrt(-2.*log(max(vec3(rand.x,rand.x,rand.z),1e-8)))*vec3(sin(2.*PI*rand.y),cos(2.*PI*rand.y),sin(2.*PI*rand.w));
    return box_muller;
}

//uniformly inside a sphere
vec3 random_sphere(float p)
{
    return normalize(randn(p))*pow(hash(p+85.67),0.333333);
}

vec3 cosdistr(vec3 dir, float seed)
{
    vec3 rand_dir = normalize(randn(seed*SQRT2));
    vec3 norm_dir = normalize(rand_dir - dot(dir,rand_dir)*dir);
    float u = hash(seed);
    return normalize(dir*sqrt(u) + norm_dir*sqrt(1.-u));
}


vec4 perlin_octave(vec2 p)
{
   vec2 pi = floor(p);
   vec2 pf = p - pi;
   vec2 pfc = 0.5 - 0.5*cos(pf*PI);
   vec2 a = vec2(0.,1.);

   vec4 a00 = hash42(pi+a.xx);
   vec4 a01 = hash42(pi+a.xy);
   vec4 a10 = hash42(pi+a.yx);
   vec4 a11 = hash42(pi+a.yy);

   vec4 i1 = mix(a00, a01, pfc.y);
   vec4 i2 = mix(a10, a11, pfc.y);

   return mix(i1, i2, pfc.x);
}

mat2 rotat = mat2(cos(0.5), -sin(0.5), sin(0.5), cos(0.5));

vec4 perlin4(vec2 p)
{
	float a = 1.;
	vec4 res = vec4(0.);
	for(int i = 0; i < PERLIN_SCALE; i++)
	{
		res += a*(perlin_octave(p)-0.5);
        //inverse perlin
		p *= 0.6*rotat;
		a *= 1.2;
	}
	return res;
}

/////
/////Code from Marble Marcher Community Edition
/////

#define COL col_scene
#define DE de_scene
//##########################################
//   Space folding
//##########################################
void planeFold(inout vec4 z, vec3 n, float d) {
	z.xyz -= 2.0 * min(0.0, dot(z.xyz, n) - d) * n;
}
void sierpinskiFold(inout vec4 z) {
	z.xy -= min(z.x + z.y, 0.0);
	z.xz -= min(z.x + z.z, 0.0);
	z.yz -= min(z.y + z.z, 0.0);
}

// Polynomial smooth minimum by iq
float smoothmin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
  return mix(a, b, h) - k*h*(1.0-h);
}

// Soft menger fold: smoothmin rounds each crease so the iterated
// surface reads as organic instead of crystalline. k controls the
// smoothing radius in iteration-local space — bigger = softer,
// but fine detail blurs. 0.08 gives visible rounding without
// dissolving ridges.
void mengerFold(inout vec4 z) {
	float a = smoothmin(z.x - z.y, 0.0, uTerrainFoldK);
	z.x -= a;
	z.y += a;
	a = smoothmin(z.x - z.z, 0.0, uTerrainFoldK);
	z.x -= a;
	z.z += a;
	a = smoothmin(z.y - z.z, 0.0, uTerrainFoldK);
	z.y -= a;
	z.z += a;
}
void boxFold(inout vec4 z, vec3 r) {
	z.xyz = clamp(z.xyz, -r, r) * 2.0 - z.xyz;
}
void rotX(inout vec4 z, float s, float c) {
	z.yz = vec2(c*z.y + s*z.z, c*z.z - s*z.y);
}
void rotY(inout vec4 z, float s, float c) {
	z.xz = vec2(c*z.x - s*z.z, c*z.z + s*z.x);
}
void rotZ(inout vec4 z, float s, float c) {
	z.xy = vec2(c*z.x + s*z.y, c*z.y - s*z.x);
}
void rotX(inout vec4 z, float a) {
	rotX(z, sin(a), cos(a));
}
void rotY(inout vec4 z, float a) {
	rotY(z, sin(a), cos(a));
}
void rotZ(inout vec4 z, float a) {
	rotZ(z, sin(a), cos(a));
}

//##########################################
//   Primitive DEs
//##########################################
float de_sphere(vec4 p, float r) {
	return (length(p.xyz) - r) / p.w;
}
float de_box(vec4 p, vec3 s) {

	vec3 a = abs(p.xyz) - s;
	return (min(max(max(a.x, a.y), a.z), 0.0) + length(max(a, 0.0))) / p.w;
}
float de_tetrahedron(vec4 p, float r) {
	float md = max(max(-p.x - p.y - p.z, p.x + p.y - p.z),
				max(-p.x + p.y + p.z, p.x - p.y + p.z));
	return (md - r) / (p.w * sqrt(3.0));
}
float de_capsule(vec4 p, float h, float r) {
	p.y -= clamp(p.y, -h, h);
	return (length(p.xyz) - r) / p.w;
}

//##########################################
//   Main DEs
//##########################################

// Shift the periodic fold grid off world origin so the abs() fold
// creases (at integer multiples of the mod period in pre-fold space)
// don't align with world x=0 / z=0. Without this offset, looking
// straight down at the origin shows two crisp axis-lines because
// perlin perturbation is smallest there, leaving the mirror
// symmetry through world origin visually undisguised.
float de_fractal(vec4 p)
{
	vec3 p0 = p.xyz;
	float s1 = sin(uTerrainAng1);
	float c1 = cos(uTerrainAng1);
	float s2 = sin(uTerrainAng2);
	float c2 = cos(uTerrainAng2);
	p.xz += uTerrainGridOffset;
	p.xz = mod(p.xz + vec2(0.5*p.w), vec2(1.*p.w)) - vec2(0.5*p.w);
	vec4 perlin1 = perlin4(p0.xz);
	vec3 shift = uTerrainShift + 0.35*perlin1.xyz;
	for (int i = 0; i < FRACTAL_ITER; ++i) {

		p.xyz = abs(p.xyz);

		rotZ(p, s1, c1);
		mengerFold(p);
		rotX(p, s2, c2);
		p *= uTerrainFracScale*(1.);
		p.xyz += shift;

	}

	return 0.66*de_box(p, vec3(6.0));
}

vec4 col_fractal(vec4 p)
{
	vec3 p0 = p.xyz;
	vec3 orbit = vec3(0.0);
	float s1 = sin(uTerrainAng1);
	float c1 = cos(uTerrainAng1);
	float s2 = sin(uTerrainAng2);
	float c2 = cos(uTerrainAng2);
	p.xz += uTerrainGridOffset;
	p.xz = mod(p.xz + vec2(0.5*p.w), vec2(1.*p.w)) - vec2(0.5*p.w);
	vec4 perlin1 = perlin4(p0.xz);
	vec3 shift = uTerrainShift + 0.35*(perlin1.xyz - 0.5);
	for (int i = 0; i < FRACTAL_ITER; ++i) {
		p.xyz = abs(p.xyz);
		rotZ(p, s1, c1);
		mengerFold(p);
		rotX(p, s2, c2);
		p *= uTerrainFracScale*(1.);
		p.xyz += shift;
		orbit = max(orbit, abs(p.xyz)*iFracCol);
	}
	return vec4(orbit, de_box(p, vec3(6.0)));
}

float breathingMask(vec3 pos, float mask)
{
	float a = 0.5 + 0.5*sin(iTime*0.19 + mask*3.1 + pos.x*0.045);
	float b = 0.5 + 0.5*sin(iTime*0.11 + mask*5.7 + pos.z*0.038 + 1.8);
	return a*0.58 + b*0.42;
}

// Floating Mandelbulb field is injected at the marker below.
// See glsl/layer_mandelbulb_sky.glsl. Exposes: skybulbField(pos),
// ENABLE_SKYBULBS.
// __SKYBULB_LAYER__

// Ground spore plants are injected at the marker below.
// See glsl/layer_spore_plants.glsl. Exposes: sporePlantField(pos),
// ENABLE_SPORE_PLANTS.
// __SPORE_PLANT_LAYER__

// Giant vines field is injected at the marker below.
// See glsl/layer_vines.glsl. Exposes: vineField(pos), ENABLE_VINES.
// __VINE_LAYER__

// Apollonian architecture is injected at the marker below.
// See glsl/layer_apollo_arch.glsl. Exposes: apolloArchField(pos), ENABLE_ARCH.
// __APOLLO_ARCH_LAYER__

// __TERRAIN_SURFACE_LAYERS__

#define ENABLE_MICROBIAL_MAT 0

float boneExposureMask(vec3 pos, vec4 fractalInfo)
{
	vec4 large = perlin4(pos.xz*0.18 + vec2(-3.8, 5.1));
	float orbit = clamp(dot(fractalInfo.xyz, vec3(0.45, 0.35, 0.20))*0.20, 0.0, 1.0);
	float ridge = 1.0 - smoothstep(0.08, 1.15, abs(fractalInfo.w));
	float high = smoothstep(8.4, 13.8, pos.y + large.x*1.1);
	float broad = smoothstep(-0.30, 0.56, large.x + large.y*0.35);

	float structure = clamp(ridge*0.30 + orbit*0.30 + high*0.12 + large.z*0.12, 0.0, 1.0);
	float exposed = smoothstep(0.58, 0.88, structure)*mix(0.18, 0.80, broad);

	return clamp(exposed, 0.0, 1.0);
}

vec3 alienTerrainAlbedo(vec3 pos, vec4 fractalInfo)
{
	vec4 large = perlin4(pos.xz*0.18 + vec2(4.7, -2.3));
	float height = smoothstep(7.2, 13.4, pos.y + large.x*1.4);

	float orbit = clamp(dot(fractalInfo.xyz, vec3(0.45, 0.35, 0.20))*0.20, 0.0, 1.0);
	float foldedRidge = 1.0 - smoothstep(0.05, 1.45, abs(fractalInfo.w));
	float growth = clamp(orbit*0.75 + foldedRidge*0.55 + large.y*0.18, 0.0, 1.0);

	float breath = breathingMask(pos, growth);

	float skybulbDist = skybulbField(pos);
	float skybulbShell = 1.0 - smoothstep(0.0, 0.10, skybulbDist);
	float sporePlantDist = sporePlantField(pos);
	float sporePlantShell = 1.0 - smoothstep(0.0, 0.10, sporePlantDist);

	float boneMask = boneExposureMask(pos, fractalInfo);
	float boneVein = smoothstep(0.30, 0.92, orbit + foldedRidge*0.52 + large.w*0.18);
	vec3 col = mix(PAL_BONE_WHITE, PAL_COOL_BONE, clamp(0.35 + height*0.30 + large.z*0.45, 0.0, 1.0));
	col *= 0.72 + 0.24*boneVein;
	col += PAL_COLD_HIGHLIGHT*smoothstep(0.62, 1.0, orbit + large.z*0.18)*0.035;
	col += PAL_PALE_GLOW*boneMask*(0.020 + 0.030*breath);

#if ENABLE_MICROBIAL_MAT
	float matMask = microbialMatMask(pos, fractalInfo, boneMask);
	matMask *= (1.0 - skybulbShell*0.90);
	matMask *= (1.0 - sporePlantShell*0.80);
	vec3 matCol = microbialMatColor(pos, matMask);
	col = mix(col, matCol, matMask*0.68);
#endif

#if ENABLE_SKYBULBS
	if (skybulbShell > 0.001) {
		float pulse = 0.5 + 0.5*sin(iTime*0.35 + pos.y*0.42 + large.x*4.0);
		float ember = smoothstep(0.62, 1.0, pulse + large.w*0.18);
		vec3 sporeBulbCol = mix(vec3(0.020, 0.000, 0.010), vec3(0.260, 0.010, 0.060), pulse);
		sporeBulbCol = mix(sporeBulbCol, vec3(0.420, 0.040, 0.330), smoothstep(0.28, 0.88, pulse + large.y*0.15));
		sporeBulbCol += vec3(0.760, 0.060, 0.120)*ember*0.26;
		sporeBulbCol += vec3(0.550, 0.080, 0.680)*smoothstep(0.45, 1.0, pulse + large.z*0.12)*0.18;
		col = mix(col, sporeBulbCol, skybulbShell);
	}
#endif

#if ENABLE_SPORE_PLANTS
	if (sporePlantShell > 0.001) {
		float stalkMask = 1.0 - smoothstep(8.8, 11.4, pos.y + large.x*0.8);
		float pulse = 0.5 + 0.5*sin(iTime*0.85 + pos.x*0.21 - pos.z*0.18 + large.y*6.0);
		float capMask = smoothstep(0.25, 0.92, pulse + large.z*0.22 + height*0.18);
		vec3 stalkCol = mix(vec3(0.020, 0.000, 0.020), vec3(0.220, 0.020, 0.090), capMask*0.55 + stalkMask*0.35);
		vec3 sacCol = mix(vec3(0.310, 0.020, 0.070), vec3(0.620, 0.080, 0.460), capMask);
		sacCol += vec3(0.860, 0.100, 0.120)*smoothstep(0.70, 1.0, pulse)*0.20;
		col = mix(col, mix(stalkCol, sacCol, 1.0 - stalkMask*0.85), sporePlantShell);
	}
#endif

#if ENABLE_VINES
	// Apollonian building palette: dark body + cold mineral highlights
	// + warm cavity bleed from orbit-trap pockets.
	float vineDist  = vineField(pos);
	float vineShell = 1.0 - smoothstep(0.0, 0.10, vineDist);
	if (vineShell > 0.01) {
		vec2  aInfo = vineColorInfo(pos);
		float adr   = aInfo.x;
		float orb   = clamp(aInfo.y * 1.25, 0.0, 1.0);
		vec3 gc = 0.5 + 0.5*cos(6.2831*adr*0.16 + vec3(3.4, 2.6, 1.4));
		vec3 apolloBase = vec3(0.040, 0.032, 0.070);
		vec3 apolloHigh = vec3(0.150 + gc.x*0.18, 0.220 + gc.y*0.15, 0.360 + gc.z*0.22);
		vec3 apolloCol  = mix(apolloBase, apolloHigh, orb*0.74 + 0.14);
		apolloCol += vec3(0.520, 0.080, 0.140) * smoothstep(0.84, 1.0, 1.0 - orb) * 0.28;
		col = mix(col, apolloCol, vineShell);
	}
#endif

#if ENABLE_ARCH
	{
		float archD    = apolloArchField(pos);
		float archMask = 1.0 - smoothstep(0.0, 0.18, archD);
		if (archMask > 0.01) {
			vec3  aInfo = apolloArchColorInfo(pos);
			float adr   = aInfo.y;
			float orb   = clamp(aInfo.z * 1.2, 0.0, 1.0);
			// Cold alien stone palette: dark obsidian base, blue-teal lattice glow,
			// red emissive bleed in deep orbit-trap cavities.
			vec3 gc      = 0.5 + 0.5*cos(6.2831*adr*0.12 + vec3(3.5, 2.8, 1.8));
			vec3 archBase = vec3(0.05, 0.04, 0.09);
			vec3 archHigh = vec3(0.16 + gc.x*0.22, 0.25 + gc.y*0.16, 0.42 + gc.z*0.25);
			vec3 archCol  = mix(archBase, archHigh, orb*0.75 + 0.15);
			archCol += vec3(0.50, 0.05, 0.02) * smoothstep(0.88, 1.0, 1.0 - orb) * 0.45;
			col = mix(col, archCol, archMask);
		}
	}
#endif

	return clamp(col, 0.0, 0.96);
}

// Surface inflation (Minkowski sum with small sphere). Any concavity
// with curvature radius < SURFACE_SOFTEN_R gets rounded out. Too
// large and fine detail dissolves into a blob.
#define SURFACE_SOFTEN_R 0.03

float de_scene(vec3 pos)
{
	float d = 1e8;
#if ENABLE_BASE_TERRAIN
	vec4 p = vec4(pos,1.);
	d = de_fractal(p) - SURFACE_SOFTEN_R;
#endif
#if ENABLE_SPORE_PLANTS
	d = smoothmin(d, sporePlantField(pos), 0.16);
#endif
#if ENABLE_VINES
	// tight k so only the root bulb ↔ terrain contact gets softened,
	// not a meter-wide foggy band. Rest of terrain stays crisp.
	d = smoothmin(d, vineField(pos), 1.2);
#endif
#if ENABLE_ARCH
	// Hard union — architecture is rigid, no terrain blending.
	d = min(d, apolloArchField(pos));
#endif
#if ENABLE_SKYBULBS
	d = min(d, skybulbField(pos));
#endif
	return d;
}

vec4 col_scene(vec3 pos)
{
	vec4 p = vec4(pos,1.);
	vec4 info = col_fractal(p);
	return vec4(alienTerrainAlbedo(pos, info), 0.0);
}

vec4 calcNormal(vec3 p, float dx) {
	const vec3 k = vec3(1,-1,0);
	return   (k.xyyx*DE(p + k.xyy*dx) +
			 k.yyxx*DE(p + k.yyx*dx) +
			 k.yxyx*DE(p + k.yxy*dx) +
			 k.xxxx*DE(p + k.xxx*dx))/vec4(4.*dx,4.*dx,4.*dx,4.);
}

void scene_material(vec3 pos, inout vec4 color, inout vec2 pbr)
{
	//DE_count = DE_count+1;
	vec4 p = vec4(pos,1.);
	vec4 info = col_fractal(p);
	vec3 albedo = alienTerrainAlbedo(pos, info);

	color = vec4(albedo, 1.);

	float wetGrowth = smoothstep(0.30, 0.90, dot(info.xyz, vec3(0.45, 0.35, 0.20))*0.20);
	float boneMask = boneExposureMask(pos, info);
	float roughness = mix(0.66, 0.45, wetGrowth);
	roughness = mix(roughness, 0.82, boneMask*0.30);
#if ENABLE_MICROBIAL_MAT
	float matMask = microbialMatMask(pos, info, boneMask);
	roughness = mix(roughness, 0.42, matMask*0.58);
#endif
#if ENABLE_SKYBULBS
	float skybulbShell = 1.0 - smoothstep(0.0, 0.08, skybulbField(pos));
	roughness = mix(roughness, 0.26, skybulbShell*0.92);
#endif
#if ENABLE_SPORE_PLANTS
	float sporePlantShell = 1.0 - smoothstep(0.0, 0.10, sporePlantField(pos));
	roughness = mix(roughness, 0.34, sporePlantShell*0.88);
#endif
	pbr = vec2(PBR_METALLIC, roughness);
	float reflection = 0.;

	color = vec4(min(color.xyz,1.), reflection);
}


#define overrelax 1.35

void ray_march(inout vec4 p, inout vec4 ray, inout vec4 var, float angle, float max_d)
{
    float prev_h = 0., td = 0.;
    float omega = overrelax;
    float candidate_td = 1.;
    float candidate_error = 1e8;
    for(; ((ray.w+td) < max_d) && (var.x < MAX_MARCHES);   var.x+= 1.)
    {
        p.w = DE(p.xyz + td*ray.xyz);

        if(prev_h*omega>max(p.w,0.)+max(prev_h,0.)) //if overtepped
        {
            td += (1.-omega)*prev_h; // step back to the safe distance
            prev_h = 0.;
            omega = (omega - 1.)*0.6 + 1.; //make the overstepping smaller
        }
        else
        {
			if(p.w < 0.)
			{
				candidate_error = 0.;
				candidate_td = td;
				break;
			}

            if(p.w/td < candidate_error)
            {
                candidate_error = p.w/td;
                candidate_td = td;

                if(p.w < (ray.w+td)*angle) //if closer to the surface than the cone radius
                {
                    break;
                }
            }

            td += p.w*omega; //continue marching

            prev_h = p.w;
        }
    }

    ray.w += candidate_td;
	p.xyz = p.xyz + candidate_td*ray.xyz;
	p.w = candidate_error*candidate_td;
}


void ray_march(inout vec4 p, inout vec4 ray, inout vec4 var, float angle)
{
	ray_march(p, ray, var, angle, MAX_DIST);
}



#define shadow_steps 128
float shadow_march(vec4 pos, vec4 dir, float distance2light, float light_angle)
{
	float light_visibility = 1.;
	float ph = 1e5;
	float dDEdt = 0.;
	pos.w = DE(pos.xyz);
	int i = 0;
	for (; i < shadow_steps; i++) {

		dir.w += pos.w;
		pos.xyz += pos.w*dir.xyz;
		pos.w = DE(pos.xyz);

		float y = pos.w*pos.w/(2.0*ph);
        float d = (pos.w+ph)*0.5*(1.-dDEdt);
		float angle = d/(max(MIN_DIST,dir.w-y)*light_angle);

        light_visibility = min(light_visibility, angle);

		//minimizing banding even further
		dDEdt = dDEdt*0.75 + 0.25*(pos.w-ph)/ph;

		ph = pos.w;

		if(dir.w >= distance2light)
		{
			break;
		}

		if(dir.w > MAX_DIST || pos.w < max(LOD*dir.w, MIN_DIST))
		{
			return 0.;
		}
	}

	if(i >= shadow_steps)
	{
		light_visibility=0.;
	}
	//return light_visibility; //bad
	light_visibility = clamp(2.*light_visibility - 1.,-1.,1.);
	return  0.5 + (light_visibility*sqrt(1.-light_visibility*light_visibility) + asin(light_visibility))/3.14159265; //looks better and is more physically accurate(for a circular light source)
}


#define AMBIENT_MARCHES 3
#define AMBIENT_COLOR 2*vec4(1,1,1,1)


///PBR functions
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}
///END PBR functions

const float Br = 0.0025;
const float Bm = 0.0003;
const float g =  0.9800;
const vec3 nitrogen = vec3(0.650, 0.570, 0.475);
const vec3 Kr = Br / pow(nitrogen, vec3(4.0));
const vec3 Km = Bm / pow(nitrogen, vec3(0.84));

vec3 sky_color(in vec3 pos)
{
	// Atmosphere Scattering
	vec3 fsun = LIGHT_DIRECTION;
	float brightnees = exp(-sqrt(pow(abs(min(5.*(pos.y-0.1),0.)),2.)+0.1));
	if(pos.y < 0.)
	{
		pos.y = 0.;
		pos.xyz = normalize(pos.xyz);
	}
    float mu = dot(normalize(pos), normalize(fsun));

	vec3 extinction = mix(exp(-exp(-((pos.y + fsun.y * 4.0) * (exp(-pos.y * 16.0) + 0.1) / 80.0) / Br) * (exp(-pos.y * 16.0) + 0.1) * Kr / Br) * exp(-pos.y * exp(-pos.y * 8.0 ) * 4.0) * exp(-pos.y * 2.0) * 4.0, vec3(1.0 - exp(fsun.y)) * 0.2, -fsun.y * 0.2 + 0.5);
	vec3 sky_col = brightnees* 3.0 / (8.0 * 3.14) * (1.0 + mu * mu) * (Kr + Km * (1.0 - g * g) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5)) / (Br + Bm) * extinction;
	sky_col = 0.4*clamp(sky_col,0.,10.);
	return pow(sky_col,vec3(1./gamma_sky));
}

vec3 ambient_sky_color(in vec3 pos)
{
	float y = pos.y;
	pos.xyz = normalize(vec3(1,0,0));
	return sky_color(pos)*exp(-abs(y));
}

vec4 ambient_occlusion(in vec4 pos, in vec4 norm, in vec4 dir)
{
	vec3 pos0 = pos.xyz;

	float occlusion_angle = 0.;
	vec3 direction = normalize(norm.xyz);
	vec3 ambient_color = ambient_sky_color(norm.xyz);
	//step out
	pos.xyz += 0.02*dir.w*direction;
	//march in the direction of the normal
	for(int i = 0; i < AMBIENT_MARCHES; i++)
	{
		pos.xyz += pos.w*direction;
		pos.w = DE(pos.xyz);

		norm.w = length(pos0 - pos.xyz);
		occlusion_angle += clamp(pos.w/norm.w,0.,1.);
	}

	occlusion_angle /= float(AMBIENT_MARCHES); // average weighted by importance
	return vec4(ambient_color,1.)*(0.5-cos(3.14159265*occlusion_angle)*0.5);
}


vec3 refraction(vec3 rd, vec3 n, float p) {
	float dot_nd = dot(rd, n);
	return p * (rd - dot_nd * n) + sqrt(1.0 - (p * p) * (1.0 - dot_nd * dot_nd)) * n;
}

vec3 lighting(vec4 color, vec2 pbr, vec4 pos, vec4 dir, vec4 norm, vec3 refl, vec3 refr, float shadow)
{
	vec3 albedo = color.xyz;
	albedo = pow(albedo,vec3(1./gamma_material)); //square it to make the fractals more colorfull

	vec4 ambient_color = ambient_occlusion(pos, norm, dir);

	float metallic = pbr.x;
	vec3 F0 = vec3(0.04);
	F0 = mix(F0, albedo, metallic);

	//reflectance equation
	vec3 Lo = vec3(0.0);
	vec3 V = -dir.xyz;
	vec3 N = norm.xyz;

	{ //ambient occlusion contribution
		float roughness = max(pbr.y,0.5);
		vec3 L = normalize(N);
		vec3 H = normalize(V + L);
		vec3 radiance = ambient_color.xyz;

		// cook-torrance brdf
		float NDF = DistributionGGX(N, H, roughness);
		float G   = GeometrySmith(N, V, L, roughness);
		vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);

		vec3 kS = F;
		vec3 kD = vec3(1.0) - kS;
		kD *= 1.0 - metallic;

		vec3 numerator    = NDF * G * F;
		float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
		vec3 specular     = numerator / max(denominator, 0.001);

		// add to outgoing radiance Lo
		float NdotL = max(dot(N, L), 0.0);
		Lo += (kD * albedo / PI + specular) * radiance * NdotL;
	}

	if(!SHADOWS_ENABLED)
	{
		shadow = ambient_color.w;
	}

	vec3 sun_color = sky_color(LIGHT_DIRECTION);

	{ //light contribution
		float roughness = pbr.y;
		vec3 L = normalize(LIGHT_DIRECTION);
		vec3 H = normalize(V + L);
		vec3 radiance = sun_color*shadow*(0.8+0.2*ambient_color.w);

		// cook-torrance brdf
		float NDF = DistributionGGX(N, H, roughness);
		float G   = GeometrySmith(N, V, L, roughness);
		vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);

		vec3 kS = F;
		vec3 kD = vec3(1.0) - kS;
		kD *= 1.0 - metallic;

		vec3 numerator    = NDF * G * F;
		float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
		vec3 specular     = numerator / max(denominator, 0.001);

		// add to outgoing radiance Lo
		float NdotL = max(dot(N, L), 0.0);
		Lo += (kD * albedo / PI + specular) * radiance * NdotL;
	}

	{ //light reflection, GI imitation
		float roughness = max(PBR_ROUGHNESS,0.8);
		vec3 L = normalize(-LIGHT_DIRECTION);
		vec3 H = normalize(V + L);
		vec3 radiance = 0.5*sun_color*ambient_color.w*(1.-ambient_color.w);

		// cook-torrance brdf
		float NDF = DistributionGGX(N, H, roughness);
		float G   = GeometrySmith(N, V, L, roughness);
		vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);

		vec3 kS = F;
		vec3 kD = vec3(1.0) - kS;
		kD *= 1.0 - metallic;

		vec3 numerator    = NDF * G * F;
		float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
		vec3 specular     = numerator / max(denominator, 0.001);

		// add to outgoing radiance Lo
		float NdotL = max(dot(N, L), 0.0);
		Lo += (kD * albedo / PI + specular) * radiance * NdotL;
	}

	if(color.w>0.5) // if metal
	{
		vec3 n = normalize(norm.xyz);
		vec3 q = dir.xyz - n*(2.*dot(dir.xyz,n));

        //metal
        vec3 F0 = vec3(0.6);
        vec3 L = normalize(q);
        vec3 H = normalize(V + L);
        vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        Lo += kS*refl;
	}

	return Lo;
}

vec3 shading_simple(in vec4 pos, in vec4 dir, float fov, float shadow)
{
	if(pos.w < max(1.*fov*dir.w, MIN_DIST))
	{
		//calculate the normal
		float error = 0.5*fov*dir.w;
		vec4 norm = calcNormal(pos.xyz, max(MIN_DIST, error));
		norm.xyz = normalize(norm.xyz);
		if(norm.w < -error)
		{
			return COL(pos.xyz).xyz;
		}
		else
		{
			//optimize color sampling
			vec3 cpos = pos.xyz - pos.w*norm.xyz;
			//cpos = cpos - DE(cpos)*norm.xyz;
			//cpos = cpos - DE(cpos)*norm.xyz;

			vec4 color; vec2 pbr;
			scene_material(cpos, color, pbr);
			return lighting(color, pbr, pos, dir, norm, vec3(0), vec3(0), shadow);
		}
	}
	else
	{
		return sky_color(dir.xyz);
	}
}


// Distance fog, only active beyond FOG_START. Near scene untouched;
// far hits melt into sky to hide sub-pixel shimmer from stacked
// terrain + bulb detail.
#define FOG_START 100.0
#define FOG_K 0.006

vec3 render_ray(in vec4 pos, in vec4 dir, float fov)
{
	vec4 var = vec4(0,0,0,1);
	ray_march(pos, dir, var, fov);
    vec4 spos = vec4(pos.xyz, pos.w);
	float shadow = shadow_march(spos, vec4(LIGHT_DIRECTION,0.), 5., LIGHT_ANGLE);
	vec3 col = shading_simple(pos, dir, fov, shadow);

	float fog = 1.0 - exp(-max(dir.w - FOG_START, 0.0) * FOG_K);
	return mix(col, sky_color(dir.xyz), fog);
}

vec3 ACESFilm(vec3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return (x*(a*x+b))/(x*(c*x+d)+e);
}

vec3 HDRmapping(vec3 color, float exposure)
{
	// Exposure tone mapping
    vec3 mapped = ACESFilm(color * exposure);
    // Gamma correction
    return pow(mapped, vec3(1.0 / gamma_camera));
}


mat3 getCamera(vec2 angles)
{
   mat3 theta_rot = mat3(1,   0,              0,
                          0,   cos(angles.y),  sin(angles.y),
                          0,  -sin(angles.y),  cos(angles.y));

   mat3 phi_rot = mat3(cos(angles.x),   sin(angles.x), 0.,
        		       -sin(angles.x),   cos(angles.x), 0.,
        		        0.,              0.,            1.);

   return theta_rot*phi_rot;
}

vec3 getRay(vec2 angles, vec2 pos)
{
    mat3 camera = getCamera(angles);
    return normalize(transpose(camera)*vec3(FOV*pos.x, 1., FOV*pos.y));
}

vec3 getRayFov(vec2 angles, vec2 pos, float fov)
{
    mat3 camera = getCamera(angles);
    return normalize(transpose(camera)*vec3(fov*pos.x, 1., fov*pos.y));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized centered pixel coordinates
    vec2 pos = (fragCoord - iResolution.xy*0.5)/max(iResolution.x,iResolution.y);

    LOD = 1.5/max(iResolution.x,iResolution.y);
    vec2 angles = vec2(2.*PI, PI)*(iMouse.xy/iResolution.xy - 0.5);
    float zoom = clamp(uZoom, 0.0, 1.0);

    if(iMouse.z < 1.)
    {
        angles = vec2(PI/5., -0.08);
    }
    float viewFov = mix(2.70, 1.05, smoothstep(0.0, 1.0, zoom));
    vec3 ray = getRayFov(angles, pos, viewFov);
    vec4 cpos = vec4(uCameraOrigin, 1.);
    vec4 dir = vec4(normalize(ray.xzy),0.);

#if ENABLE_BASE_TERRAIN
   	float de = de_fractal(cpos);
    cpos.y -= de*0.98;
#endif

    // DEBUG toggle: 1 = visualize DE at camera, 0 = normal render
    //   red = inside geometry | green = near surface | blue = far
    #define DEBUG_CAMERA_DE 0

    vec3 col;
    #if DEBUG_CAMERA_DE
        float deCam = DE(cpos.xyz);
        if (deCam < 0.0)      col = vec3(1.0, 0.0, 0.0);
        else if (deCam < 1.0) col = vec3(0.0, deCam, 0.0);
        else                  col = vec3(0.0, 0.0, clamp(deCam*0.1, 0.0, 1.0));
        fragColor = vec4(col, 1.0);
    #else
        col = render_ray(cpos, dir, LOD);
        fragColor = vec4(HDRmapping(col, 0.5), 1.0);
    #endif
}

void main() {
  mainImage(gl_FragColor, gl_FragCoord.xy);
}
