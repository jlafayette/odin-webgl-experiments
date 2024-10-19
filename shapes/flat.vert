# version 300 es

precision highp float;

in vec2 aPos;
in mat4 aModelMatrix;

uniform vec4 uColor;
uniform mat4 uViewProjectionMatrix;

out vec4 vColor;

void main() {
    gl_PointSize = 10.0;
    gl_Position = uViewProjectionMatrix * aModelMatrix * vec4(aPos.xy, 1.0, 1.0);
    vColor = uColor;
}
