shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float age=0.0;
uniform float seed=0.0;
uniform float opacity=.38;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float n=noise(p*2.8+vec2(seed,-age*.6));
 float shape=length(p*vec2(.83,1.08))+(n-.5)*.24;
 float body=1.0-smoothstep(.35,.92,shape);
 float edge_fade=1.0-smoothstep(.72,1.0,max(abs(p.x),abs(p.y)));
 float breath=smoothstep(0.0,.10,age)*pow(1.0-age,1.05);
 vec3 color=mix(vec3(.733,.804,.773),vec3(.92,.94,.88),n*.45);
 ALBEDO=color;EMISSION=color*.10;ALPHA=body*edge_fade*breath*opacity;
}
