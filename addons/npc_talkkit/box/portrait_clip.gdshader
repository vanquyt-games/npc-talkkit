// Clips a portrait to a rounded rectangle, the shape of its frame.
shader_type canvas_item;

uniform vec2 rect_size = vec2(1.0);
// Top left, top right, bottom right, bottom left.
uniform vec4 radii = vec4(0.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = local - half_size;
	float r = p.x < 0.0 ? (p.y < 0.0 ? radii.x : radii.w) : (p.y < 0.0 ? radii.y : radii.z);
	r = min(r, min(half_size.x, half_size.y));
	vec2 q = abs(p) - half_size + r;
	float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	COLOR.a *= clamp(0.5 - distance, 0.0, 1.0);
}
