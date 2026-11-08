shader_type canvas_item;
uniform float fill : hint_range(0.0,1.0)=1.0;
uniform float trail_fill : hint_range(0.0,1.0)=1.0;
uniform float impact : hint_range(0.0,1.0)=0.0;
uniform vec2 bar_size=vec2(632.0,32.0);
uniform vec4 fill_color : source_color=vec4(0.733,0.804,0.773,1.0);
uniform vec4 ink : source_color=vec4(0.224,0.184,0.255,1.0);
uniform vec4 highlight : source_color=vec4(0.733,0.804,0.773,1.0);

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Six straight, symmetric edges; the same signed distance defines the
// liquid clipping and the complete frame, including both slanted end caps.
float frame_distance(vec2 p,vec2 extent){
	float slope=.48;
	float side=(abs(p.x)+slope*abs(p.y)-extent.x)/sqrt(1.0+slope*slope);
	return max(abs(p.y)-extent.y,side);
}
void fragment(){
	vec2 px=UV*bar_size;
	vec2 p=px-bar_size*.5;
	float distance=frame_distance(p,bar_size*.5-vec2(1.0));
	float aa=max(fwidth(distance)*.65,.5);
	float mask=1.0-smoothstep(-aa,aa,distance);
	float inside=1.0-smoothstep(-aa,aa,distance+1.45);
	vec2 q=vec2(UV.x*13.0-TIME*0.30,UV.y*2.5);
	float flow=noise(q+vec2(noise(q*0.7+TIME*0.12),noise(q*0.8-TIME*0.09)));
	float flame=sin(UV.y*8.0+flow*6.0+UV.x*30.0-TIME*1.8)*0.5+0.5;
	float filament=pow(flame,13.0)*(0.2+flow*0.55);
	float alive=(1.0-smoothstep(fill-0.001,fill+0.001,UV.x))*step(0.0001,fill);
	float trailing=(1.0-smoothstep(trail_fill-0.001,trail_fill+0.001,UV.x))*(1.0-alive)*step(0.0001,trail_fill);
	float spine=pow(max(0.0,1.0-abs(UV.y-0.48)*1.7),2.0);
	vec3 liquid=fill_color.rgb*(0.45+flow*0.35+spine*0.23)+highlight.rgb*filament*0.18;
	vec3 color=ink.rgb*0.38;
	color=mix(color,fill_color.rgb*0.24+vec3(0.298,0.133,0.106)*0.30,trailing);
	color=mix(color,liquid,alive);
	float edge=exp(-abs(UV.x-fill)*bar_size.x*0.40)*step(0.001,fill)*step(fill,0.999);
	color+=highlight.rgb*edge*(0.23+impact*0.5);
	color=mix(color,highlight.rgb,impact*alive*0.22);
	float top_light=(1.0-smoothstep(0.0,1.5,abs(px.y-2.7)))*.11;
	color+=highlight.rgb*top_light;
	vec3 frame=mix(ink.rgb*.90,fill_color.rgb*.75,.55);
	float upper=1.0-smoothstep(0.0,bar_size.y,px.y);
	frame=mix(frame,highlight.rgb*.82,upper*.38);
	color=mix(frame,color,inside);
	COLOR=vec4(color,mask);
}
