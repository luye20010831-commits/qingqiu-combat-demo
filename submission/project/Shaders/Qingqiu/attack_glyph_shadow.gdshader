shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float opacity=0.0;
uniform float charge=0.0;
uniform float pulse=0.0;
uniform float fade=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;float r=length(p);
 float soft=exp(-r*r*5.0)*(1.0-smoothstep(.60,.98,r));
 COLOR=vec4(.065,.052,.082,soft*(.48+.12*charge)*opacity*(1.0-fade));
}
