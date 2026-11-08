shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
uniform sampler2D art_texture:source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 uv_region=vec4(0,0,1,1);
instance uniform float flip=0.0;
void vertex(){
 foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);
	float seed=MODEL_MATRIX[3].x*1.3+MODEL_MATRIX[3].z*0.7;
	VERTEX.x+=sin(TIME*0.7+seed)*0.018*pow(1.0-UV.y,2.0);
	vec3 up=vec3(0,1,0);
	vec3 right=normalize(cross(up,INV_VIEW_MATRIX[2].xyz));
	vec3 back=normalize(cross(right,up));
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right,0),vec4(up,0),vec4(back,0),MODEL_MATRIX[3]);
}
void fragment(){
	vec2 uv=UV;
	uv.x=mix(uv.x,1.0-uv.x,flip);
	vec4 art=texture(art_texture,uv_region.xy+uv*uv_region.zw);
	ALBEDO=art.rgb*0.72;
	ALPHA=art.a;
	ALPHA_SCISSOR_THRESHOLD=0.45;
	DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
