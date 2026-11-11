shader_type spatial;
// Podłoże: łąki i pola z szumu w skali mapy, drobny szum na powierzchni.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
global uniform float wetness;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float big = texture(noise_tex, p * 0.0011).r;
	float mid = texture(noise_tex, p * 0.012 + vec2(0.3, 0.7)).r;
	float fine = texture(noise_tex, p * 0.21).r;
	float tiny = texture(noise_tex, p * 1.7).r;
	vec3 grass = mix(vec3(0.085, 0.16, 0.035), vec3(0.17, 0.24, 0.06), mid);
	vec3 grain = vec3(0.36, 0.31, 0.12);
	vec3 soil = vec3(0.17, 0.125, 0.085);
	vec3 col = mix(grass, grain, smoothstep(0.585, 0.6, big));
	col = mix(col, soil, smoothstep(0.34, 0.325, big) * 0.85);
	// rzędy na polach
	float rows = 0.5 + 0.5 * sin((p.x * 0.8 + p.y * 0.6) * 2.2);
	col *= mix(1.0, 0.86 + 0.14 * rows, max(smoothstep(0.585, 0.6, big), smoothstep(0.34, 0.325, big)));
	col *= (0.78 + 0.44 * fine) * (0.85 + 0.3 * tiny);
	ALBEDO = col * mix(1.0, 0.72, wetness);
	ROUGHNESS = mix(0.96, 0.7, wetness);
	SPECULAR = 0.25;
	NORMAL_MAP = texture(normal_tex, p * 0.3).rgb;
	NORMAL_MAP_DEPTH = 1.1;
}
