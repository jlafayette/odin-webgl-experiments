#version 300 es

precision highp float;

in vec2 aPos;
in vec2 aTex;
in mat4 aMatrix;

uniform mat4 uProjection;

out vec2 TexCoords;

void main() {
    gl_Position = uProjection * aMatrix * vec4(aPos, 0.0, 1.0);
    TexCoords = aTex;
}
