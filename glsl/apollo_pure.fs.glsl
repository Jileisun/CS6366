// apollo_pure.fs.glsl
// Reference Apollonian fractal shader, adapted from the provided reference.
// Only change: iChannel0 wood texture replaced with a procedural equivalent.

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

// ---- procedural replacement for iChannel0 wood texture --------------
vec3 proceduralWood( in vec3 pos, in vec3 nor )
{
    vec3 w = nor*nor;
    w /= (w.x + w.y + w.z + 1e-4);
    // triplanar rings
    float rx = sin(length(pos.yz)*5.3 + pos.x*1.1);
    float ry = sin(length(pos.xz)*5.3 + pos.y*1.1);
    float rz = sin(length(pos.xy)*5.3 + pos.z*1.1);
    float v  = 0.5 + 0.4*(w.x*rx + w.y*ry + w.z*rz);
    return mix( vec3(0.54, 0.37, 0.19), vec3(0.88, 0.70, 0.44), v );
}

// ---- render (identical to reference, texture call replaced) ---------
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
        vec3  lin = vec3(1.0,1.0,1.5)*(2.0+fre*fre*vec3(1.8,1.0,1.0))*occ*(1.0-0.5*abs(nor.y));

        col  = 0.5 + 0.5*cos( 6.2831*res.y + vec3(0.0,1.0,2.0) );
        col *= proceduralWood( pos, nor );
        col  = col*lin;
        col += 0.6*pow(1.0-fre,32.0)*occ*vec3(0.5,1.0,1.5);
        col *= exp(-0.3*t);
    }
    col.z += 0.01;
    return sqrt(col * uApolloGain);
}

// ---- main (Shadertoy mainImage → Three.js main) ---------------------
void main()
{
    float time = iTime*0.15*uApolloOrbitSpeed + 0.005*iMouse.x;

    vec2 fragCoord = vUv * iResolution.xy;

    vec3 ro = vec3(
        uApolloOrbitRadius*cos(0.1+.33*time),
        0.5+0.20*cos(0.37*time),
        uApolloOrbitRadius*cos(0.5+0.35*time)
    );
    vec3 ta = vec3( 1.9*cos(1.2+.41*time), 0.5+0.10*cos(0.27*time), 1.9*cos(2.0+0.38*time) );
    float roll = 0.2*cos(0.1*time);

    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(roll), cos(roll), 0.0);
    vec3 cu = normalize(cross(cw,cp));
    vec3 cv = normalize(cross(cu,cw));

    vec2 p  = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    vec3 rd = normalize( p.x*cu + p.y*cv + 2.0*cw );

    gl_FragColor = vec4( render(ro,rd), 1.0 );
}
