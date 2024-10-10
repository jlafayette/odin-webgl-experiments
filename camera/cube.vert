#version 300 es

precision highp float;

in vec4 aVertexPosition;
in vec4 aVertexColor;
in vec3 aVertexNormal;
in mat4 aModelMatrix;
in mat4 aNormalMatrix;

uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

out vec3 vLighting;
out vec4 vColor;

vec3 light(in vec3 color, in vec3 dir, in vec4 normal) {
	vec3 ndir = normalize(dir);
	float directional = max(dot(normal.xyz, ndir), 0.0);
	return color * directional;
}

void main() {
	gl_Position = uProjectionMatrix * uViewMatrix * aModelMatrix * vec4(aVertexPosition.xyz, 1.0);
	vColor = aVertexColor;

	// could move this to instance in mat4 instead of doing it here
	// mat4 normalMatrix = inverse(transpose(aModelMatrix));

	vec4 transformedNormal = aNormalMatrix * vec4(aVertexNormal, 1.0);

	vLighting = vec3(0.0, 0.3, 0.3) * 0.3
		+ light(
			vec3(0.9, 0.8, 0.8),
			vec3(0.85, 0.8, 0.75),
			transformedNormal
		  ) * 0.9
		+ light(
			vec3(0.1, 0.25, 0.5),
			vec3(-0.2, -0.1, -0.3),
			transformedNormal
		  ) * 0.3
	;
}

