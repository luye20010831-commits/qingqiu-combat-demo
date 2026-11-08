shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_opaque;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
uniform int phase=1;
uniform float bloom_clock=10.0;
instance uniform float bloom_delay=0.0;
uniform vec4 petal_color : source_color=vec4(0.086,0.522,0.663,1.0);
uniform vec4 outline_color : source_color=vec4(0.0,0.204,0.447,1.0);
uniform vec4 core_color : source_color=vec4(0.439,0.953,1.0,1.0);
uniform vec4 stem_color : source_color=vec4(0.129,0.651,0.459,1.0);
varying float seed;
void vertex(){
 foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);
	seed=MODEL_MATRIX[3].x*1.31+MODEL_MATRIX[3].z*0.73;
	VERTEX.x+=sin(TIME*1.4+seed)*0.025*(1.0-UV.y);
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	vec3 up=vec3(0.0,1.0,0.0);
	vec3 right=normalize(cross(up,INV_VIEW_MATRIX[2].xyz));
	vec3 back=normalize(cross(right,up));
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*scale.x,0.0),vec4(up*scale.y,0.0),vec4(back*scale.z,0.0),MODEL_MATRIX[3]);
}
void fragment(){
	vec2 p=(UV-0.5)*2.0;
	p.y=-p.y;
	vec2 center=p-vec2(0.0,0.31);
	float angle=atan(center.y,center.x);
	float r=length(center);
	float opened=phase==3?smoothstep(bloom_delay,bloom_delay+0.62,bloom_clock):1.0;
	float petal_radius=mix(0.085,0.21+pow(0.5+0.5*cos(angle*6.0),0.55)*0.24,opened);
	float petals=length(center/vec2(mix(0.46,1.0,opened),1.0))-petal_radius;
	float stem=abs(p.x-sin(p.y*3.0+seed)*0.035)-0.018;
	stem=max(stem,max(-0.94-p.y,p.y-0.24));
	float leaves=length((p-vec2(0.12,-0.42))*vec2(3.4,8.0))-0.75;
	leaves=min(leaves,length((p-vec2(-0.12,-0.65))*vec2(3.4,8.0))-0.72);
	float shape=min(petals,min(stem,leaves*0.08));
	vec3 ink=outline_color.rgb;
	vec3 color=petal_color.rgb;
	vec3 core=core_color.rgb;
	float vein=pow(max(0.0,cos(angle*6.0)),18.0)*smoothstep(0.08,0.30,r)*0.20;
	vec3 paint=mix(color,core,(1.0-smoothstep(0.06,0.17,r))+vein);
	if(petals>0.015)paint=stem_color.rgb;
	float outline=smoothstep(-0.023,0.0,shape);
	paint=mix(paint,ink,outline);
	float mask=1.0-smoothstep(0.0,0.012,shape);
	if(phase==2){
		float erosion=sin(center.x*59.0+TIME*0.8+seed)*sin(center.y*37.0-TIME*0.5);
		mask*=1.0-step(0.72,erosion)*smoothstep(0.28,0.56,r)*0.80;
	}
	float halo=phase==2?0.0:exp(-max(petals,0.0)*18.0)*0.055*opened;
	ALBEDO=paint;
	ALPHA=max(mask,halo);
	ALPHA_SCISSOR_THRESHOLD=0.08;
	DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
