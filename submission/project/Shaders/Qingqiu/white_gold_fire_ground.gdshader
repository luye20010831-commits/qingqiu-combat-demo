shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float charge=0.0;
uniform float active=0.0;
uniform float effect_time=0.0;
uniform float fade=1.0;
void fragment(){
 vec2 p=(UV-.5)*2.2;float r=length(p);
 float breathing=.95+.025*sin(effect_time*5.0);
 float line=1.0-smoothstep(.010,.037,abs(r-breathing));
 float fill=(1.0-smoothstep(.12,1.0,r))*(.035+.11*active);
 float irregular=sin(p.x*7.0+effect_time*2.0)*sin(p.y*9.0-effect_time*1.6)*.015;
 float edge_flame=1.0-smoothstep(.025,.07,abs(r-(.90+irregular)));
 vec3 gold=vec3(1.0,.643,0.0),ivory=vec3(.94,.95,.87);
 ALBEDO=mix(gold,ivory,line*.12);EMISSION=ALBEDO*(.10+.12*active);
 ALPHA=(line*(.16+.32*charge)*(.85-.35*active)+fill+edge_flame*.08*active)*fade;
}
