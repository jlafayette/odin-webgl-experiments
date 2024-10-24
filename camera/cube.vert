#version 300 es

precision highp float;

in vec4 aVertexPosition;
in vec4 aVertexColor;
in vec3 aVertexNormal;
in mat4 aModelMatrix;
in mat4 aNormalMatrix;

uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform float uMaxFogDistance;
uniform vec4 uFogColor;

out vec3 vLighting;
out vec4 vColor;

vec3 light(in vec3 color, in vec3 dir, in vec4 normal) {
	vec3 ndir = normalize(dir);
	vec3 nnormal = normalize(normal.xyz);
	float directional = max(dot(nnormal, ndir), 0.0);
	return color * directional;
}

void main() {
	gl_Position = uProjectionMatrix * uViewMatrix * aModelMatrix * vec4(aVertexPosition.xyz, 1.0);
	vColor = aVertexColor;
	float fogDistance = length(gl_Position.xyz);
	fogDistance = clamp(fogDistance, 0.0, uMaxFogDistance) / uMaxFogDistance;
	vColor = mix(aVertexColor, uFogColor, fogDistance);

	vec4 transformedNormal = aNormalMatrix * vec4(aVertexNormal, 1.0);

	vLighting = vec3(0.3, 0.4, 0.4) * 0.3
		+ light(
			vec3(1.0, 0.9, 0.8),
			vec3(0.85, 0.8, 0.75),
			transformedNormal
		  ) * 1.8
		+ light(
			vec3(0.2, 0.45, 0.7),
			vec3(-0.2, -0.1, -0.3),
			transformedNormal
		  ) * 0.6
	;
}

