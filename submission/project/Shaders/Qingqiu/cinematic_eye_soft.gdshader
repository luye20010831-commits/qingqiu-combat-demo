shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform sampler2D layer_texture:source_color,filter_linear,repeat_disable;
uniform float glow_strength=0.0;
uniform float charm_flash=0.0;
uniform float reveal_energy=0.0;
uniform vec4 glow_color:source_color=vec4(1,.643,0,1);
uniform vec4 reveal_color:source_color=vec4(1,.643,0,1);
uniform float spirit_hit=0.0;
uniform vec2 mesh_center=vec2(0);
void vertex(){
 VERTEX.xy=mesh_center+(VERTEX.xy-mesh_center)*1.08;
 UV=(UV-.5)*1.08+.5;
}
vec4 tap(vec2 uv){
 if(any(lessThan(uv,vec2(0)))||any(greaterThan(uv,vec2(1))))return vec4(0);
 vec4 c=texture(layer_texture,uv);return vec4(c.rgb*c.a,c.a);
}
void fragment(){
 vec2 pixel=1.0/vec2(textureSize(layer_texture,0));
 vec4 filtered=vec4(0);
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
  float w=(x==0?2.0:1.0)*(y==0?2.0:1.0)/16.0;
  filtered+=tap(UV+vec2(float(x),float(y))*pixel*1.1)*w;
 }
 vec3 color=filtered.rgb/max(filtered.a,.001);
 vec4 center=tap(UV);
 color=mix(color,center.rgb/max(center.a,.001),smoothstep(.2,.8,center.a)*.40);
 ALBEDO=color;
 ALPHA=filtered.a;
 EMISSION=color*min(glow_strength,.32)*.12;
 ROUGHNESS=1.0;
}
