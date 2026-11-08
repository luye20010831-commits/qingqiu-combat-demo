shader_type fog;
uniform float density : hint_range(0.0, 1.0) = 0.24;
uniform float seed = 0.0;
uniform vec4 ivory : source_color = vec4(0.733, 0.804, 0.773, 1.0);
uniform vec4 pale_rose : source_color = vec4(0.835, 0.631, 0.651, 1.0);
uniform vec4 pink_violet : source_color = vec4(0.592, 0.545, 0.659, 1.0);

void fog() {
	vec3 p = (UVW - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.2, 1.0, length(p));
	float flow = sin(WORLD_POSITION.x * 0.8 + TIME * 0.35 + seed);
	flow += sin(WORLD_POSITION.z * 1.15 - TIME * 0.25 + seed) * 0.6;
	float curls = smoothstep(-0.8, 1.1, flow);
	DENSITY = density * edge * curls;
	vec3 color = mix(ivory.rgb, pale_rose.rgb, 0.42 + flow * 0.09);
	color = mix(color, pink_violet.rgb, smoothstep(0.6, 1.4, flow) * 0.20);
	ALBEDO = color;
	EMISSION = mix(color, pale_rose.rgb, 0.35) * DENSITY * 0.45;
}
