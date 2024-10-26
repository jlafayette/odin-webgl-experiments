#version 300 es

precision highp float;

in vec4 vColor;
in float vCircleBlend;

out vec4 fragColor;

void main() {
    fragColor = vColor;
}
