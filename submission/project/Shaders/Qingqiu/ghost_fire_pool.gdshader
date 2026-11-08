shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 pool_color : source_color = vec4(0.10588,0.81961,0.64706,1.0);
uniform float energy : hint_range(0.0,1.0) = 0.16;
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float radius = length(p);
	float mask = exp(-dot(p,p)*4.5)*(1.0-smoothstep(0.65,1.0,radius));
	ALBEDO = pool_color.rgb;
	ALPHA = mask*energy;
}
