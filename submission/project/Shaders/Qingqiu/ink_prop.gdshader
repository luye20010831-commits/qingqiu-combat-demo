shader_type spatial;
render_mode cull_disabled;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
uniform sampler2D art_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float wind_strength : hint_range(0.0, 0.15) = 0.0;
uniform float uv_wind : hint_range(0.0,0.015) = 0.004;
uniform int wind_profile : hint_range(0,2) = 0;
uniform float wind_scale : hint_range(0.0,2.0) = 1.0;
uniform float wind_clock = 0.0;
uniform bool custom_clock = false;
uniform float seed = 0.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 glow_color : source_color;

void vertex() {
 foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);
	float crown = pow(1.0 - UV.y, 2.0);
	float clock = custom_clock ? wind_clock : TIME;
	float gust = sin(clock*0.83+seed) + 0.28*sin(clock*1.73+seed*1.7);
	VERTEX.x += gust * wind_strength * wind_scale * crown;
	if (wind_profile == 2) VERTEX.y += sin(clock*1.2+seed)*wind_strength*wind_scale*crown*0.16;
}

void fragment() {
	float clock = custom_clock ? wind_clock : TIME;
	vec4 anchor = texture(art_texture,UV);
	float tip = 1.0-UV.y;
	float mask = pow(tip,1.8);
	if (wind_profile == 0) {
		float wood = smoothstep(0.008,0.055,anchor.r-anchor.g);
		mask = smoothstep(0.23,0.62,tip)*(1.0-wood*0.86);
	}
	float gust = sin(clock*0.83+seed) + 0.32*sin(clock*2.1+seed*1.6+UV.y*8.0);
	float flutter = sin(clock*3.4+UV.x*17.0+UV.y*11.0+seed);
	vec2 displacement = vec2(gust+flutter*0.24,cos(clock*1.3+seed+UV.x*9.0)*0.22)*uv_wind*wind_scale*mask*step(0.0001,wind_strength);
	if (wind_profile == 2) displacement *= vec2(0.75,0.55);
	vec2 moving_uv = UV+displacement;
	vec4 art = texture(art_texture,moving_uv);
	ALBEDO = art.rgb;
	ALPHA = art.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float spot = smoothstep(0.4, 0.7, dot(pow(art.rgb, vec3(0.4545)), vec3(0.299, 0.587, 0.114)));
	EMISSION = glow_color.rgb * spot * glow_strength * (0.78 + sin(TIME * 1.3 + seed) * 0.22);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
