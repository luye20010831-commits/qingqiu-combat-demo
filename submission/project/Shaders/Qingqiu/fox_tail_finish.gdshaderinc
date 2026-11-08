// Shared by the live skinned fox and the transparent Spine-part baker.
uniform int tail_finish : hint_range(0, 2) = 0;
uniform vec2 tail_path_uv[29];
uniform float tail_tip_start = 0.82;
uniform float tail_tip_softness = 0.035;
uniform float tail_foil_seed = 0.0;
uniform vec4 tail_black_color : source_color;
uniform vec4 tail_gold_color : source_color;
uniform vec4 tail_gold_shade : source_color;
uniform vec4 tail_gold_highlight : source_color;

float foil_hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

vec2 tail_coordinates(vec2 uv,vec2 size) {
	float nearest=1e10;
	vec2 result=vec2(0.0);
	for(int i=0;i<28;i++) {
		vec2 a=tail_path_uv[i]*size;
		vec2 edge=(tail_path_uv[i+1]-tail_path_uv[i])*size;
		float t=clamp(dot(uv*size-a,edge)/max(dot(edge,edge),0.0001),0.0,1.0);
		vec2 offset=uv*size-a-edge*t;
		float distance=dot(offset,offset);
		if(distance<nearest) {
			nearest=distance;
			vec2 normal=normalize(vec2(-edge.y,edge.x));
			result=vec2((float(i)+t)/28.0,dot(offset,normal)/(size.x*0.38));
		}
	}
	return result;
}

vec4 fox_tail_surface(vec4 layer,vec2 uv,vec2 size) {
	if(tail_finish==0)return vec4(layer.rgb,0.0);
	vec2 path=tail_coordinates(uv,size);
	float edge=tail_tip_start+sin(path.y*9.0)*0.013+sin(path.y*17.0+0.8)*0.006;
	float tip=smoothstep(edge,edge+tail_tip_softness,path.x);
	if(tail_finish==1) {
		float shade=0.82+0.18*clamp(dot(layer.rgb,vec3(0.333)),0.0,1.0);
		return vec4(mix(layer.rgb,tail_black_color.rgb*shade,tip),0.0);
	}
	float strands=0.0;
	for(int i=0;i<3;i++) {
		float n=float(i);
		float center=(n-1.0)*0.36+sin(path.x*8.0+n*1.7+tail_foil_seed)*0.12;
		center+=sin(path.x*21.0+n*0.9)*0.018;
		float distance=abs(path.y-center);
		float fragment=foil_hash(vec2(floor(path.x*24.0+n*0.61),n+tail_foil_seed));
		float width=0.0035+fragment*0.004;
		float aa=max(fwidth(distance),0.002);
		float line=1.0-smoothstep(width-aa,width+aa,distance);
		strands=max(strands,line*smoothstep(0.27,0.41,fragment));
	}
	strands*=smoothstep(0.035,0.13,path.x)*(1.0-tip*0.65);
	// Existing ink edges become gilded; fur/shadow colors remain in the body.
	float ink=1.0-smoothstep(0.09,0.19,dot(layer.rgb,vec3(0.333)));
	float metal=max(tip,max(ink,strands));
	float grain=foil_hash(floor(uv*size/1.1)+vec2(tail_foil_seed));
	float gleam=0.5+0.5*sin(path.x*27.0+path.y*13.0+tail_foil_seed*2.0);
	vec3 gold=mix(tail_gold_shade.rgb,tail_gold_color.rgb,0.82+grain*0.16);
	gold=mix(gold,tail_gold_highlight.rgb,smoothstep(0.965,0.999,grain)*gleam*0.35);
	return vec4(mix(layer.rgb,gold,metal),metal);
}
