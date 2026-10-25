// Reusable glint sweep, adapted from shine_shader.gdshader.
group_uniforms Shine;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shine_progress : hint_range(-0.5, 1.5) = 0.55;
uniform float shine_width : hint_range(0.01, 0.6) = 0.16;
uniform float shine_angle : hint_range(-1.57, 1.57) = 0.6;
uniform float shine_intensity : hint_range(0.0, 2.0) = 1.1;
group_uniforms Shine.Variations;
uniform float shine_bands : hint_range(1.0, 3.0, 1.0) = 1.0;       // 1 to 3 parallel bands
uniform float shine_band_gap : hint_range(0.02, 0.5) = 0.12;       // distance between bands
uniform float shine_band_falloff : hint_range(0.0, 1.0) = 0.45;    // how much thinner / fainter each extra band is
uniform float shine_hardness : hint_range(0.0, 1.0) = 0.0;         // 0 soft glow, 1 crisp stylised stripe
uniform vec4 shine_tail_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // colour at the edges of the band
group_uniforms Shine.Auto;
uniform float shine_auto_speed : hint_range(0.0, 3.0) = 0.0;       // sweeps per second, 0 = use shine_progress
uniform float shine_auto_pause : hint_range(0.0, 3.0) = 1.0;       // seconds between sweeps


vec4 shine_apply(vec4 col, vec2 uv, float time) {
	float p = shine_progress;
	if (shine_auto_speed > 0.0) {
		float period = 1.0 / shine_auto_speed + shine_auto_pause;
		p = mod(time, period) * shine_auto_speed * 1.8 - 0.4;   // runs from -0.4 to past 1.4, then waits
	}
	float d = uv.x * cos(shine_angle) + uv.y * sin(shine_angle);
	float aa = fwidth(d) + 1e-4;
	float glow = 0.0;
	vec3 tint = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		if (float(i) >= shine_bands) break;
		float fi = float(i);
		float w = shine_width * pow(1.0 - shine_band_falloff * 0.6, fi);
		float x = abs(d - (p - fi * (shine_band_gap + shine_width)));
		float soft = (1.0 - smoothstep(0.0, w, x));
		float hard = 1.0 - smoothstep(w * 0.55 - aa, w * 0.55 + aa, x);
		float b = mix(soft, hard, shine_hardness) * pow(1.0 - shine_band_falloff, fi);
		if (b > glow) {
			glow = b;
			tint = mix(shine_tail_color.rgb, shine_color.rgb, mix(soft, 1.0, shine_hardness));
		}
	}
	col.rgb += tint * glow * shine_intensity * col.a;
	return col;
}

group_uniforms;
