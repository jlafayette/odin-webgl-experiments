#version 300 es

precision highp float;

in vec2 aPos;
in vec2 aTexCoord;
in vec4 aColor;
in mat4 aMatrix;

uniform mat4 uModelMatrix;
uniform mat4 uViewProjectionMatrix;

out vec2 vTexCoord;
out vec4 vColor;

void main() {
    gl_Position = uViewProjectionMatrix * uModelMatrix * aMatrix * vec4(aPos.xy, 0.0, 1.0);
    vTexCoord = aTexCoord;
    vColor = aColor;
}
