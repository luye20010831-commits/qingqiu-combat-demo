shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform float variant=0.0;
uniform float fade=1.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float arc=.50-.85*p.x*p.x;
 float ink=0.0;
 if(variant<.5){
  for(int i=0;i<3;i++){
   float y=arc+(float(i)-1.0)*.26;
   ink=max(ink,1.0-smoothstep(.035,.09,abs(p.y-y)));
  }
 }else{
  float width=mix(.13,.075,step(1.5,variant))*(1.0-abs(p.x)*.45);
  ink=1.0-smoothstep(width,width+.05,abs(p.y-arc));
  if(variant>1.5)ink=max(ink,(1.0-smoothstep(.035,.08,abs(p.y-arc+.30)))*.55);
 }
 float ends=smoothstep(-1.0,-.68,p.x)*(1.0-smoothstep(.68,1.0,p.x));
 vec3 pale=vec3(.733,.804,.773),violet=vec3(.655,.502,.729);
 ALBEDO=mix(violet,pale,ink*.8);EMISSION=ALBEDO*.38;
 ALPHA=ink*ends*fade*.85;
}
