shader_type canvas_item;
uniform float amount : hint_range(0.0,1.0)=0.0;
uniform vec2 player_uv=vec2(0.5,0.5);
uniform vec2 beacon_uv=vec2(0.5,0.5);
uniform float beacon_active=0.0;
uniform float clock=0.0;
uniform float aspect=1.77778;
uniform vec4 ink : source_color=vec4(0.267,0.161,0.302,1.0);
uniform vec4 rose : source_color=vec4(0.694,0.498,0.616,1.0);
uniform vec4 mist_light : source_color=vec4(0.831,0.690,0.792,1.0);
uniform vec4 light_color : source_color=vec4(0.439,0.953,1.0,1.0);
float cloud_field(vec2 p){
	// Continuous bands with nested displacement give round billows without
	// tiled hash cells, texture seams, polar coordinates or spinning ribbons.
	float broad=sin(p.x*0.81+sin(p.y*0.74)*0.9)*cos(p.y*0.92-sin(p.x*0.63)*0.7);
	float medium=sin(p.x*1.73+p.y*0.54+1.1)*cos(p.y*1.51-p.x*0.31);
	float small=sin(p.x*3.27-p.y*1.18+0.8)*cos(p.y*2.53+p.x*0.69);
	return clamp(0.5+broad*0.26+medium*0.14+small*0.065,0.0,1.0);
}
void fragment(){
	vec2 p=UV*vec2(aspect,1.0);
	// Three independently drifting cloud banks; no angular rotation or vortex.
	float back=cloud_field(p*2.8+vec2(-clock*0.025,clock*0.009));
	float middle=cloud_field(p*4.2+vec2(clock*0.039,-clock*0.013)+vec2(19.4,6.1));
	float front=cloud_field(p*6.8+vec2(-clock*0.058,-clock*0.018)+vec2(4.7,32.9));
	float billow=smoothstep(0.24,0.75,back*0.57+middle*0.43);
	float veil=smoothstep(0.28,0.73,front);
	vec3 color=mix(ink.rgb,rose.rgb,0.30+billow*0.62);
	color=mix(color,mist_light.rgb,veil*0.40+billow*0.15);
	float opacity=clamp(0.35+billow*0.35+veil*0.22,0.0,0.92);
	float player_window=1.0-smoothstep(0.08,0.26,length((UV-player_uv)*vec2(aspect,1.0)));
	opacity*=1.0-player_window*0.24;
	float clear_halo=(1.0-smoothstep(0.035,0.095,length((UV-beacon_uv)*vec2(aspect,1.0))))*beacon_active;
	color=mix(color,light_color.rgb,clear_halo*0.7);
	opacity*=1.0-clear_halo*0.75;
	COLOR=vec4(color,opacity*amount);
}
