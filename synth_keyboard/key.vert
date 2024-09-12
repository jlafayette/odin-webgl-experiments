#version 300 es

precision lowp float;

in vec4 aPos;
in vec2 aTexCoord;
// in mat4 matrix;

uniform mat4 uModelMatrix;
uniform mat4 uViewProjectionMatrix;

out vec2 vTexCoord;

void main() {
    gl_Position = uViewProjectionMatrix * uModelMatrix * aPos;
    // gl_Position = uViewProjectionMatrix * matrix * uModelMatrix * aPos;
    vTexCoord = aTexCoord;
}
