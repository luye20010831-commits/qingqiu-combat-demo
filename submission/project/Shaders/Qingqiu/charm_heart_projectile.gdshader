shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform float fade=1.0;
uniform vec4 edge_color : source_color=vec4(.745,0.0,.184,1.0);
uniform vec4 fill_color : source_color=vec4(.851,.110,.424,1.0);
uniform vec4 highlight_color : source_color=vec4(.949,.769,.839,1.0);
#include "res://Shaders/Qingqiu/charm_heart_shape.gdshaderinc"
void fragment(){
 vec2 p=(UV-.5)*2.8;p.y=-p.y+.22;
 float d=charm_heart_distance(p);
 float aa=max(fwidth(d),.003);
 float mask=1.0-smoothstep(-aa,aa,d);
 float border=smoothstep(-.045,-.012,d);
 float rim=exp(-pow((d+.055)/.027,2.0));
 vec3 rose=edge_color.rgb,pink=fill_color.rgb,pale=highlight_color.rgb;
 float flow=.5+.5*sin(p.y*4.0-p.x*2.0-clock*1.7);
 vec3 paint=mix(pink,pale,.035+flow*.08);
 paint=mix(paint,rose,border*.64);paint=mix(paint,pale,rim*.72);
 ALBEDO=paint;EMISSION=pale*rim*.25+pink*(.06+.025*flow);
 ALPHA=mask*fade*(.74+rim*.24);
}
