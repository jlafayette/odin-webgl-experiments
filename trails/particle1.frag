#version 300 es

precision lowp float;

in vec2 vTexCoord;
in vec4 vColor;

out vec4 fragColor;

void main() {
    // vec4 col = texture(uSampler, vTexCoord);
    
	vec2 st = vTexCoord.xy;
    // a. The DISTANCE from the pixel to the center
    float dist = distance(st,vec2(0.5));    
    float _radius = 0.9;
    float softness = 0.1;
	float d = 1.-smoothstep(_radius-(_radius*softness),
                            _radius+(_radius*softness),
                            dot(dist,dist)*4.0);    
    fragColor = vColor;
    fragColor.a = vColor.a * d;
    // fragColor.rg = vTexCoord.xy;
    // fragColor.rgb = vec3(d, d, d);
    
    // fragColor.a = 1.0;
    // fragColor.r = 1.0;
}
