#version 300 es

precision highp float;

in vec4 vColor;
in float vCircleBlend;
in vec2 vTexCoord;

out vec4 fragColor;

void main() {
	vec2 st = vTexCoord.xy;
    // The distance from the pixel to the center
    float dist = distance(st,vec2(0.5));    
    float _radius = 0.99;
    float softness = 0.00;
	float d = 1.-smoothstep(_radius-(_radius*softness),
                            _radius+(_radius*softness),
                            dot(dist,dist)*4.0);    
    d = floor(d*1.999);
    fragColor = vColor;
    fragColor.a = mix(fragColor.a * d, fragColor.a, 1.0-vCircleBlend);
    // debug
    // fragColor.a = mix(fragColor.a * d, fragColor.a, 0.5);
}
