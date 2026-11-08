shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled,blend_add;
uniform float clock=0.0;
uniform float fade=1.0;
#include "res://Shaders/Qingqiu/charm_heart_shape.gdshaderinc"
void fragment(){
 vec2 p=(UV-.5)*vec2(4.666667,4.4);p.y=-p.y+.22;
 float d=charm_heart_distance(p);
 float angle=atan(p.y,p.x);
 float outer=max(d,0.0);
 float envelope=1.0-smoothstep(.72,1.0,length((UV-.5)*2.0));
 float soft=exp(-outer*9.5)*.13;
 float rim=exp(-pow((d-.045)/.085,2.0))*.34;
 float flow=.5+.5*sin(angle*3.0-clock*2.2+outer*16.0);
 float wisps=exp(-pow((d-(.12+.035*sin(angle*4.0+clock*1.6)))/.036,2.0))*pow(flow,4.0)*.14;
 float breath=.90+.10*sin(clock*3.2);
 float outside=smoothstep(-.03,.06,d);
 vec3 pink=vec3(.863,.647,.745),violet=vec3(.655,.502,.729),pale=vec3(.733,.804,.773);
 vec3 tint=mix(violet,pink,flow*.6+.25);
 tint=mix(tint,pale,rim*.55);
 ALBEDO=tint;EMISSION=tint*.25;
 ALPHA=(soft+rim+wisps)*outside*envelope*breath*fade;
}
