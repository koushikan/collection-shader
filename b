#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
 precision highp float;
 #else
 precision mediump float;
#endif
#define SHADER_NAME Hotspot
attribute vec2 TexCoord0;
attribute vec3 Vertex;

varying vec2 vTexCoord0;
varying vec4 vViewPos;

uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;

uniform float uHotspotIndex;

// icon size 48 pixel width and 2 pixel padding between them
const vec2 ICON_SIZE = 48.0 / vec2(512.0, -256.0);
const vec2 ICON_AND_PADDING = ICON_SIZE + 2.0 / vec2(512.0, -256.0);

void main(void) {
  vec2 offset = vec2(mod(uHotspotIndex, 10.0), floor(uHotspotIndex / 10.0));
  vTexCoord0 = vec2(TexCoord0.x, 1.0 - TexCoord0.y) * ICON_SIZE + offset * ICON_AND_PADDING;

  vViewPos = uModelViewMatrix * vec4(Vertex.xyz, 1.0);
  gl_Position = uProjectionMatrix * vViewPos;
}








#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
 precision highp float;
 #else
 precision mediump float;
#endif
#define SHADER_NAME Hotspot
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


#define _linTest(color, keepLinear) { return keepLinear == 1 ? color : linearTosRGB(color); }

//#pragma DECLARE_FUNCTION
float linearTosRGBWithTest(const in float color, const in int keepLinear) _linTest(color, keepLinear)

//#pragma DECLARE_FUNCTION
vec3 linearTosRGBWithTest(const in vec3 color, const in int keepLinear) _linTest(color, keepLinear)

//#pragma DECLARE_FUNCTION
vec4 linearTosRGBWithTest(const in vec4 color, const in int keepLinear) _linTest(color, keepLinear)

//#pragma DECLARE_FUNCTION
float adjustSpecular( const in float specular, const in vec3 normal ) {
    // Based on The Order : 1886 SIGGRAPH course notes implementation (page 21 notes)
    float normalLen = length(normal);
    if ( normalLen < 1.0) {
        float normalLen2 = normalLen * normalLen;
        float kappa = ( 3.0 * normalLen -  normalLen2 * normalLen )/( 1.0 - normalLen2 );
        // http://www.frostbite.com/2014/11/moving-frostbite-to-pbr/
        // page 91 : they use 0.5/kappa instead
        return 1.0-min(1.0, sqrt( (1.0-specular) * (1.0-specular) + 1.0/kappa ));
    }
    return specular;
}

//#pragma DECLARE_FUNCTION
vec3 normalTangentSpace(const in vec4 tangent, const in vec3 normal, const in vec3 texNormal) {
    vec3 tang = vec3(0.0,1.0,0.0);
    float l = length(tangent.xyz);
    if (l != 0.0) {
        //normalize reusing length computations
        // tang =  normalize(tangent.xyz);
        tang =  tangent.xyz / l;
    }
    vec3 B = tangent.w * normalize(cross(normal, tang));
    return normalize( texNormal.x * tang + texNormal.y * B + texNormal.z * normal);
}

//#pragma DECLARE_FUNCTION
vec2 normalMatcap(const in vec3 normal, const in vec3 eyeVector) {
    vec3 nm_x = vec3(-eyeVector.z, 0.0, eyeVector.x);
    vec3 nm_y = cross(nm_x, eyeVector);
    return vec2(dot(normal.xz, -nm_x.xz), dot(normal, nm_y)) * vec2(0.5)  + vec2(0.5);
}

//#pragma DECLARE_FUNCTION
vec3 textureNormalMap(const in vec3 normal, const in int flipY) {
    vec3 rgb = normal * vec3(2.0) + vec3(-1.0); // MADD vec form
    rgb[1] = flipY == 1 ? -rgb[1] : rgb[1];
    return rgb;
}

//#pragma DECLARE_FUNCTION
vec3 bumpMap(const in vec4 tangent, const in vec3 normal, const in vec2 gradient) {
    vec3 outnormal;
    float l = length(tangent.xyz);
    if (l != 0.0) {
        //normalize reusing length computations
        // vec3 tang =  normalize(tangent.xyz);
        vec3 tang =  tangent.xyz / l;
        vec3 binormal = tangent.w * normalize(cross(normal, tang));
        outnormal = normal + gradient.x * tang + gradient.y * binormal;
    }
    else {
       outnormal = vec3(normal.x + gradient.x, normal.y + gradient.y, normal.z);
    }
    return normalize(outnormal);
}

//#pragma DECLARE_FUNCTION
float checkerboard(const in vec2 uv, const in vec4 halton) {
    float taaSwap = step(halton.z, 0.0);
    return mod(taaSwap + floor(uv.x) + floor(uv.y), 2.0);
}

// random links on packing :
// cesium attributes packing
// https://cesiumjs.org/2015/05/18/Vertex-Compression/

// float packing in 24 bits or 32 bits
// https://skytiger.wordpress.com/2010/12/01/packing-depth-into-color/

//#pragma DECLARE_FUNCTION
vec4 encodeDepthAlphaProfileScatter(const in float depth, const in float alpha, const in float profile, const in float scatter) {
    vec4 pack = vec4(0.0);

    // opacity in alpha
    pack.a = alpha;

    if(profile == 0.0) {
        const vec3 code = vec3(1.0, 255.0, 65025.0);
        pack.rgb = vec3(code * depth);
        pack.gb = fract(pack.gb);
        pack.rg -= pack.gb * (1.0 / 256.0);
    } else {
        // depth in rg
        pack.g = fract(depth * 255.0);
        pack.r = depth - pack.g / 255.0;

        // scatter 6 bits
        pack.b = floor(0.5 + scatter * 63.0) * 4.0 / 255.0;
    }

    // profile on 2 lower bits
    pack.b -= mod(pack.b, 4.0 / 255.0);
    pack.b += profile / 255.0; // 3 profile possible for sss

    return pack;
}

int decodeProfile(const in vec4 pack) {
    float packValue = floor(pack.b * 255.0 + 0.5);
    // we extract the 2 lowest bits
    float profile = mod(packValue, 2.0);
    profile += mod(packValue - profile, 4.0);
    return int(profile);
}

float decodeDepth(const in vec4 pack) {
    if(decodeProfile(pack) == 0){
        const vec3 decode = 1.0 / vec3(1.0, 255.0, 65025.0);
        return dot(pack.rgb, decode);
    }

    return pack.r + pack.g / 255.0;
}

float decodeScatter(const in vec4 pack) {
    float scatter = pack.b - mod(pack.b, 4.0 / 255.0);
    return scatter * 255.0 / 4.0 / 63.0;
}

float decodeAlpha(const in vec4 pack) {
    return pack.a;
}

float getLuminance(const in vec3 color) {
    // http://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
    const vec3 colorBright = vec3(0.2126, 0.7152, 0.0722);
    return dot(color, colorBright);
}

float distanceToDepth(const in sampler2D depth, const in vec2 uv, const in vec4 viewPos, const vec2 nearFar) {
    float fragDepth = clamp( (-viewPos.z * viewPos.w - nearFar.x) / (nearFar.y - nearFar.x), 0.0, 1.0);
    return fragDepth - decodeDepth(texture2D(depth, uv));
}

vec3 encode24(const in float x){
    const vec3 code = vec3(1.0, 255.0, 65025.0);
    vec3 pack = vec3(code * x);
    pack.gb = fract(pack.gb);
    pack.rg -= pack.gb * (1.0 / 256.0);
    return pack;
}

float decode24(const in vec3 x) {
    const vec3 decode = 1.0 / vec3(1.0, 255.0, 65025.0);
    return dot(x, decode);
}

varying vec2 vTexCoord0;
varying vec4 vViewPos;

uniform sampler2D uTextureHotspot;
uniform vec3 uColor;

uniform sampler2D uTextureDepth;
uniform vec2 uGlobalTexSize;
uniform vec2 uGlobalTexRatio;
uniform vec2 uNearFar;

const float BIAS_VISIBILITY = 0.05;

void main(void) {
  float distDepth = distanceToDepth(uTextureDepth, uGlobalTexRatio * gl_FragCoord.xy / uGlobalTexSize, vViewPos, uNearFar);
  float alpha = distDepth < BIAS_VISIBILITY ? 1.0 : 0.1;

  gl_FragColor = vec4(uColor, 1.0) * texture2D(uTextureHotspot, vTexCoord0);
  gl_FragColor.a *= alpha;

  gl_FragColor.rgb *= gl_FragColor.a;
}
