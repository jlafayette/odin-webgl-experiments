#version 300 es

precision highp float;

in vec2 vPos;
in vec2 vDim;
in vec2 vTileSize;

uniform sampler2D uSampler;
uniform vec3 uColor;

out vec4 color;

float square(vec2 f, vec2 lo) {
    float c = 1.0;
    vec2 hi = vec2(1.0) - lo;
    // step will return 0.0 unless the value is over threshold
    // in that case it will return 1.0
    c *= step(lo.x, f.x);
    c *= 1.0 - step(hi.x, f.x);
    c *= step(lo.y, f.y);
    c *= 1.0 - step(hi.y, f.y);
    return c;
}
float smooth_square(vec2 f, vec2 lo) {
    float s = 0.01;
    float c = 1.0;
    vec2 hi = vec2(1.0) - lo;
    c *= smoothstep(lo.x, lo.x+s, f.x);
    c *= 1.0 - smoothstep(hi.x-s, hi.x, f.x);
    c *= smoothstep(lo.y, lo.y+s, f.y);
    c *= 1.0 - smoothstep(hi.y-s, hi.y, f.y);
    return c;
}

void main() {

    // c is the square center of each tile
    vec2 pos = (vPos * vDim) / vTileSize;
    vec2 f = fract(pos);
    float c = square(f, vec2(0.1));
    
    vec2 nTiles = (vDim / vTileSize);
    vec2 tpos = (vPos * nTiles) / nTiles;
    vec4 t = texture(uSampler, tpos);

    vec3 rgb = mix(vec3(0.0), uColor, t.r);
    rgb *= c;

    // border for debugging
    // vec2 px = 1.0 / vTileSize;
    // float b = 1.0 - smooth_square(f, px);
    
    color = vec4(rgb, 1.0);
}
