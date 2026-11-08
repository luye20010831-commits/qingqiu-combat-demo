shader_type spatial;
render_mode cull_disabled;
uniform sampler2D sprite_texture:source_color,filter_linear,repeat_disable;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
void vertex(){
 foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);
 vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 vec3 up=vec3(0,1,0);
 vec3 right=normalize(cross(up,INV_VIEW_MATRIX[2].xyz));
 vec3 back=normalize(cross(right,up));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*scale.x,0),vec4(up*scale.y,0),vec4(back*scale.z,0),MODEL_MATRIX[3]);
}
void fragment(){
 vec4 art=texture(sprite_texture,UV);
 ALBEDO=art.rgb;ALPHA=art.a;ALPHA_SCISSOR_THRESHOLD=.42;
 ROUGHNESS=1.0;SPECULAR=0.0;
 DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
