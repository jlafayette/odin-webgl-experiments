#version 300 es

precision lowp float;

in vec2 vTexCoord;
in vec4 vColor;

uniform sampler2D uSampler;

out vec4 fragColor;

void main() {
    vec4 col = texture(uSampler, vTexCoord);
    fragColor = col * vColor;
}
