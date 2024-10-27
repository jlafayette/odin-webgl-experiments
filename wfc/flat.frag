#version 300 es

precision highp float;

in vec4 vColor;
in vec2 vTexCoord;

uniform sampler2D uSampler;

out vec4 fragColor;

void main() {
    vec4 col = texture(uSampler, vTexCoord);
    fragColor.a = vColor.a;
    fragColor.rgb = mix(vColor.rgb, col.rgb, col.a);
}
