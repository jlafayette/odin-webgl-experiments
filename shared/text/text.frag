#version 300 es

precision highp float;

in vec2 TexCoords;

uniform sampler2D uSampler;
uniform vec3 uTextColor;

out vec4 color;

void main() {
    vec4 t = texture(uSampler, TexCoords);
    vec4 sampled = vec4(1.0, 1.0, 1.0, t.a);
    color = vec4(uTextColor, 1.0) * sampled;
}

