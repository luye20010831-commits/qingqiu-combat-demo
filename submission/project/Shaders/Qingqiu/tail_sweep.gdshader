shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float progress=0.0;
void fragment(){
 vec2 p=(UV-.5)*5.4;
 float r=length(p);float a=atan(p.x,p.y);
 float head=mix(-1.45,1.45,clamp((progress-.08)/.24,0.0,1.0));
 float delta=head-a;
 float arc=smoothstep(0.0,.07,delta)*(1.0-smoothstep(.28,.75,delta));
 float line=1.0-smoothstep(.035,.17,abs(r-2.0));
 float second=(1.0-smoothstep(.018,.055,abs(r-1.74)))*.35;
 float life=smoothstep(.04,.10,progress)*(1.0-smoothstep(.32,.48,progress));
 ALBEDO=vec3(.733,.804,.773);EMISSION=ALBEDO*.2;
 ALPHA=(line+second)*arc*life*.50;
}
