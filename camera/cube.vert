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

void main() {
	gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition.xyz, 1.0);
	vColor = aVertexColor;

	// apply lighting effect
	vec3 ambientLight = vec3(0.3, 0.3, 0.3);
	vec3 directionalLightColor = vec3(1.0, 1.0, 1.0);
	vec3 directionalVector = normalize(vec3(0.85, 0.8, 0.75));
	
	vec4 transformedNormal = uNormalMatrix * vec4(aVertexNormal, 1.0);
	
	float directional = max(dot(transformedNormal.xyz, directionalVector), 0.0);
	vLighting = ambientLight + (directionalLightColor * directional);
}

