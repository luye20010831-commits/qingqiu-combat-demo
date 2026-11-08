shader_type canvas_item;
uniform float progress=0.0;
uniform float reduced=0.0;
void fragment(){
 vec2 p=(UV-.5)*vec2(1.35,1.0);
 float pulse=sin(clamp(progress,0.0,1.0)*3.14159);
 float edge=smoothstep(.22,.72,length(p));
 float flare=exp(-pow((length(p)-(.72-.08*pulse))/.026,2.0));
 float strength=mix(1.0,.45,reduced);
 vec3 color=mix(vec3(.224,.184,.255),vec3(1.0,.643,0.0),flare*.75);
 COLOR=vec4(color,(edge*.30+flare*.16)*pulse*strength);
}
