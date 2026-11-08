shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled,blend_add;
uniform float life=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float ray=exp(-abs(p.x)*21.0-abs(p.y)*3.6)+exp(-abs(p.y)*21.0-abs(p.x)*3.6);
 float core=exp(-dot(p,p)*22.0);
 float mask=(ray*.55+core*.65)*(1.0-smoothstep(.62,1.0,length(p)));
 vec3 gold=vec3(1.0,.643,0.0),pale=vec3(.91,.86,.70);
 ALBEDO=mix(gold,pale,core);EMISSION=ALBEDO*.45;
 ALPHA=mask*(1.0-smoothstep(.05,1.0,life));
}
