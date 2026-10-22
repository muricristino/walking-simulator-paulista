shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 24.0;
uniform float dither = 1.0;
uniform float sat = 1.08;

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[x + y * 4] / 16.0 - 0.5;
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c += bayer(px) * dither / levels;
	c = floor(c * levels + 0.5) / levels;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
