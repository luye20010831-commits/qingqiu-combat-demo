shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float golden=0.0;
uniform float shot=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=UV-.5;
 vec3 ink=vec3(.224,.184,.255),jade=vec3(.24,.23,.31),gold=vec3(.459,.4,.302);
 vec3 base=mix(ink*.16,gold*.20,golden);
 float mist=exp(-pow(p.y*2.8+sin(p.x*5.0+clock*.18)*.12,2.0))*exp(-dot(p,p)*2.0);
 base+=mix(jade,gold,golden)*mist*.12;
 vec2 cell=floor((UV+vec2(0,clock*.014))*vec2(52,30));
 vec2 point=fract((UV+vec2(0,clock*.014))*vec2(52,30))-.5;
 float mote=pow(max(0.0,1.0-length(point)*7.0),3.0)*step(.975,hash(cell));
 base+=mix(vec3(.65,.49,.73),vec3(1,.643,0),golden)*mote*(.3+.3*sin(clock+hash(cell)*6.28));
 float floor_line=exp(-pow((UV.y-.77)/.0025,2.0))*exp(-pow(p.x*1.7,2.0))*step(.5,golden)*(1.0-step(.5,shot));
 base+=vec3(1,.643,0)*floor_line*.12;
 COLOR=vec4(base,1.0);
}
