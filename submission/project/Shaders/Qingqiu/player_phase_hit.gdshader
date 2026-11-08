shader_type canvas_item;
render_mode unshaded;
uniform float strength=0.0;
uniform float age=0.0;
uniform int phase_index=1;
uniform float reduced=0.0;
uniform vec4 hit_color:source_color=vec4(0.765,0.129,0.212,1.0);
vec3 flame(vec2 p,float seed){
	float t=age*(2.0-reduced*0.7);
	float coordinate=p.x*12.0;
	float base_cell=floor(coordinate);
	vec3 result=vec3(0.022-p.y,0.0,0.0);
	for(int i=-1;i<=1;i++){
		float cell=base_cell+float(i);
		float random=fract(sin(cell*127.1+seed*37.3)*43758.5453);
		float height=(0.065+random*0.095+sin(t*4.0+cell)*0.012)*(0.50+0.50*strength);
		float rise=p.y/max(height,0.001);
		float x=coordinate-cell-0.5;
		float curl=sin(rise*3.2-t*2.0+random*6.28)*rise*0.30;
		float width=0.56*pow(max(0.0,1.0-rise),0.72);
		float field=min((width-abs(x+curl))/12.0,height-p.y);
		float channel=abs(x+curl+0.12*sin(rise*5.0+random*4.0));
		float hot=(1.0-smoothstep(0.020,0.070,channel))*smoothstep(0.10,0.32,rise)*(1.0-smoothstep(0.74,0.95,rise));
		float spark_y=height+0.018+0.065*fract(t*0.55+random);
		float ember=(1.0-smoothstep(0.018,0.040,abs(x-0.18*sin(t+cell))))*(1.0-smoothstep(0.002,0.006,abs(p.y-spark_y)));
		ember*=step(0.68,random)*(1.0-smoothstep(0.18,0.24,p.y));
		result.z=max(result.z,ember);
		if(field>result.x){result.x=field;result.y=hot;}
	}
	return result;
}
void fragment(){
	if(phase_index==1){
		float edge=pow(clamp(length((UV-0.5)*vec2(1.0,0.8))*1.5,0.0,1.0),1.5);
		COLOR=vec4(hit_color.rgb,strength*(0.30+edge*0.20)*(1.0-reduced*0.45));
	}else{
		vec3 f=flame(vec2(UV.x,1.0-UV.y),0.0);
		vec3 top=flame(vec2(1.0-UV.x,UV.y),2.1);
		vec3 left=flame(vec2(UV.y,UV.x),4.7);
		vec3 right=flame(vec2(1.0-UV.y,1.0-UV.x),6.2);
		float ember=max(max(f.z,top.z),max(left.z,right.z));
		if(top.x>f.x)f=top;
		if(left.x>f.x)f=left;
		if(right.x>f.x)f=right;
		float field=f.x;
		float aa=max(fwidth(field),0.001);
		float mask=smoothstep(-aa,aa,field);
		float tips=1.0-smoothstep(0.001,0.0035,field);
		float vein=f.y;
		vec3 ink=vec3(0.224,0.184,0.255)*0.20;
		vec3 fire=mix(ink,vec3(0.239,0.231,0.310),tips*0.65+vein*0.25);
		if(phase_index==3){
			fire=mix(hit_color.rgb*0.58,hit_color.rgb,smoothstep(0.0,0.06,field));
			fire=mix(fire,vec3(0.733,0.804,0.773),clamp(tips*0.94+vein*0.76,0.0,1.0));
		}
		COLOR=vec4(fire,max(mask,ember*0.75)*strength*(0.94-reduced*0.40));
	}
}
