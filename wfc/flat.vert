# version 300 es

precision highp float;

in vec2 aPos;
in vec4 aColor;
in vec4 aTileInfo;
in mat4 aModelMatrix;

uniform mat4 uViewProjectionMatrix;

out vec4 vColor;
out vec2 vTexCoord;

void main() {
    gl_PointSize = 10.0;
    gl_Position = uViewProjectionMatrix * aModelMatrix * vec4(aPos.xy, 1.0, 1.0);
    vec2 tex = aPos;

    // flipV
    // tex = mat2(1.0, 0.0,
    //            0.0, -1.0) * tex;
    // flipH
    // tex = mat2(-1.0, 0.0,
    //             0.0, 1.0) * tex;
    
    tex += vec2(0.5, 0.5); // 0-1
    // tex = mat2(0.5, 0.0,
    //            0.0, -0.5) * tex;
    tex = tex * aTileInfo.zw; // scaled to tile size
    tex = tex + aTileInfo.xy; // offset to correct tile
    vTexCoord = tex;
    
    vColor = aColor;
}
