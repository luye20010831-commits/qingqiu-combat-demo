shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform sampler2D layer_texture:source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 tint:source_color=vec4(.733,.804,.773,1.0);
uniform float opacity=.14;
#include "res://Shaders/Qingqiu/foot_sort.gdshaderinc"
void vertex(){foot_sort_main_view=foot_vertex(INV_VIEW_MATRIX,MAIN_CAM_INV_VIEW_MATRIX);}
void fragment(){
 vec4 source=texture(layer_texture,UV);
 ALBEDO=tint.rgb;EMISSION=tint.rgb*.035;
 ALPHA=source.a*opacity;
 DEPTH=foot_depth(VIEW_MATRIX,PROJECTION_MATRIX,FRAGCOORD.z);
}
