shader_type canvas_item;

// Standalone adapter: preserve the original parameter names.
#define perspective_fov fov
#define perspective_cull_back cull_back
#define perspective_y_rot y_rot
#define perspective_x_rot x_rot
#define perspective_inset inset
#include "res://examples/cards/standard_deck/effects/perspective.gdshaderinc"

void vertex() {
	vec3 position;
	vec2 offset;
	perspective_vertex(VERTEX, UV, TEXTURE_PIXEL_SIZE, vec2(1.0), position, offset);
	perspective_position = position;
	perspective_offset = offset;
}

void fragment() {
	if (abs(perspective_position.z) < 0.00001 ||
		(perspective_enabled && cull_back && perspective_position.z <= 0.0)) discard;
	vec2 uv = perspective_uv(perspective_position, perspective_offset);
	COLOR = texture(TEXTURE, uv);
	COLOR.a *= step(max(abs(uv.x - 0.5), abs(uv.y - 0.5)), 0.5);
}
