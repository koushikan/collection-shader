#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
 precision highp float;
 #else
 precision mediump float;
#endif
#define SHADER_NAME Environment
attribute vec3 Vertex;
uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;

uniform vec4 uHalton;
uniform vec2 uGlobalTexSize;
uniform vec2 uGlobalTexRatio;

varying vec3 vLocalVertex;

void main(void)
{
    vLocalVertex = Vertex.rgb;

    mat4 projectionMatrix = uProjectionMatrix;
    vec2 halt = uGlobalTexRatio.xy * uHalton.xy / uGlobalTexSize.xy;
    projectionMatrix[2][0] += halt.x;
    projectionMatrix[2][1] += halt.y;

    gl_Position = (projectionMatrix * (uModelViewMatrix * vec4(Vertex, 1.0))).xyww;
}
