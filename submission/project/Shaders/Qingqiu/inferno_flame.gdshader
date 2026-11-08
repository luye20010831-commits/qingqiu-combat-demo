shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform float seed=0.0;
uniform float opacity=1.0;
uniform float impact=0.0;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
void vertex(){foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);}
float tongue(vec2 p,float x,float h,float w,float lean,float phase){
 float y=p.y/h;
 float center=x+lean*y*y+sin(y*6.2-clock*4.7+phase)*.14*y*y;
 float radius=w*pow(max(1.0-y,0.0),.77)*(.42+.70*smoothstep(0.0,.17,y));
 return max(abs(p.x-center)-radius,max(-p.y,p.y-h));
}
float flame(vec2 p){
 float a=tongue(p,0.0,.96,.29,.20*sin(clock*1.8+seed),seed);
 float b=tongue(p,-.30,.69,.22,-.42,seed+2.0);
 float c=tongue(p,.30,.77,.22,.34,seed+4.0);
 return min(a,min(b,c));
}
void fragment(){
 vec2 p=vec2((UV.x-.5)*2.0,1.0-UV.y);
 float d=flame(p);float aa=max(fwidth(d),.003);
 float solid=1.0-smoothstep(-aa,aa,d);
 float edge=exp(-abs(d)*58.0);
 float fold=1.0-smoothstep(-.01,.03,flame(vec2(p.x*1.5,p.y*1.35))+.055);
 vec3 ink=vec3(.0025,.0020,.0045),dark=vec3(.020,.016,.028),silver=vec3(.20,.235,.225);
 vec3 color=mix(ink,dark,fold*.8);
 color=mix(color,silver,edge*.75);
 float seam=pow(max(0.0,sin(p.y*8.0-clock*3.0+seed)),9.0)*fold;
 vec3 ember=vec3(.12,.010,.019);
 color=mix(color,ember,seam*.07);
 float glow=exp(-max(0.0,d)*35.0)*(1.0-solid)*.045;
 ALBEDO=color;EMISSION=silver*edge*(.12+impact*.18)+ember*seam*.06+silver*glow;
 ALPHA=(solid*.97+glow)*opacity*smoothstep(-.01,.035,p.y);
 DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
