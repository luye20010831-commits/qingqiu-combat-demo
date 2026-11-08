shader_type canvas_item;
render_mode unshaded,blend_add;
uniform vec4 tint:source_color=vec4(.086,.522,.663,1);
uniform float charge=0.0;
uniform float opacity=0.0;
uniform float pulse=0.0;
uniform float clock=0.0;
uniform float fade=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;float r=length(p);
 float soft=exp(-r*r*5.8)*(1.0-smoothstep(.66,.99,r));
 float breath=.92+.08*sin(clock*2.3);
 float strength=(.34+.18*charge+.36*pulse)*breath;
 float angle=atan(p.y,p.x);
 float rays=pow(max(0.0,cos(angle*6.0-clock*.32)),12.0)*exp(-r*r*7.0)*.08*charge;
 COLOR=vec4(tint.rgb,(soft*strength+rays)*opacity*(1.0-fade));
}
