#version 300 es

precision highp float;

in vec4 aVertexPosition;
in vec4 aVertexColor;
in vec3 aVertexNormal;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat4 uNormalMatrix;

out vec3 vLighting;
out vec4 vColor;

vec3 light(in vec3 color, in vec3 dir, in vec4 normal) {
	vec3 ndir = normalize(dir);
	float directional = max(dot(normal.xyz, ndir), 0.0);
	return color * directional;
}

void main() {
	gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition.xyz, 1.0);
	vColor = aVertexColor;

	vec4 transformedNormal = uNormalMatrix * vec4(aVertexNormal, 1.0);
	
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

