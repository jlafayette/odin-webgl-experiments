#version 300 es

precision highp float;

in vec4 aPos;
in vec2 aTexCoord;
in vec4 aColor;
in mat4 aMatrix;

uniform mat4 uModelMatrix;
uniform mat4 uViewProjectionMatrix;

out vec2 vTexCoord;
out vec4 vColor;

void main() {
    gl_Position = uViewProjectionMatrix * aMatrix * aPos;
    vTexCoord = aTexCoord;
    vColor = aColor;
}
