#version 300 es

precision highp float;

in vec2 aPos;
in vec3 aColor;

uniform mat4 uProjection;

out vec4 vColor;

void main() {
    gl_Position = uProjection * vec4(aPos, -1.0, 1.0);
    vColor = vec4(aColor, 1.0);
}
