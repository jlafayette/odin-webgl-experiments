# version 300 es

precision highp float;

in vec2 aPos;
in vec4 aColor;
in mat4 aModelMatrix;

uniform mat4 uViewProjectionMatrix;

out vec4 vColor;

void main() {
    gl_PointSize = 10.0;
    gl_Position = uViewProjectionMatrix * aModelMatrix * vec4(aPos.xy, 1.0, 1.0);
    vColor = aColor;
}
