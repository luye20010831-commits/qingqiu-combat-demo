shader_type spatial;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D fracture_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 ground_color : source_color;
uniform float fracture_strength : hint_range(0.0,1.0) = 0.24;
varying vec2 ground_position;

float edge_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 k = vec2(127.1, 311.7);
	float a = fract(sin(dot(cell, k)) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), k)) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), k)) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0, 1.0), k)) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 fracture_image(vec2 world) {
	vec2 cell=floor(world/10.5);
	float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	if(seed<0.28)return vec4(0.0);
	vec2 local=fract(world/10.5)-0.5;
	float patch_edge=1.0-smoothstep(0.40,0.50,max(abs(local.x),abs(local.y)));
	vec2 p=local-vec2(sin(seed*24.0),cos(seed*31.0))*0.06;
	float angle=seed*6.283185;
	p=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*p;
	p*=0.88+seed*0.20;
	vec2 uv=p+0.5;
	if(min(uv.x,uv.y)<0.0 || max(uv.x,uv.y)>1.0)return vec4(0.0);
	vec4 art=texture(fracture_texture,uv);
	art.a*=patch_edge;
	return art;
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Mirrored repeats join the generated texture without a hard tile seam.
	vec2 tile_uv = 1.0 - abs(mod(ground_position / 26.0, 2.0) - 1.0);
	vec3 stone = texture(stone_texture, tile_uv).rgb;
	float edge = max(abs(ground_position.x), abs(ground_position.y));
	float fade = 1.0 - smoothstep(19.5 + edge_noise(ground_position * 0.3) * 3.0, 30.0, edge);
	float variation = dot(stone, vec3(0.299, 0.587, 0.114));
	vec3 base=ground_color.rgb * (0.95 + variation * 0.2);
	vec4 fracture=fracture_image(ground_position);
	float lip=smoothstep(0.10,0.30,dot(fracture.rgb,vec3(0.299,0.587,0.114)));
	vec3 fracture_color=fracture.rgb*mix(0.32,0.80,lip);
	base=mix(base,fracture_color,fracture.a*fracture_strength);
	ALBEDO = base * fade;
	ROUGHNESS = 0.92;
	SPECULAR = 0.05 * fade;
	EMISSION = vec3(0.0);
}
