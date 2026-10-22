shader_type sky;

uniform vec3 zenith = vec3(0.05, 0.05, 0.16);
uniform vec3 mid = vec3(0.32, 0.16, 0.34);
uniform vec3 horizon = vec3(1.0, 0.48, 0.24);
uniform vec3 ground = vec3(0.12, 0.08, 0.12);
uniform vec3 sun_dir = vec3(0.0, 0.03, -1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	float h = d.y;
	vec3 hz = mix(mid * 1.1, horizon, pow(s, 3.0));
	vec3 c = mix(hz, mid, smoothstep(0.0, 0.18, h));
	c = mix(c, zenith, smoothstep(0.15, 0.6, h));
	c += horizon * pow(s, 40.0) * 0.6;
	vec2 g = floor(d.xz / max(d.y, 0.05) * 60.0);
	float st = step(0.996, hash(g)) * smoothstep(0.3, 0.8, h);
	c += vec3(st) * 0.5;
	if (h < 0.0) {
		c = mix(c, ground, smoothstep(0.0, -0.1, h));
	}
	COLOR = c;
}
