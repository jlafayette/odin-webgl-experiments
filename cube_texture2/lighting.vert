#version 300 es

precision highp float;

in vec4 aVertexPosition;
in vec3 aVertexNormal;
in vec2 aTextureCoord;

uniform mat4 uNormalMatrix;
uniform mat4 uModelMatrix;
uniform mat4 uViewProjectionMatrix;

out vec2 vTextureCoord;
out vec3 vLighting;

void main() {
	gl_Position = uViewProjectionMatrix * uModelMatrix * aVertexPosition;
	vTextureCoord = aTextureCoord;
	
	// apply lighting effect
	vec3 ambientLight = vec3(0.1, 0.2, 0.3);
	vec3 directionalLightColor = vec3(1.0, 0.9, 0.8);
	vec3 directionalVector = normalize(vec3(0.85, 0.8, 0.75));
	
	vec3 transformedNormal = (uNormalMatrix * vec4(aVertexNormal, 1.0)).xyz;
	transformedNormal = normalize(transformedNormal);
	
	float directional = max(dot(transformedNormal, directionalVector), 0.0);
	vLighting = ambientLight + (directionalLightColor * directional);
}
