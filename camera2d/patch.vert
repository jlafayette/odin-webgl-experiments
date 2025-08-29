#version 300 es

precision highp float;

in vec2 aPos;
// in vec2 aTex;

uniform mat4 uProjection;
uniform vec2 uDim;
uniform vec2 uTileSize;
uniform vec2 uPosOffset;

out vec2 vPos;
out vec2 vDim;
out vec2 vTileSize;

void main() {
    gl_PointSize = 10.0;

    vec2 pos = (aPos + uPosOffset) * uDim;
    gl_Position = uProjection * vec4(pos, 0.0, 1.0);
    // TexCoords = aTex;
    vPos = aPos;
    vDim = uDim;
    vTileSize = uTileSize;
}
