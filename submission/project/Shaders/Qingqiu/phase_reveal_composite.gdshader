shader_type canvas_item;
render_mode unshaded;
uniform float opacity=1.0;
uniform float glow=0.0;
uniform float eye_shot=0.0;
uniform float clock=0.0;
uniform float reduced=0.0;
uniform vec4 fire_outer:source_color=vec4(1,.643,0,1);
uniform vec4 fire_core:source_color=vec4(.95,.94,.87,1);
uniform vec4 tint:source_color=vec4(1,.643,0,1);
void fragment(){
 vec4 body=texture(TEXTURE,UV);
 vec2 px=TEXTURE_PIXEL_SIZE*4.0;
 float spread=0.0;
 spread+=texture(TEXTURE,UV+vec2(px.x,0)).a;
 spread+=texture(TEXTURE,UV-vec2(px.x,0)).a;
 spread+=texture(TEXTURE,UV+vec2(0,px.y)).a;
 spread+=texture(TEXTURE,UV-vec2(0,px.y)).a;
 float edge=max(0.0,spread*.25-body.a)*glow;
 float focus=.30+.70*(1.0-smoothstep(.16,.52,abs(UV.y-.5)));
 vec3 paint=(body.rgb+tint.rgb*edge*.4)*mix(1.0,focus,eye_shot);
 float coverage=max(body.a,edge*.5);
 if(eye_shot>.5){
  // Follow only the live eye alpha. No screen-border or full-frame fire.
  vec2 pixel=TEXTURE_PIXEL_SIZE;
  float turbulence=sin(UV.x*43.0+UV.y*27.0-clock*4.0+sin(UV.y*19.0+clock)*1.4)*.5+.5;
  float tongue=pow(turbulence,2.0);
  vec2 drift=vec2(sin(UV.x*31.0+clock*2.0)*9.0,8.0+tongue*20.0)*pixel;
  float outside=0.0,near_edge=0.0,glow_alpha=0.0;
  for(int i=0;i<12;i++){
   float a=float(i)*6.2831853/12.0;
   vec2 direction=vec2(cos(a),sin(a));
   outside=max(outside,texture(TEXTURE,UV+direction*pixel*(22.0+tongue*34.0)+drift).a);
   near_edge=max(near_edge,texture(TEXTURE,UV+direction*pixel*10.0).a);
   glow_alpha+=texture(TEXTURE,UV+direction*pixel*47.0).a/12.0;
  }
  float rim=clamp(near_edge-body.a,0.0,1.0);
  float flames=clamp(outside-body.a,0.0,1.0);
  float flame_haze=clamp(glow_alpha-body.a,0.0,1.0);
  float fire_alpha=(flames*.67+rim*.36+flame_haze*.24)*mix(1.0,.6,reduced);
  vec3 fire=mix(fire_outer.rgb,fire_core.rgb,clamp(rim*.9+flames*tongue*.35,0.0,1.0));
  float combined=body.a+fire_alpha*(1.0-body.a);
  paint=(paint*body.a+fire*fire_alpha*(1.0-body.a))/max(combined,.001);
  coverage=combined;
 }
 COLOR=vec4(paint,clamp(coverage*opacity,0.0,1.0));
}
