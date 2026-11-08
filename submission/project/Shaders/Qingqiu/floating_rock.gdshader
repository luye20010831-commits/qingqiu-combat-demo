shader_type spatial;
render_mode cull_disabled;
uniform sampler2D rock_texture : source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 sprite_rect=vec4(0.0,0.0,1.0,1.0);
void fragment(){
	vec4 art=texture(rock_texture,sprite_rect.xy+UV*sprite_rect.zw);
	ALBEDO=art.rgb;
	ALPHA=art.a;
	ALPHA_SCISSOR_THRESHOLD=0.5;
	ROUGHNESS=1.0;
	SPECULAR=0.0;
	EMISSION=vec3(0.0);
}
