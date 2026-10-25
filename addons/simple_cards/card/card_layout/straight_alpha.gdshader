shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Canvas captures contain premultiplied colors. Ordinary blend_mix shaders need
// straight RGB; write it without blending into this intermediate texture.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.rgb = color.a > 0.00001 ? color.rgb / color.a : vec3(0.0);
	COLOR = color;
}
