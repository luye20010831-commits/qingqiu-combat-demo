shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float front_pass=1.0;
uniform float energy=0.0;
uniform float clock=0.0;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
void vertex(){foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);}
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float r=length(p/vec2(.78,.34));
 float d=abs(r-1.0);
 float band=1.0-smoothstep(.17,.25,d);
 float front=smoothstep(-.08,.08,p.y);
 float pass=mix(1.0-front,front,front_pass);
 float angle=atan(p.y/.34,p.x/.78);
 float stripe=pow(max(0.0,cos(angle*7.0-clock*.7)),20.0);
 vec3 gold=vec3(.95,.43,.012),ivory=vec3(.91,.86,.70),ink=vec3(.459,.4,.302);
 float rim=1.0-smoothstep(.07,.17,d);
 vec3 paint=mix(ink,gold,rim*.90);
 paint=mix(paint,ivory,rim*stripe*.15);
 float aura=(1.0-smoothstep(.18,.65,d))*energy*.15;
 ALBEDO=paint;EMISSION=gold*(energy*.48+aura)+ivory*rim*stripe*energy*.12;
 ALPHA=clamp(band*.95+aura,0.0,1.0)*pass;
 DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
