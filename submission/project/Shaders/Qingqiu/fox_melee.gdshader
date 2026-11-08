shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float progress=0.0;
uniform float variant=0.0;
uniform float confirmed=0.0;
void fragment(){
	vec2 p=UV-0.5;
	float alpha=0.0;
	float fade=1.0-smoothstep(0.25,1.0,progress);
	if(variant<0.5){
		for(int i=0;i<3;i++){
			float n=float(i)-1.0;
			float bend=p.x*0.55+n*0.15+0.30*p.x*p.x;
			float stroke=1.0-smoothstep(0.012,0.028,abs(p.y-bend));
			stroke*=smoothstep(-0.46,-0.31,p.x)*(1.0-smoothstep(0.30,0.45,p.x));
			stroke*=smoothstep(progress*1.4-0.8,progress*1.4-0.65,p.x);
			alpha=max(alpha,stroke);
		}
	}else{
		float ring=abs(length(p*vec2(1.0,1.3))-(0.09+progress*0.43));
		alpha=(1.0-smoothstep(0.012,0.040,ring))*(0.35+0.65*confirmed);
		float rays=pow(max(0.0,sin(atan(p.y,p.x)*9.0)),12.0);
		alpha=max(alpha,rays*(1.0-smoothstep(0.08,0.43,length(p)))*(1.0-progress));
	}
	vec3 ivory=vec3(0.733,0.804,0.773);
	ALBEDO=ivory;
	EMISSION=ivory*(0.25+confirmed*0.40);
	ALPHA=alpha*fade*0.92;
}
