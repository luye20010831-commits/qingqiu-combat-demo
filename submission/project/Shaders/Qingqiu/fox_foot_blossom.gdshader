shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform vec4 tint:source_color=vec4(.733,.804,.773,1.0);
uniform float progress=0.0;
uniform float opacity=.8;
void fragment(){
 float open=1.0-pow(1.0-clamp(progress/.24,0.0,1.0),3.0);
 vec2 p=(UV-.5)*2.3/max(.12,open);
 float petal=10.0;
 for(int i=0;i<6;i++){
  float a=float(i)*1.047198;
  vec2 q=vec2(p.x*cos(a)+p.y*sin(a),-p.x*sin(a)+p.y*cos(a))-vec2(0.0,.34);
  petal=min(petal,abs(length(q/vec2(.19,.39))-1.0)*.17);
 }
 float aa=max(fwidth(petal),.002);
 float stroke=1.0-smoothstep(.009,.017+aa,petal);
 float center=1.0-smoothstep(.035,.060,length(p));
 float fade=(1.0-smoothstep(.30,1.0,progress))*smoothstep(0.0,.045,progress);
 ALBEDO=tint.rgb;EMISSION=tint.rgb*.20;
 ALPHA=max(stroke,center*.65)*fade*opacity;
}
