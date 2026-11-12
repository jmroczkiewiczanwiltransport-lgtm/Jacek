shader_type spatial;
// Asfalt z namalowanymi liniami. UV.x = metry w poprzek od lewej krawędzi, UV.y = metry wzdłuż drogi.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 base_color : source_color = vec3(0.105, 0.105, 0.115);
uniform vec4 solid_lines = vec4(-1.0);      // pozycje linii ciągłych (m); -1 = brak
uniform vec4 dash_lines = vec4(-1.0);       // pozycje linii przerywanych (m)
uniform float dash_len = 4.0;
uniform float dash_gap = 8.0;
uniform vec2 edge_dash_zone = vec2(-1.0);   // odcinek (m wzdłuż), na którym linia solid_lines.w jest przerywana (włączenie do ruchu)
uniform float line_width = 0.2;
uniform float mottle = 0.5;                 // siła plam w dużej skali (plac ma spokojniejszą nawierzchnię)
global uniform float wetness;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float stripe(float x, float pos, float w) {
	if (pos < 0.0) { return 0.0; }
	float aa = fwidth(x) * 1.2 + 0.0005;
	return 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, abs(x - pos));
}

float dashes(float y, float len, float gap) {
	float ph = mod(y, len + gap);
	float aa = fwidth(y) * 1.2 + 0.0005;
	return smoothstep(0.0, aa, ph) * (1.0 - smoothstep(len - aa, len, ph));
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_tex, p * 0.021).r;
	float n2 = texture(noise_tex, p * 0.23).r;
	float n3 = texture(noise_tex, p * 1.9).r;
	vec3 col = base_color * (1.0 - mottle * 0.5 + mottle * n1) * (0.82 + 0.36 * n3);
	float m = max(max(stripe(UV.x, solid_lines.x, line_width), stripe(UV.x, solid_lines.y, line_width)), stripe(UV.x, solid_lines.z, line_width));
	float last = stripe(UV.x, solid_lines.w, line_width);
	if (UV.y > edge_dash_zone.x && UV.y < edge_dash_zone.y) {
		last = stripe(UV.x, solid_lines.w, line_width * 1.6) * dashes(UV.y, 1.5, 1.5);
	}
	m = max(m, last);
	float d = dashes(UV.y, dash_len, dash_gap);
	m = max(m, d * max(max(stripe(UV.x, dash_lines.x, line_width), stripe(UV.x, dash_lines.y, line_width)), max(stripe(UV.x, dash_lines.z, line_width), stripe(UV.x, dash_lines.w, line_width))));
	m *= 0.78 + 0.22 * n2;
	col = mix(col, vec3(0.82, 0.82, 0.78) * (0.8 + 0.2 * n3), m);
	float puddle = smoothstep(0.52, 0.7, n1) * wetness;
	ALBEDO = col * mix(1.0, 0.5, wetness);
	ROUGHNESS = mix(mix(0.88, 0.62, m), mix(0.32, 0.05, puddle), wetness);
	SPECULAR = mix(0.4, 0.75, wetness);
	NORMAL_MAP = texture(normal_tex, p * 0.37).rgb;
	NORMAL_MAP_DEPTH = mix(0.75, 0.1, max(puddle, wetness * 0.6));
}
