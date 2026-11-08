// CanvasItem port: only billboard/output plumbing changed; source material math retained.
shader_type canvas_item;


// Reused from the user's Survivor project; its live monster controller selects treatment 1.
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform int treatment : hint_range(0, 3) = 1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float cloud(vec2 p) {
	return noise(p) * 0.57 + noise(p * 2.07 + vec2(3.1, 1.7)) * 0.28 + noise(p * 4.13) * 0.15;
}
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p), a = atan(p.y, p.x);
	float aa = max(fwidth(r), 0.001);
	float t = TIME * 0.38;
	vec2 q = p * (treatment == 0 ? 5.0 : 3.6) + vec2(float(treatment) * 7.7, float(treatment) * 3.2);
	vec2 drift = vec2(cloud(q * 0.7 + vec2(t, -t * 0.8)), cloud(q * 0.7 + vec2(4.7 - t * 0.6, t)));
	float fog = cloud(q + drift * (treatment == 0 ? 2.8 : 1.6) + vec2(t * 0.4, t * 0.8));
	float veins = cloud(q * 1.7 + drift * 4.0 - vec2(t * 0.7, t));
	float filament = pow(clamp(1.0 - abs(veins - 0.52) * 3.8, 0.0, 1.0), 5.0);
	float ratio = clamp(health_ratio, 0.0, 1.0);
	float wave = sin(p.x * 12.0 + TIME * 1.8) * 0.020 + sin(p.x * 23.0 - TIME * 1.2) * 0.010;
	float surface = mix(0.92, 0.08, ratio) + wave;
	float softness = treatment == 0 ? 0.006 : (treatment == 2 ? 0.065 : 0.035);
	float fill = smoothstep(surface - softness, surface + softness, UV.y + (fog - 0.5) * (treatment == 0 ? 0.015 : 0.12));
	if (ratio >= 1.0) { fill = 1.0; }
	if (ratio <= 0.0) { fill = 0.0; }
	vec3 empty = vec3(0.025, 0.016, 0.024);
	vec3 substance;
	if (treatment == 0) {
		// Lacquer blood: layered red marbling with narrow oily specular threads.
		substance = mix(vec3(0.13, 0.008, 0.024), vec3(0.72, 0.055, 0.090), smoothstep(0.2, 0.8, fog));
		substance += vec3(0.16, 0.038, 0.035) * filament;
		substance *= 1.12 - UV.y * 0.28;
	} else if (treatment == 1) {
		// Carmine vapor in a fine oxblood seal.
		substance = mix(vec3(0.10, 0.022, 0.038), vec3(0.68, 0.13, 0.18), smoothstep(0.12, 0.87, fog));
		substance += vec3(0.11, 0.045, 0.050) * veins * fog;
	} else if (treatment == 2) {
		// No hard rim: drifting crimson mist defines the silhouette itself.
		substance = mix(vec3(0.16, 0.026, 0.055), vec3(0.88, 0.20, 0.25), smoothstep(0.16, 0.82, fog));
		substance += vec3(0.10, 0.050, 0.055) * veins;
	} else {
		// Ink smoke with silver-gray wisps and a restrained red ember beneath.
		substance = mix(vec3(0.012, 0.016, 0.023), vec3(0.28, 0.30, 0.34), smoothstep(0.22, 0.82, fog));
		substance += vec3(0.12, 0.13, 0.15) * filament * fog;
		float ember = exp(-dot((p - vec2(0.03, 0.21)) * 3.2, (p - vec2(0.03, 0.21)) * 3.2));
		substance = mix(substance, vec3(0.46, 0.027, 0.055) * (0.5 + fog), ember * 0.58);
	}
	vec3 contents = mix(empty, substance, fill);
	float rim, disc, alpha;
	vec3 frame;
	float light = clamp(dot(p / max(r, 0.001), vec2(-0.65, -0.76)) * 0.5 + 0.5, 0.0, 1.0);
	if (treatment == 0) {
		disc = 1.0 - smoothstep(0.417 - aa, 0.417 + aa, r);
		float rough_r = r + (noise(p * 39.0) - 0.5) * 0.009;
		float cuts = smoothstep(-0.94, -0.85, sin(a * 7.0 + 0.6));
		rim = smoothstep(0.421 - aa, 0.427 + aa, rough_r) * (1.0 - smoothstep(0.464 - aa, 0.469 + aa, rough_r)) * cuts;
		frame = mix(vec3(0.007, 0.009, 0.014), vec3(0.12, 0.13, 0.16), light * 0.7);
		frame += vec3(0.14, 0.018, 0.025) * pow(light, 5.0) * (0.4 + veins);
	} else if (treatment == 1) {
		disc = 1.0 - smoothstep(0.432 - aa, 0.432 + aa, r);
		rim = (1.0 - smoothstep(0.005, 0.008 + aa, abs(r - 0.451)));
		frame = mix(vec3(0.12, 0.012, 0.028), vec3(0.48, 0.065, 0.10), light);
		float outer_arc = (1.0 - smoothstep(0.001, 0.003 + aa, abs(r - 0.474))) * smoothstep(0.0, 0.5, sin(a * 3.0 + 0.5)) * 0.45;
		rim = max(rim, outer_arc);
	} else if (treatment == 2) {
		float edge = 0.425 + (fog - 0.5) * 0.075 + sin(a * 5.0 + t) * 0.006;
		disc = 1.0 - smoothstep(edge - 0.025, edge + 0.025, r);
		rim = (1.0 - smoothstep(0.0, 0.048, abs(r - edge))) * (0.25 + fog * 0.35);
		frame = vec3(0.30, 0.025, 0.060) + vec3(0.24, 0.055, 0.07) * filament;
	} else {
		disc = 1.0 - smoothstep(0.410, 0.437, r);
		float broken = smoothstep(-0.10, 0.20, sin(a * 5.0 + sin(a * 3.0) * 0.8));
		float radius = 0.461 + sin(a * 3.0 + 0.7) * 0.006;
		rim = (1.0 - smoothstep(0.001, 0.004 + aa, abs(r - radius))) * broken;
		frame = mix(vec3(0.13, 0.035, 0.058), vec3(0.45, 0.32, 0.33), light);
	}
	// Composite frame and mist without painting an opaque rectangular quad.
	float body_alpha = disc * (treatment == 2 ? mix(0.18 + fog * 0.12, 0.74 + fog * 0.23, fill) : 1.0);
	float frame_alpha = 0.0;
	alpha = body_alpha + frame_alpha;
	COLOR = vec4((contents * body_alpha + frame * frame_alpha) / max(alpha, 0.001), alpha);
}
