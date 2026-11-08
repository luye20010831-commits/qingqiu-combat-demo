shader_type canvas_item;
uniform vec2 effect_size=vec2(632.0,64.0);
uniform float fill=1.0;
uniform float trail_fill=1.0;
uniform float impact=0.0;
uniform float emitting=1.0;
uniform vec4 tint:source_color=vec4(.733,.804,.773,1.0);
float hash(float n){return fract(sin(n*127.1)*43758.54);}
void fragment(){
 vec2 p=UV*effect_size;
 float alpha=0.0;
 float reach=max(fill,trail_fill);
 // Sparse flecks leave the filled upper edge, drift upward and dissolve.
 for(int i=0;i<28;i++){
  float n=float(i);
  float birth=.025+hash(n+5.3)*.95;
  float speed=.43+hash(n+8.2)*.35;
  float age=fract(TIME*speed+hash(n+2.4));
  float x=birth*effect_size.x+sin(age*3.8+n)*age*(3.0+hash(n+1.1)*7.0);
  float y=29.0-age*(19.0+hash(n+13.0)*9.0);
  float size=.85+hash(n+4.1)*1.0;
  vec2 d=(p-vec2(x,y))/vec2(size,size*(1.0+age*.35));
  float dot_alpha=exp(-dot(d,d)*1.5);
  float fade=smoothstep(0.0,.12,age)*pow(1.0-age,1.4);
  float live=step(birth,reach)*step(.001,reach);
  alpha+=dot_alpha*fade*live*(1.25+impact*.35);
 }
 // A small plume marks the moving health endpoint without hiding its level.
 for(int i=0;i<7;i++){
  float n=float(i)+41.0;
  float age=fract(TIME*(.55+hash(n)*.3)+hash(n+2.0));
  float x=fill*effect_size.x+sin(n+age*4.0)*age*7.0;
  float y=29.0-age*(21.0+hash(n+4.0)*7.0);
  vec2 d=(p-vec2(x,y))/vec2(.8,1.05);
  alpha+=exp(-dot(d,d))*smoothstep(0.0,.10,age)*pow(1.0-age,1.5)*.85*step(.001,fill)*step(fill,.999);
 }
 vec3 pale=vec3(.733,.804,.773);
 COLOR=vec4(mix(tint.rgb,pale,.42),clamp(alpha,0.0,.75)*emitting);
}
