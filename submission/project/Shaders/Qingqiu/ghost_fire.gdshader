shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.2, 2.0) = 1.0;
uniform float flow_speed : hint_range(0.1, 3.0) = 1.0;
uniform float wind : hint_range(-1.0, 1.0) = 0.0;
uniform float curl_amount : hint_range(0.0, 1.0) = 0.65;
uniform float outline_width : hint_range(0.001, 0.06) = 0.014;
uniform float halo_strength : hint_range(0.0, 0.7) = 0.24;
uniform float ember_amount : hint_range(0.0, 1.0) = 0.75;
uniform float seed = 1.7;
uniform vec4 outline_color : source_color = vec4(0.0, 0.20392, 0.44706, 1.0);
uniform vec4 outer_color : source_color = vec4(0.08627, 0.52157, 0.66275, 1.0);
uniform vec4 inner_color : source_color = vec4(0.10588, 0.81961, 0.64706, 1.0);
uniform vec4 core_color : source_color = vec4(0.43922, 0.95294, 1.0, 1.0);
uniform vec4 glint_color : source_color = vec4(0.73333, 0.80392, 0.77255, 1.0);

vec2 bezier(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
	float s = 1.0 - t;
	return s*s*s*a + 3.0*s*s*t*b + 3.0*s*t*t*c + t*t*t*d;
}
float tapered_curve(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d, float radius, float tip) {
	float result = 10.0;
	vec2 previous = a;
	float old_radius = radius;
	for (int i = 1; i <= 16; i++) {
		float t = float(i) / 16.0;
		vec2 point = bezier(a,b,c,d,t);
		vec2 segment = point - previous;
		float along = clamp(dot(p-previous, segment) / max(dot(segment,segment), 0.00001), 0.0, 1.0);
		float new_radius = mix(radius, tip, pow(t, 1.05));
		float distance = length(p - mix(previous, point, along)) - mix(old_radius, new_radius, along);
		result = min(result, distance);
		previous = point;
		old_radius = new_radius;
	}
	return result;
}
float smooth_union(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b-a) / k, 0.0, 1.0);
	return mix(b,a,h) - k*h*(1.0-h);
}

void fragment() {
	float time = effect_time * flow_speed;
	vec2 p = (UV - 0.5) * vec2(2.3, -2.5);
	float upper = smoothstep(-0.5, 1.0, p.y);
	p.x -= wind * upper * 0.24;
	p.x += sin(p.y*8.0 - time*4.0 + seed) * 0.028 * upper;
	p.x += sin(p.y*15.0 - time*5.3) * 0.010;
	p.y /= 0.92 + intensity*0.08;
	float sway = sin(time * 1.4 + seed) * 0.13;
	float breathe = 1.0 + sin(time * 3.2) * 0.035;
	p.x /= breathe * mix(0.88, 1.13, clamp(intensity * 0.5, 0.0, 1.0));
	vec2 a = vec2(0.0,-0.52);
	vec2 b = vec2(-0.34,-0.24);
	vec2 c = vec2(0.30+sway,0.30);
	vec2 d = vec2(0.08+sway,0.64+sin(time*1.8)*0.035);
	float main_flame = tapered_curve(p,a,b,c,d,0.265,0.045);
	float curl = tapered_curve(p,d,vec2(0.33+curl_amount*0.20+sway,0.89),vec2(-0.28+sway,1.08),vec2(-0.08+sway,0.84),0.058,0.001);
	main_flame = smooth_union(main_flame,curl,0.035);
	float left = tapered_curve(p,vec2(-0.05,-0.43),vec2(-0.42,-0.33),vec2(-0.52,0.14),vec2(-0.32+sway*0.7,0.37+sin(time*2.2)*0.07),0.175,0.001);
	float right = tapered_curve(p,vec2(0.05,-0.43),vec2(0.42,-0.25),vec2(0.52,0.08),vec2(0.22-sway*0.5,0.34+sin(time*1.9)*0.06),0.175,0.001);
	float field = smooth_union(smooth_union(main_flame,left,0.08),right,0.08);
	float body = 1.0 - smoothstep(-0.004,0.004,field);
	float fill = 1.0 - smoothstep(-outline_width-0.003,-outline_width+0.003,field);
	float middle = tapered_curve(p,vec2(-0.015,-0.51),vec2(-0.20,-0.25),vec2(0.19+sway*0.6,0.26),vec2(-0.06+sway,0.66),0.164,0.001);
	float left_stream = tapered_curve(p,vec2(-0.07,-0.45),vec2(-0.25,-0.27),vec2(-0.36,-0.02),vec2(-0.35+sway*0.4,0.18),0.047,0.001);
	float right_stream = tapered_curve(p,vec2(0.07,-0.45),vec2(0.23,-0.25),vec2(0.36,-0.02),vec2(0.30-sway*0.3,0.18),0.041,0.001);
	middle = min(middle,min(left_stream,right_stream));
	float middle_mask = 1.0 - smoothstep(-0.003,0.004,middle);
	float core = tapered_curve(p,vec2(0.035,-0.52),vec2(-0.06,-0.28),vec2(0.12,0.09),vec2(-0.02+sway*0.5,0.34),0.088,0.001);
	float core_mask = 1.0 - smoothstep(-0.003,0.004,core);
	vec3 color = mix(outline_color.rgb,outer_color.rgb,fill);
	color = mix(color,inner_color.rgb,middle_mask*fill);
	color = mix(color,core_color.rgb,core_mask*fill);
	// Thin upward streams within the body, following the central S rather than tiling.
	float stream = sin(p.y*11.0-time*4.8+p.x*7.0);
	float core_edge = 1.0-smoothstep(0.008,0.022,abs(core+0.02));
	float glint = smoothstep(0.88,0.995,stream) * core_edge * core_mask * 0.4;
	color = mix(color,glint_color.rgb,glint);
	float outside = max(field,0.0);
	float halo = exp(-outside*15.0) * (1.0-smoothstep(0.12,0.26,outside)) * halo_strength * (1.0-body);
	float sparks = 0.0;
	for (int i=0; i<8; i++) {
		float index = float(i);
		float life = fract(time*(0.29+index*0.009)+index*0.137+seed*0.1);
		float x = sin(index*2.7+seed)*0.16 + sin(life*4.4+index)*life*0.42 + wind*life*0.2;
		float y = -0.35 + life*1.58;
		vec2 q = p-vec2(x,y);
		q.x += sin(q.y*25.0+time*2.0)*0.004;
		float distance = length(q/vec2(0.010+index*0.001,0.032+life*0.025));
		float spark = (1.0-smoothstep(0.45,1.0,distance))*sin(life*3.14159265);
		sparks = max(sparks,spark);
	}
	sparks *= ember_amount;
	float alpha = max(body,max(halo,sparks));
	color = mix(inner_color.rgb,color,body);
	color = mix(color,core_color.rgb,sparks*(1.0-body));
	ALBEDO = color;
	ALPHA = alpha;
}
