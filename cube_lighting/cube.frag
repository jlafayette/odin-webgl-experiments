#version 300 es

precision highp float;

in vec2 vTextureCoord;
in vec3 vLighting;

uniform sampler2D uSampler;

out vec4 fragColor;

void main() {
	vec4 texelColor = texture(uSampler, vTextureCoord);
	fragColor = vec4(texelColor.rgb * vLighting, texelColor.a);
}
