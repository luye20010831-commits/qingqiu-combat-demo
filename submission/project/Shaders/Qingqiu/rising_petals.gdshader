shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform int phase=1;
uniform vec4 petal_tint : source_color=vec4(0.086,0.522,0.663,1.0);
uniform vec4 star_tint : source_color=vec4(0.439,0.953,1.0,1.0);
uniform bool burst=false;
uniform float burst_clock=0.0;
varying float opacity;
varying float kind;
void vertex(){
	vec4 random=INSTANCE_CUSTOM;
	float t=fract(TIME*(0.11+random.z*0.08)+random.x);
	kind=random.w;
	opacity=sin(t*3.14159)*(0.50+random.y*0.5);
	if(phase==1 && random.y>0.35)opacity=0.0;
	vec3 origin=MODEL_MATRIX[3].xyz;
	origin+=vec3(sin(t*4.5+random.x*12.0)*t*0.75,t*(phase==2?3.8:2.8),cos(t*4.0+random.y*10.0)*t*0.60);
	if(burst){
		t=clamp(burst_clock/(0.8+random.z*0.4),0.0,1.0);
		opacity=sin(t*3.14159);
		origin=MODEL_MATRIX[3].xyz+vec3(cos(random.x*6.283)*t*1.15,t*2.0,sin(random.x*6.283)*t*1.15);
	}
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	float rotation=TIME*(0.2+random.z)+random.x*6.283;
	VERTEX.xy=mat2(vec2(cos(rotation),sin(rotation)),vec2(-sin(rotation),cos(rotation)))*VERTEX.xy;
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*scale.x,0.0),vec4(INV_VIEW_MATRIX[1].xyz*scale.y,0.0),vec4(INV_VIEW_MATRIX[2].xyz*scale.z,0.0),vec4(origin,1.0));
}
void fragment(){
	vec2 p=(UV-0.5)*2.0;
	float leaf=1.0-smoothstep(0.72,0.88,length(p*vec2(1.25,0.75)));
	float star=exp(-dot(p,p)*7.0)+exp(-abs(p.x)*19.0-abs(p.y)*4.0)*0.5;
	vec3 color=mix(petal_tint.rgb,star_tint.rgb,step(0.66,kind));
	float shape=mix(leaf,star,step(0.66,kind));
	ALBEDO=color;
	ALPHA=clamp(shape,0.0,1.0)*opacity;
}
