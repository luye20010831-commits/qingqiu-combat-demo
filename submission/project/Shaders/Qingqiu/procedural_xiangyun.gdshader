shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled;

uniform float gold_amount : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.14;
uniform float tail_extension : hint_range(0.0, 0.3) = 0.10;
uniform float ribbon_width : hint_range(0.005, 0.08) = 0.025;
uniform float outline_width : hint_range(0.002, 0.025) = 0.007;
uniform float curl_radius : hint_range(0.08, 0.45) = 0.25;
uniform int curl_count : hint_range(1, 5) = 3;
uniform float aspect : hint_range(2.0, 8.0) = 5.0;
uniform float drift_speed : hint_range(0.0, 2.0) = 0.35;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.02;
uniform float seed = 0.0;
uniform float solid_amount : hint_range(0.0,1.0) = 0.72;
uniform float cloud_clock = 0.0;
uniform bool custom_clock = false;
uniform vec4 fill_color : source_color;
uniform vec4 outline_color : source_color;
uniform vec4 gold_color : source_color;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	float t = clamp(dot(p - a, edge) / dot(edge, edge), 0.0, 1.0);
	return length(p - a - edge * t);
}

float spiral_distance(vec2 p, vec2 center, float radius, float handedness) {
	float distance_to_curve = 20.0;
	vec2 previous = center + vec2(0.0, -radius);
	for (int i = 1; i <= 22; i++) {
		float t = float(i) / 22.0;
		float angle = -1.570796 + handedness * t * 6.6;
		float r = mix(radius, radius * 0.12, t);
		vec2 current = center + vec2(cos(angle), sin(angle)) * r;
		distance_to_curve = min(distance_to_curve, segment_distance(p, previous, current));
		previous = current;
	}
	return distance_to_curve;
}

float ellipse_distance(vec2 p,vec2 radius) {
	return (length(p/radius)-1.0)*min(radius.x,radius.y);
}

float smooth_union(float a,float b,float k) {
	float h = clamp(0.5+0.5*(b-a)/k,0.0,1.0);
	return mix(b,a,h)-k*h*(1.0-h);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float clock = custom_clock ? cloud_clock : TIME;
	float time = clock * drift_speed + seed;
	float wave = sin(p.x * 1.8 + time) * 0.10;
	float lobes = 20.0;
	float scroll_lines = 20.0;
	float left_bound = 20.0;
	float right_bound = -20.0;
	for (int i = 0; i < 5; i++) {
		if (i < curl_count) {
			float x = (float(i) - float(curl_count - 1) * 0.5) * 0.67 - 0.28;
			float radius = curl_radius * (0.83 + 0.16 * sin(float(i) * 2.0 + seed));
			float side = (i % 2 == 0) ? 1.0 : -1.0;
			float center_y = sin(x*1.8+time)*0.10;
			vec2 center = vec2(x,center_y);
			left_bound = min(left_bound,x-radius*1.95);
			right_bound = max(right_bound,x+radius*1.95);
			float base = ellipse_distance(p-center,vec2(radius*1.95,radius*0.76));
			float bump = ellipse_distance(p-center-vec2(radius*0.25,side*radius*0.55),vec2(radius*1.02,radius*0.76));
			float small_bump = ellipse_distance(p-center-vec2(-radius*0.72,side*radius*0.38),vec2(radius*0.82,radius*0.66));
			float cluster = smooth_union(smooth_union(base,bump,0.04),small_bump,0.03);
			lobes = smooth_union(lobes,cluster,0.045);
			vec2 local = vec2(p.x,(p.y-center_y)*side*1.15);
			float curl = spiral_distance(local,vec2(x+radius*0.1,radius*0.14),radius*0.67,1.0);
			scroll_lines = min(scroll_lines,curl);
		}
	}
	// A zero-width infinite ribbon still draws an antialiased hairline. Cap
	// both ends relative to the actual cloud lobes, rather than the quad UVs.
	float start = left_bound-tail_extension;
	float end = right_bound+tail_extension;
	float taper = smoothstep(0.0,0.24,min(p.x-start,end-p.x));
	float shape = max(abs(p.y-wave)-ribbon_width*taper,max(start-p.x,p.x-end));
	shape = mix(shape,smooth_union(shape,lobes,0.035),solid_amount);
	float aa = max(fwidth(shape), 0.001);
	float mask = 1.0 - smoothstep(-aa, aa, shape);
	float outer_line = 1.0-smoothstep(outline_width-aa,outline_width+aa,abs(shape));
	float inner_line = 1.0-smoothstep(outline_width*0.6-aa,outline_width*0.6+aa,scroll_lines);
	float line = max(outer_line,inner_line)*mask;
	vec3 ink = mix(outline_color.rgb, gold_color.rgb, gold_amount);
	vec3 fill = mix(fill_color.rgb,gold_color.rgb,gold_amount*0.18);
	ALBEDO = mix(fill,ink,line);
	EMISSION = fill * emission_strength * (1.0-line);
	ALPHA = mask * mix(opacity*0.84,min(opacity*1.5,0.65),line) * (0.96+sin(time)*0.04);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
