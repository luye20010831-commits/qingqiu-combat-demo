shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hit_point = vec3(0.0, 0.0, 1.0);
uniform vec4 spirit_color : source_color = vec4(0.73, 0.80, 0.77, 1.0);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float distance_from_hit = length(local_position - hit_point);
	float wave = exp(-pow((distance_from_hit - age * 4.2) / 0.07, 2.0));
	float echo = exp(-pow((distance_from_hit - age * 3.0 + 0.23) / 0.04, 2.0)) * 0.45;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	float envelope = pow(1.0 - age, 1.3) * smoothstep(0.0, 0.035, age);
	ALBEDO = spirit_color.rgb;
	EMISSION = spirit_color.rgb * 0.65;
	ALPHA = clamp((wave + echo) * 0.8 + rim * 0.16, 0.0, 0.9) * envelope;
}
