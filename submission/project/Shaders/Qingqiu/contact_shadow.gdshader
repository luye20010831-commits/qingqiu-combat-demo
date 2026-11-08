shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

void fragment() {
	float distance_from_center = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.005, 0.013, 0.016);
	ALPHA = (1.0 - smoothstep(0.12, 1.0, distance_from_center)) * 0.57;
}
