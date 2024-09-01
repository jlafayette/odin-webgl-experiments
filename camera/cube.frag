#version 300 es

precision highp float;

in vec3 vLighting;
in vec4 vColor;

out vec4 fragColor;

void main() {
	fragColor = vec4(vColor.rgb * vLighting + 0.1, vColor.a);
}
