shader_type canvas_item;
uniform float emitting=0.0;
uniform vec4 tint : source_color=vec4(0.106,0.82,0.647,1.0);
float hash(float n){return fract(sin(n*127.1)*43758.54);}
void fragment(){
	vec2 p=UV;
	float alpha=0.0;
	for(int i=0;i<22;i++){
		float n=float(i);
		float t=fract(TIME*(0.45+hash(n+2.0)*0.35)+hash(n+7.0));
		float x=0.5+sin(t*4.0+n)*0.12*t+(hash(n+3.0)-0.5)*0.38*t;
		float y=1.0-t*0.95;
		float r=0.012+hash(n+8.0)*0.015;
		vec2 delta=(p-vec2(x,y))*vec2(1.25,1.0);
		float dot_glow=exp(-dot(delta,delta)/(r*r));
		float star=exp(-abs(delta.x)*300.0-abs(delta.y)*90.0)*0.4;
		alpha+=(dot_glow+star)*sin(t*3.14159)*(1.0-t*0.45);
	}
	COLOR=vec4(tint.rgb,clamp(alpha,0.0,0.85)*emitting);
}
