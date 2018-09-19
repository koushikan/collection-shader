#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
 precision highp float;
 #else
 precision mediump float;
#endif
#define SHADER_NAME Environment
varying vec3 vLocalVertex;

// common stuffs
uniform int uOutputLinear;
uniform float uRGBMRange;

uniform float uEnvironmentExposure;
uniform float uBackgroundExposure;

uniform vec3 uDiffuseSPH[9];
uniform samplerCube uTexture0;
uniform float uSize;
uniform int uAmbient;

uniform float uFrameModTaaSS;

// approximation such as http://chilliant.blogspot.fr/2012/08/srgb-approximations-for-hlsl.html
// introduced slightly darker colors and more slight banding in the darks.

// so we stick with the reference implementation (except we don't check if color >= 0.0):
// https://www.khronos.org/registry/gles/extensions/EXT/EXT_sRGB.txt
#define LIN_SRGB(x) x < 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1.0/2.4) - 0.055
#define SRGB_LIN(x) x < 0.04045 ? x * (1.0 / 12.92) : pow((x + 0.055) * (1.0 / 1.055), 2.4)

//#pragma DECLARE_FUNCTION
float linearTosRGB(const in float color) { return LIN_SRGB(color); }

//#pragma DECLARE_FUNCTION
vec3 linearTosRGB(const in vec3 color) { return vec3(LIN_SRGB(color.r), LIN_SRGB(color.g), LIN_SRGB(color.b)); }

//#pragma DECLARE_FUNCTION
vec4 linearTosRGB(const in vec4 color) { return vec4(LIN_SRGB(color.r), LIN_SRGB(color.g), LIN_SRGB(color.b), color.a); }

//#pragma DECLARE_FUNCTION NODE_NAME:sRGBToLinear
float sRGBToLinear(const in float color) { return SRGB_LIN(color); }

//#pragma DECLARE_FUNCTION NODE_NAME:sRGBToLinear
vec3 sRGBToLinear(const in vec3 color) { return vec3(SRGB_LIN(color.r), SRGB_LIN(color.g), SRGB_LIN(color.b)); }

//#pragma DECLARE_FUNCTION NODE_NAME:sRGBToLinear
vec4 sRGBToLinear(const in vec4 color) { return vec4(SRGB_LIN(color.r), SRGB_LIN(color.g), SRGB_LIN(color.b), color.a); }

//http://graphicrants.blogspot.fr/2009/04/rgbm-color-encoding.html
vec3 RGBMToRGB( const in vec4 rgba ) {
    const float maxRange = 8.0;
    return rgba.rgb * maxRange * rgba.a;
}

const mat3 LUVInverse = mat3( 6.0013, -2.700, -1.7995, -1.332, 3.1029, -5.7720, 0.3007, -1.088, 5.6268 );

vec3 LUVToRGB( const in vec4 vLogLuv ) {
    float Le = vLogLuv.z * 255.0 + vLogLuv.w;
    vec3 Xp_Y_XYZp;
    Xp_Y_XYZp.y = exp2((Le - 127.0) / 2.0);
    Xp_Y_XYZp.z = Xp_Y_XYZp.y / vLogLuv.y;
    Xp_Y_XYZp.x = vLogLuv.x * Xp_Y_XYZp.z;
    vec3 vRGB = LUVInverse * Xp_Y_XYZp;
    return max(vRGB, 0.0);
}

// http://graphicrants.blogspot.fr/2009/04/rgbm-color-encoding.html
//#pragma DECLARE_FUNCTION
vec4 encodeRGBM(const in vec3 color, const in float range) {
    if(range <= 0.0) return vec4(color, 1.0);
    vec4 rgbm;
    vec3 col = color / range;
    rgbm.a = clamp( max( max( col.r, col.g ), max( col.b, 1e-6 ) ), 0.0, 1.0 );
    rgbm.a = ceil( rgbm.a * 255.0 ) / 255.0;
    rgbm.rgb = col / rgbm.a;
    return rgbm;
}

//#pragma DECLARE_FUNCTION
vec3 decodeRGBM(const in vec4 color, const in float range) {
    if(range <= 0.0) return color.rgb;
    return range * color.rgb * color.a;
}

// https://twitter.com/pyalot/status/711956736639418369
// https://github.com/mrdoob/three.js/issues/10331
//#pragma DECLARE_FUNCTION NODE_NAME:FrontNormal
#define _frontNormal(normal) gl_FrontFacing ? normal : -normal

//#pragma DECLARE_FUNCTION NODE_NAME:Normalize
#define _normalize(vec) normalize(vec)

//#pragma DECLARE_FUNCTION
vec4 preMultAlpha(const in vec3 color, const in float alpha) { return vec4(color.rgb * alpha, alpha); }

//#pragma DECLARE_FUNCTION
vec4 preMultAlpha(const in vec4 color) { return vec4(color.rgb * color.a, color.a); }

//#pragma DECLARE_FUNCTION
vec4 setAlpha(const in vec3 color, const in float alpha) { return vec4(color, alpha); }

//#pragma DECLARE_FUNCTION
vec4 setAlpha(const in vec3 color, const in vec4 alpha) { return vec4(color, alpha.a); }



vec3 cubemapSeamlessFixDirection(const in vec3 direction, const in float size ) {
    vec3 dir = direction;
    float scale = 1.0 - 1.0 / size;
    // http://seblagarde.wordpress.com/2012/06/10/amd-cubemapgen-for-physically-based-rendering/
    vec3 absDir = abs(dir);
    float M = max(max(absDir.x, absDir.y), absDir.z);

    if (absDir.x != M) dir.x *= scale;
    if (absDir.y != M) dir.y *= scale;
    if (absDir.z != M) dir.z *= scale;

    return dir;
}

// seamless cubemap for background ( no lod )
vec3 textureCubeFixed(const in samplerCube tex, const in vec3 direction, const in float scale ) {
    // http://seblagarde.wordpress.com/2012/06/10/amd-cubemapgen-for-physically-based-rendering/
    vec3 dir = cubemapSeamlessFixDirection( direction, scale);
    return LUVToRGB( textureCube( tex, dir ) );
}

//#pragma DECLARE_FUNCTION
vec3 textureEnvironmentCube( const in samplerCube tex, const in mat3 envTransform, const in vec3 normal, const in vec3 eyeVector, const in vec2 texSize){
    vec3 R = normalize((2.0 * clamp(dot(normal, eyeVector), 0.0, 1.0)) * normal - eyeVector);
    return textureCubeFixed(tex, envTransform * R, texSize[0] );
}

#ifndef TEX_BUMP
#define TEX_BUMP(tex, uv) 1.0
#endif

// Todo use #idfef and derivatives (dDFx, dDFy, fwidth) extension ?
// float valuetexture2D(tex, uv);
// return vec2(dFdx(value), dFdy(value));
//#pragma DECLARE_FUNCTION
vec2 textureGradient(in sampler2D tex, const in vec2 uv, const in vec2 texSize) {
    vec2 invSize = 1.0 / texSize;
    float dx = TEX_BUMP(tex, uv - vec2(invSize.x, 0.0)) - TEX_BUMP(tex, uv + vec2(invSize.x, 0.0));
    float dy = TEX_BUMP(tex, uv - vec2(0.0, invSize.y)) - TEX_BUMP(tex, uv + vec2(0.0, invSize.y));
    return vec2(dx, dy);
}


// white vs interleaved vs blue noise
// https://blog.demofox.org/2017/10/31/animating-noise-for-integration-over-time/

// to test in a shadertoy
// https://www.shadertoy.com/view/lsdfD4

// https://www.shadertoy.com/view/4djSRW
// most combinations are possible : in[1,2,3] -> out[1,2,3]
#define INT_SCALE1 .1031
float pseudoRandom(const in vec2 fragCoord) {
    vec3 p3  = fract(vec3(fragCoord.xyx) * INT_SCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

// https://github.com/EpicGames/UnrealEngine/blob/release/Engine/Shaders/Private/Random.ush#L27
float interleavedGradientNoise(const in vec2 fragCoord, const in float frameMod) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(fragCoord.xy + frameMod * vec2(47.0, 17.0) * 0.695, magic.xy)));
}

// https://github.com/EpicGames/UnrealEngine/blob/release/Engine/Shaders/Private/MaterialTemplate.ush#L1863
// we slighty change it by multiplying by 1.2 (to match with other noise), otherwise the range seems to be between [0 - 0.83]
float ditheringNoise(const in vec2 fragCoord, const in float frameMod) {
    // float fm = mod(frameMod, 2.0) == 0.0 ? 1.0 : -1.0;
    float fm = frameMod;
    float dither5 = fract((fragCoord.x + fragCoord.y * 2.0 - 1.5 + fm) / 5.0);
    float noise = fract(dot(vec2(171.0, 231.0) / 71.0, fragCoord.xy));
    return (dither5 * 5.0 + noise) * (1.2 / 6.0);
}

//#pragma DECLARE_FUNCTION
void ditheringMaskingDiscard(
    const in vec4 fragCoord,
    const in int dithering,
    const in float alpha,
    const in float factor,

    const in float thinLayer,

    const in float frameMod,
    const in vec2 nearFar,

    const in vec4 halton) {

    if (dithering != 1) {
        if (alpha < factor) discard;
        return;
    }

    float rnd;

    if (thinLayer == 0.0) {
        float linZ = (1.0 / fragCoord.w - nearFar.x) / (nearFar.y - nearFar.x);
        float sliceZ = floor(linZ * 500.0) / 500.0;
        rnd = interleavedGradientNoise(fragCoord.xy + sliceZ, frameMod);
    } else {
        rnd = pseudoRandom(fragCoord.xy + halton.xy * 1000.0 + fragCoord.z * (abs(halton.z) == 2.0 ? 1000.0 : 1.0));
    }

    if (alpha * factor < rnd) discard;
}


// sph env
vec3 evaluateDiffuseSphericalHarmonics(const in vec3 s[9], const in vec3 n) {
    // https://github.com/cedricpinson/envtools/blob/master/Cubemap.cpp#L523
    vec3 result = (s[0]+s[1]*n.y+s[2]*n.z+s[3]*n.x+s[4]*n.y*n.x+s[5]*n.y*n.z+s[6]*(3.0*n.z*n.z-1.0)+s[7]*(n.z*n.x)+s[8]*(n.x*n.x-n.y*n.y));
    return max(result, vec3(0.0));
}

void main(void) {

    vec3 color;
    if (uAmbient == 1) {
        vec3 normal = normalize(vLocalVertex + mix(-0.5/255.0, 0.5/255.0, pseudoRandom(gl_FragCoord.xy))*2.0);
        // vec3 normal = normalize(vLocalVertex + (interleavedGradientNoise(gl_FragCoord.xy, uFrameModTaaSS) - 0.5) * 0.4);
        color = evaluateDiffuseSphericalHarmonics(uDiffuseSPH, normal);
    } else {
        color = textureCubeFixed(uTexture0, normalize(vLocalVertex), uSize);
    }

    color *= uEnvironmentExposure * uBackgroundExposure;

    if (uOutputLinear == 0 ) color = linearTosRGB(color);

    gl_FragColor = encodeRGBM(color, uRGBMRange);
}
