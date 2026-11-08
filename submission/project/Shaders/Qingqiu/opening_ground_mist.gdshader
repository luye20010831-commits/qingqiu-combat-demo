shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float clock=0.0;
uniform float opacity=0.45;
uniform float seed=0.0;
uniform vec4 tint:source_color=vec4(.733,.804,.773,1.0);
void fragment(){
	vec2 p=(UV-.5)*2.0;
	float drift=clock*.24+seed;
	float billow=sin(p.x*5.3+drift+sin(p.y*3.1)*.9)*.10;
	billow+=sin(p.y*7.7-drift*.6+p.x*2.7)*.055;
	float body=1.0-smoothstep(.42,.97,length(p*vec2(.91,1.07))+billow);
	float edge=1.0-smoothstep(.75,1.0,max(abs(p.x),abs(p.y)));
	float folds=.68+.15*sin(p.x*8.0+p.y*4.7-drift)+.10*cos(p.y*9.1-drift*.7);
	ALBEDO=tint.rgb;EMISSION=tint.rgb*.08;
	ALPHA=body*edge*folds*opacity;
}
