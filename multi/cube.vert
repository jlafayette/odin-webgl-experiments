#version 300 es

precision lowp float;

in vec4 aPos;
in vec2 aTexCoord;

uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;

out vec2 vTexCoord;

void main() {
    gl_PointSize = 10.0;
    gl_Position = uProjectionMatrix * uModelViewMatrix * aPos;
    vTexCoord = aTexCoord;
}
