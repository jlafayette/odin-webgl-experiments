#version 300 es

precision lowp float;

in vec2 vTexCoord;
in vec4 vColor;

out vec4 fragColor;

void main() {
    
	vec2 st = vTexCoord.xy;
    // The distance from the pixel to the center
    float dist = distance(st,vec2(0.5));    
    float _radius = 0.75;
    float softness = 0.5;
	float d = 1.-smoothstep(_radius-(_radius*softness),
                            _radius+(_radius*softness),
                            dot(dist,dist)*4.0);    
    fragColor = vColor;
    fragColor.a = vColor.a * d;
}
