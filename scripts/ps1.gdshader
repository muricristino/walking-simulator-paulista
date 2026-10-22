shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D glow_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 emit = vec3(0.0);
uniform float glow = 0.0;
uniform vec2 snap_res = vec2(400.0, 300.0);
uniform float affine = 0.6;
uniform float unshaded = 0.0;
uniform float squash = 0.0;
varying vec3 aff;

void vertex() {
	vec4 p = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 g = snap_res * 0.5;
	if (p.w > 0.05) {
		p.xy = floor(p.xy / p.w * g + 0.5) / g * p.w;
	}
	p.z = mix(p.z, p.w, squash);
	POSITION = p;
	aff = vec3(UV * p.w, p.w);
}

void fragment() {
	vec2 uv = mix(UV, aff.xy / aff.z, affine);
	vec3 c = texture(tex, uv).rgb * tint.rgb * COLOR.rgb;
	ALBEDO = c * (1.0 - unshaded);
	EMISSION = emit + texture(glow_tex, uv).rgb * glow * COLOR.a + c * unshaded;
	ROUGHNESS = 1.0;
}
