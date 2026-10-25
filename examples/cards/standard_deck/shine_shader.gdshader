shader_type canvas_item;

// Standalone adapter: preserve the original parameter names.
#define shine_progress progress
#define shine_width width
#define shine_angle angle
#define shine_intensity intensity
#define shine_bands bands
#define shine_band_gap band_gap
#define shine_band_falloff band_falloff
#define shine_hardness hardness
#define shine_tail_color tail_color
#define shine_auto_speed auto_speed
#define shine_auto_pause auto_pause
#include "res://examples/cards/standard_deck/effects/shine.gdshaderinc"

varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	COLOR = shine_apply(texture(TEXTURE, UV), UV, TIME) * vertex_tint;
}
