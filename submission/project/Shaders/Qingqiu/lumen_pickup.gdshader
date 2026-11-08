shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform vec4 light_color : source_color=vec4(0.439,0.953,1.0,1.0);
void fragment(){
	vec2 p=(UV-0.5)*2.0;
	float r=length(p);
	float core=exp(-r*r*40.0);
	float halo=exp(-r*r*5.0)*0.4;
	float ring=exp(-abs(r-(0.48+sin(clock*2.0)*0.04))*65.0)*0.5;
	float ray=exp(-abs(p.x)*35.0)*exp(-abs(p.y)*3.0)*0.30;
	ALBEDO=light_color.rgb;
	ALPHA=clamp(core+halo+ring+ray,0.0,1.0);
}
