shader_type spatial;
render_mode cull_disabled;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
uniform sampler2D layer_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float apparition_visibility : hint_range(0.0,1.0) = 1.0;
uniform float mist_dissolve : hint_range(0.0,1.0) = 0.0;
uniform float front_shade : hint_range(0.0, 1.0) = 1.0;
uniform float glow_strength : hint_range(0.0, 3.0) = 0.0;
uniform float charm_flash : hint_range(0.0, 1.0) = 0.0;
uniform float spirit_hit : hint_range(0.0, 1.0) = 0.0;
uniform float ink_tint_amount : hint_range(0.0,1.0) = 0.0;
uniform vec4 ink_tint : source_color = vec4(0.224,0.184,0.255,1.0);
uniform float reveal_energy : hint_range(0.0,2.0) = 0.0;
uniform vec4 reveal_color : source_color = vec4(1.0,0.643,0.0,1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.643, 0.0, 1.0);
#include "res://Shaders/Qingqiu/fox_tail_finish.gdshaderinc"

float vapor_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float vapor_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(vapor_hash(i),vapor_hash(i+vec2(1,0)),f.x),mix(vapor_hash(i+vec2(0,1)),vapor_hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);}
void fragment() {
	vec4 layer = texture(layer_texture, UV);
	// Alpha-scissored cutouts need an explicit mist dissolve, not object transparency.
	float grain=fract(sin(dot(floor(UV*128.0),vec2(127.1,311.7)))*43758.5453);
	if (apparition_visibility<0.999 && grain>=apparition_visibility) { discard; }
	float mist_field=vapor_noise(UV*5.0+vec2(TIME*.10,0.0));
	float mist_threshold=mist_dissolve*1.20-.10;
	if(mist_dissolve>.001 && mist_field<mist_threshold){discard;}
	vec4 finish = fox_tail_surface(layer,UV,vec2(textureSize(layer_texture,0)));
	ALBEDO = mix(finish.rgb * front_shade, vec3(0.73, 0.80, 0.77), spirit_hit * 0.42);
	ALBEDO = mix(ALBEDO,ink_tint.rgb*(0.70+0.30*dot(layer.rgb,vec3(0.333))),ink_tint_amount);
	float vapour_band = smoothstep(0.55, 0.95, 0.5 + 0.5 * sin(UV.y * 48.0 + TIME * 8.0));
	ALPHA = layer.a * (1.0 - spirit_hit * vapour_band * 0.42);
	ALPHA_SCISSOR_THRESHOLD = 0.62;
	float light_pixels = smoothstep(0.09, 0.45, dot(layer.rgb, vec3(0.299, 0.587, 0.114)));
	float breath = 0.92 + sin(TIME * 1.6) * 0.08;
	EMISSION = glow_color.rgb * light_pixels * (glow_strength * breath + charm_flash * 0.45);
	EMISSION += vec3(0.73, 0.80, 0.77) * spirit_hit * light_pixels * 0.45;
	float contour=1.0-smoothstep(0.12,0.32,dot(layer.rgb,vec3(0.333)));
	ALBEDO=mix(ALBEDO,reveal_color.rgb,contour*reveal_energy*0.18);
	EMISSION+=reveal_color.rgb*reveal_energy*(contour*0.32+0.04);
	EMISSION+=tail_gold_color.rgb*finish.a*0.07;
	float mist_edge=(1.0-smoothstep(0.0,.12,mist_field-mist_threshold))*step(.001,mist_dissolve);
	ALBEDO=mix(ALBEDO,vec3(.733,.804,.773),mist_dissolve*.55+mist_edge*.35);
	EMISSION+=vec3(.733,.804,.773)*mist_edge*.12;
	ROUGHNESS = mix(1.0,0.42,finish.a);
	SPECULAR = finish.a*0.30;
	DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
