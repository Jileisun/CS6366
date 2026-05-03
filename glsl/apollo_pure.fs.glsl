// apollo_pure.fs.glsl
// Reference Apollonian fractal shader, adapted from the provided reference.
// This variant uses a bright tree-like triplanar surface.

precision highp float;

uniform vec3  iResolution;
uniform float iTime;
uniform vec4  iMouse;
uniform float uApolloScale;
uniform float uApolloIterations;
uniform float uApolloInset;
uniform float uApolloInversion;
uniform float uApolloOrbitRadius;
uniform float uApolloOrbitSpeed;
uniform float uApolloGain;

varying vec2 vUv;

// ---- reference map() ------------------------------------------------
vec3 map_apollo( vec3 p )
{
    p *= uApolloScale;
    float scale = 1.0;
    float orb = 10000.0;

    for( int i=0; i<12; i++ )
    {
        if( float(i) >= uApolloIterations ) break;
        p = -1.0 + 2.0*fract(0.5*p+0.5);
        p -= sign(p)*uApolloInset;
        float r2 = dot(p,p);
        float k = uApolloInversion/max(r2, 0.04);
        p     *= k;
        scale *= k;
        orb    = min( orb, r2 );
    }

    float d1 = sqrt( min( min( dot(p.xy,p.xy), dot(p.yz,p.yz) ), dot(p.zx,p.zx) ) ) - 0.02;
    float d2 = abs(p.y);
    float dmi = d2;
    float adr = 0.7*floor((0.5*p.y+0.5)*8.0);
    if( d1<d2 ) { dmi = d1; adr = 0.0; }
    return vec3( 0.5*dmi/(scale*uApolloScale), adr, orb );
}

// ---- raymarch -------------------------------------------------------
vec3 trace( in vec3 ro, in vec3 rd )
{
    float maxd = 20.0;
    float t = 0.01;
    vec2  info = vec2(0.0);
    for( int i=0; i<256; i++ )
    {
        float precis = 0.001*t;
        vec3  r = map_apollo( ro+rd*t );
        float h = r.x;
        info = r.yz;
        if( h<precis || t>maxd ) break;
        t += h;
    }
    if( t>maxd ) t=-1.0;
    return vec3( t, info );
}

vec3 calcNormal( in vec3 pos, in float t )
{
    float precis = 0.0001 * t * 0.57;
    vec2 e = vec2(1.0,-1.0)*precis;
    return normalize(
        e.xyy*map_apollo( pos + e.xyy ).x +
        e.yyx*map_apollo( pos + e.yyx ).x +
        e.yxy*map_apollo( pos + e.yxy ).x +
        e.xxx*map_apollo( pos + e.xxx ).x );
}

// ---- AO (reference forwardSF hemisphere) ----------------------------
vec3 forwardSF( float i, float n )
{
    const float PI  = 3.141592653589793238;
    const float PHI = 1.618033988749894848;
    float phi = 2.0*PI*fract(i/PHI);
    float zi  = 1.0 - (2.0*i+1.0)/n;
    float sinT = sqrt(1.0 - zi*zi);
    return vec3( cos(phi)*sinT, sin(phi)*sinT, zi );
}

float calcAO( in vec3 pos, in vec3 nor )
{
    float ao = 0.0;
    for( int i=0; i<16; i++ )
    {
        vec3 w = forwardSF( float(i), 16.0 );
        w *= sign( dot(w,nor) );
        float h = float(i)/15.0;
        ao += clamp( map_apollo( pos + nor*0.01 + w*h*0.15 ).x*2.0, 0.0, 1.0 );
    }
    ao /= 16.0;
    return clamp( ao*16.0, 0.0, 1.0 );
}

// ---- procedural plant texture ---------------------------------------
float hash12( in vec2 p )
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise2( in vec2 p )
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f*f*(3.0 - 2.0*f);

    return mix(
        mix(hash12(i + vec2(0.0, 0.0)), hash12(i + vec2(1.0, 0.0)), u.x),
        mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm2( in vec2 p )
{
    float f = 0.0;
    float a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for( int i=0; i<5; i++ )
    {
        f += a * noise2(p);
        p = m * p;
        a *= 0.55;
    }
    return f;
}

vec3 plantTexture2D( in vec2 uv, in float band, in float upMask )
{
    vec2 p = uv * 2.4;
    float barkMask = fbm2(p * 1.4);
    float leafMask = fbm2(p * 2.8 + vec2(4.0, 1.7));
    float blossom = fbm2(p * 7.0 + vec2(2.3, 6.1));
    float ribs = abs(sin(p.x * 2.8 + 2.2 * fbm2(p * 0.9)) * cos(p.y * 2.0 - 1.8 * fbm2(p * 1.4)));
    float vein = 1.0 - smoothstep(0.18, 0.72, ribs);
    float crest = 0.5 + 0.5*cos(6.2831*band + 2.0*barkMask);

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

vec3 plantTextureBox( in vec3 pos, in vec3 nor, in float band )
{
    vec3 w = abs(nor);
    w = w*w*w;
    w /= (w.x + w.y + w.z + 1e-4);

    float upX = smoothstep(-0.15, 0.65, nor.x);
    float upY = smoothstep(-0.15, 0.65, nor.y);
    float upZ = smoothstep(-0.15, 0.65, nor.z);

    vec3 txX = plantTexture2D(pos.yz, band, upX);
    vec3 txY = plantTexture2D(pos.zx, band + 0.17, upY);
    vec3 txZ = plantTexture2D(pos.xy, band + 0.31, upZ);

    return (w.x * txX + w.y * txY + w.z * txZ) / (w.x + w.y + w.z);
}

// ---- render ----------------------------------------------------------
vec3 render( in vec3 ro, in vec3 rd )
{
    vec3 col = vec3(0.0);
    vec3 res = trace( ro, rd );
    float t  = res.x;
    if( t>0.0 )
    {
        vec3  pos = ro + t*rd;
        vec3  nor = calcNormal( pos, t );
        float fre = clamp(1.0+dot(rd,nor), 0.0, 1.0);
        float occ = pow( clamp(res.z*2.0,0.0,1.0), 1.2 );
              occ = 1.5*(0.1+0.9*occ)*calcAO(pos,nor);
        vec3  lin = vec3(1.05,1.08,1.30)*(2.35+fre*fre*vec3(1.9,1.1,1.0))*occ*(1.0-0.4*abs(nor.y));

        vec3 bandCol = 0.5 + 0.5*cos( 6.2831*res.y + vec3(0.0,1.0,2.0) );
        vec3 plantCol = plantTextureBox( pos, nor, res.y );
        vec3 baseCol = mix(0.22 * bandCol + vec3(0.10, 0.08, 0.04), plantCol, 0.88);
        col  = baseCol * lin;
        col += 0.36*pow(1.0-fre,24.0)*occ*vec3(0.78,0.96,0.54);
        col += 0.08 * vec3(0.24, 0.34, 0.12) * occ;
        col *= exp(-0.22*t);
    }
    col.z += 0.01;
    return sqrt(col * uApolloGain);
}

// ---- main (Shadertoy mainImage → Three.js main) ---------------------
void main()
{
    float mouseActive = step(0.5, dot(iMouse.xy, iMouse.xy));
    vec2 mouse = mix(0.5 * iResolution.xy, iMouse.xy, mouseActive);
    vec2 mouseN = mouse / max(iResolution.xy, vec2(1.0));

    float autoOrbit = 0.85 * iTime * uApolloOrbitSpeed;
    float dragOrbit = (mouseN.x - 0.5) * 2.4;
    float orbit = autoOrbit + dragOrbit;

    float autoLift = 0.22 * cos(0.31 * iTime * max(uApolloOrbitSpeed, 0.25));
    float dragLift = (0.5 - mouseN.y) * 0.85;
    float lift = autoLift + dragLift;

    vec2 fragCoord = vUv * iResolution.xy;

    vec3 ro = vec3(
        uApolloOrbitRadius*cos(0.1 + 0.33*orbit),
        0.55 + 0.28*lift,
        uApolloOrbitRadius*cos(0.5 + 0.35*orbit)
    );
    vec3 ta = vec3(
        1.9*cos(1.2 + 0.41*orbit),
        0.5 + 0.18*lift,
        1.9*cos(2.0 + 0.38*orbit)
    );
    float roll = 0.0;

    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(roll), cos(roll), 0.0);
    vec3 cu = normalize(cross(cw,cp));
    vec3 cv = normalize(cross(cu,cw));

    vec2 p  = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    vec3 rd = normalize( p.x*cu + p.y*cv + 2.0*cw );

    gl_FragColor = vec4( render(ro,rd), 1.0 );
}
