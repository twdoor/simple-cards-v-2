/// Faux 3D Perspective Shader for 2D CanvasItems in Godot.
/// By CodeVogel (https://codevogel.com), based on Hei's '2D-perspective' shader (https://godotshaders.com/shader/2d-perspective/)
/// This version adds versatility for showing front/back textures.
// MIT Licensed

shader_type canvas_item;

uniform bool cull_backface = true;
uniform bool use_front = true;
uniform float fov : hint_range(1, 179) = 90.0;
uniform float rot_y_deg : hint_range(-360, 360) = 0.0;
uniform float rot_x_deg : hint_range(-360, 360) = 0.0;
uniform float inset : hint_range(0, 1) = 0.0;

varying vec2 offset;
varying vec3 world_pos_3d;

void vertex() {
	float rot_y_rad = radians(rot_y_deg);
	float rot_x_rad = radians(rot_x_deg);

	float sin_y = sin(rot_y_rad), cos_y = cos(rot_y_rad);
	float sin_x = sin(rot_x_rad), cos_x = cos(rot_x_rad);

	// Construct rotation matrix
	mat3 rotation_matrix;
	rotation_matrix[0] = vec3(cos_y, 0.0, -sin_y);
	rotation_matrix[1] = vec3(sin_y * sin_x, cos_x, cos_y * sin_x);
	rotation_matrix[2] = vec3(sin_y * cos_x, -sin_x, cos_y * cos_x);

	// Project UV coordinates into pseudo-3D space
	float perspective_scale = tan(radians(fov) * 0.5);
	world_pos_3d = rotation_matrix * vec3(UV - 0.5, 0.5 / perspective_scale);

	// Adjust XY coordinates based on perspective depth
	float depth_scale = (0.5 / perspective_scale) + 0.5;
	world_pos_3d.xy *= depth_scale * rotation_matrix[2].z;
	offset = depth_scale * rotation_matrix[2].xy;

	// Apply perspective transformation to vertex position 
	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * perspective_scale * (1.0 - inset);
}

void fragment() {
	// Discard back-facing fragments if culling is enabled
	if (cull_backface && world_pos_3d.z <= 0.0) discard;

	// Perspective divide to get 2D UV coordinates
	vec2 projected_uv = (world_pos_3d.xy / world_pos_3d.z) - offset + 0.5;

	// Discard pixels outside of the rectangle
	if (projected_uv.x < 0.0 || projected_uv.x > 1.0 || projected_uv.y < 0.0 || projected_uv.y > 1.0)
		discard;

	// Sample the texture depending on which face is visible
	if (use_front) {
		COLOR = texture(TEXTURE, projected_uv);
	} else {
		// flip back face uv horizontally to keep texture orientation correct
		COLOR = texture(TEXTURE, vec2(1.0 - projected_uv.x, projected_uv.y));
	}
}