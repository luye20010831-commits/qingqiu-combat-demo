shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform float seed=0.0;
uniform float opacity=1.0;
uniform float impact=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
 vec2 p=(UV-.5)*2.3;float r=length(p*vec2(.96,1.05));
 float coarse=noise(p*4.0+vec2(seed,seed*.37));
 float grain=noise(p*17.0+seed);
 float body=1.0-smoothstep(.79,1.02,r+(coarse-.5)*.22);
 float fissure=exp(-abs(coarse-.48)*72.0)*smoothstep(.40,.80,grain);
 float pulse=.55+.45*sin(clock*2.1+seed);
 vec3 ink=vec3(.002,.0015,.003),ash=vec3(.038,.032,.045),ember=vec3(.12,.010,.019);
 vec3 color=mix(ink,ash,grain*.28+impact*.15);
 color=mix(color,ember,fissure*.28*pulse);
 ALBEDO=color;EMISSION=ember*fissure*.07*pulse+vec3(.16,.18,.17)*impact*.025;
 ALPHA=body*(.60+impact*.18)*opacity;
}
