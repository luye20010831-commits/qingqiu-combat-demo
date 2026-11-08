shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform float strength:hint_range(0.0,1.0)=1.0;
uniform float seed=0.0;
uniform vec4 gold:source_color=vec4(1.0,0.643,0.0,1.0);
uniform vec4 ivory:source_color=vec4(0.94,0.95,0.87,1.0);
uniform vec4 edge:source_color=vec4(0.459,0.4,0.302,1.0);
// Solid tapered tongues, with broad negative space. No filament skeleton.
float tongue(vec2 p,float x,float height,float width,float lean,float phase){
 float y=p.y/height;
 float sway=sin(y*5.2-clock*3.2+phase)*.15*y*y;
 float center=x+lean*y*y+sway;
 float radius=width*pow(max(1.0-y,0.0),.72);
 radius*=.40+.75*smoothstep(0.0,.20,y);
 radius*=1.0+.10*sin(y*6.0-clock*4.0+phase);
 float side=abs(p.x-center)-radius;
 return max(side,max(-p.y,p.y-height));
}
float body(vec2 p){
 float a=tongue(p,0.0,.90+.035*sin(clock*3.0+seed),.30,.34*sin(clock*1.6+seed),seed);
 float b=tongue(p,-.27,.61+.05*sin(clock*3.7+seed+2.0),.22,-.38,seed+2.0);
 float c=tongue(p,.25,.69+.04*sin(clock*3.3+seed+4.0),.20,.35,seed+4.0);
 return min(a,min(b,c));
}
void fragment(){
 vec2 p=vec2((UV.x-.5)*2.0,1.0-UV.y);
 p.y=(p.y-.025)/max(.2,strength);
 float d=body(p);
 float aa=max(fwidth(d),.0025);
 float solid=1.0-smoothstep(-aa,aa,d);
 float outline=1.0-smoothstep(.002,.018,abs(d));
 float inner=1.0-smoothstep(-.012,.012,body(vec2(p.x*1.62,p.y*1.32))+.026);
 float warm=1.0-smoothstep(.015,.075,abs(d));
 vec3 paint=mix(gold.rgb,ivory.rgb,inner*.94);
 paint=mix(paint,ivory.rgb,smoothstep(.03,.23,-d)*.50);
 paint=mix(paint,edge.rgb,outline*.65);
 // Restrained soft glow, rather than a second bright contour.
 float halo=exp(-max(d,0.0)*50.0)*(1.0-solid)*.10;
 float spark=0.0;
 for(int i=0;i<4;i++){
  float n=float(i);
  float life=fract(clock*.55+n*.267+seed*.13);
  vec2 c=vec2(sin(n*4.3+seed)*(.14+life*.26),.40+life*.58);
  vec2 q=(p-c)/vec2(.016,.026);
  spark=max(spark,(1.0-smoothstep(.2,1.0,length(q)))*sin(life*3.14159));
 }
 ALBEDO=mix(paint,ivory.rgb,spark);
 EMISSION=ALBEDO*(.22+inner*.35)+gold.rgb*halo*.35;
 ALPHA=clamp(solid*.94+halo+spark*.7,0.0,1.0)*strength*smoothstep(-.01,.045,p.y);
}
