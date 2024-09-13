#version 300 es

precision highp float;

in vec4 aPos;
in vec2 aTexCoord;
in mat4 aMatrix;

uniform mat4 uModelMatrix;
uniform mat4 uViewProjectionMatrix;

out vec2 vTexCoord;

void main() {
    gl_Position = uViewProjectionMatrix * uModelMatrix * aMatrix * aPos;
    vTexCoord = aTexCoord;
}
