// Fake 3D camera perspective by Hei, MIT; adapted from perspective_shader.gdshader.
group_uniforms Perspective;
uniform bool perspective_enabled = true;
uniform float perspective_fov : hint_range(1.0, 179.0) = 90.0;
uniform bool perspective_cull_back = true;
uniform float perspective_y_rot : hint_range(-180.0, 180.0) = 0.0;
uniform float perspective_x_rot : hint_range(-180.0, 180.0) = 0.0;
uniform float perspective_inset : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

varying flat vec2 perspective_offset;
varying vec3 perspective_position;

void perspective_vertex(inout vec2 vertex, vec2 uv, vec2 pixel_size, vec2 extent, out vec3 position, out vec2 offset) {
	vec2 source_uv = (uv - 0.5) * extent;
	if (!perspective_enabled) {
		vertex += (uv - 0.5) * (extent - 1.0) / pixel_size;
		position = vec3(source_uv, 1.0);
		offset = vec2(0.0);
		return;
	}
	float b = radians(perspective_y_rot);
	float c = radians(perspective_x_rot);
	mat3 rotation = mat3(
		vec3(cos(b), 0.0, -sin(b)),
		vec3(sin(b) * sin(c), cos(c), cos(b) * sin(c)),
		vec3(sin(b) * cos(c), -sin(c), cos(b) * cos(c))
	);
	float t = tan(radians(perspective_fov) * 0.5);
	position = rotation * vec3(source_uv, 0.5 / t);
	float v = 0.5 / t + 0.5;
	position.xy *= v * rotation[2].z;
	offset = v * rotation[2].xy;
	vertex += (uv - 0.5) / pixel_size * (extent * (1.0 + t * (1.0 - perspective_inset)) - 1.0);
}

vec2 perspective_uv(vec3 position, vec2 offset) {
	return position.xy / position.z - offset + 0.5;
}
