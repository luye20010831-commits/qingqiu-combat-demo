shader_type canvas_item;
render_mode unshaded;
uniform float progress:hint_range(0.0,1.0)=0.0;
uniform float clock=0.0;
uniform float intensity:hint_range(0.0,1.0)=1.0;
uniform vec4 ink_color:source_color=vec4(.224,.184,.255,1.0);
uniform vec4 flame_color:source_color=vec4(1.0,.643,0.0,1.0);
uniform vec4 edge_color:source_color=vec4(.91,.84,.65,1.0);
uniform vec4 core_color:source_color=vec4(.94,.95,.87,1.0);
// Broad painted tongues fold in from both edges, then reverse and withdraw.
float flame_front(vec2 p,float reach,float offset){
 float flow=clock*(progress<.5?-1.0:1.0);
 float base=reach-.22;
 float field=base-p.y;
 for(int i=0;i<8;i++){
  float n=float(i);
  float phase=n*2.71+offset;
  float height=.19+.07*sin(phase+flow*1.7);
  float u=(p.y-base)/max(height,.01);
  float center=(n+.5)/8.0+.018*sin(u*4.5+phase+flow*2.0)*max(u,0.0);
  float width=.088*pow(max(1.0-u,0.0),.65);
  float finger=min(width-abs(p.x-center),height-(p.y-base));
  field=max(field,finger);
 }
 return field;
}
void fragment(){
 float rise=smoothstep(.015,.43,progress);
 float fall=smoothstep(.59,.985,progress);
 float reach=-.19+(rise-fall)*1.53;
 float bottom=flame_front(vec2(UV.x,1.0-UV.y),reach,0.0);
 float top=flame_front(vec2(1.0-UV.x,UV.y),reach*.90-.035,3.4);
 float field=max(bottom,top);
 float aa=max(fwidth(field),.001);
 float cover=smoothstep(-aa,aa,field);
 // Phase commits exactly at .5, within an entirely opaque hold.
 if(progress>=.44 && progress<=.56)cover=1.0;
 float envelope=smoothstep(0.0,.02,progress)*(1.0-smoothstep(.98,1.0,progress));
 float edge=1.0-smoothstep(.0015,.0065,field);
 float inner_bottom=flame_front(vec2(UV.x+.026*sin(UV.y*4.0-clock*1.5),1.0-UV.y),reach*.53+.03,1.7);
 float inner_top=flame_front(vec2(1.0-UV.x,UV.y),reach*.46+.025,5.8);
 float inner=max(inner_bottom,inner_top);
 float core=smoothstep(-.007,.007,inner);
 float inner_edge=1.0-smoothstep(.004,.02,abs(inner));
 vec3 paint=mix(flame_color.rgb,edge_color.rgb,.22);
 paint=mix(paint,core_color.rgb,core*.92);
 paint=mix(paint,edge_color.rgb,inner_edge*.7);
 // A broad undulating fold remains visible while the screen is fully covered.
 float fold_y=.50+.075*sin(UV.x*7.0-clock*1.8)+.032*sin(UV.x*15.0+clock);
 float fold=1.0-smoothstep(.015,.10,abs(UV.y-fold_y));
 paint=mix(paint,flame_color.rgb,fold*.42*intensity);
 paint=mix(paint,ink_color.rgb,edge*.65);
 COLOR=vec4(paint,cover*envelope);
}
