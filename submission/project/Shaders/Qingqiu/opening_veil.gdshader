shader_type canvas_item;
uniform float darkness=1.0;
uniform float bars=1.0;
uniform float vignette=.25;
uniform vec4 ink:source_color=vec4(.038,.045,.055,1.0);
void fragment(){
	float edge=smoothstep(.25,.74,length((UV-.5)*vec2(1.35,1.0)));
	float border=1.0-smoothstep(.061,.064,min(UV.y,1.0-UV.y));
	float alpha=max(darkness,edge*vignette);
	alpha=max(alpha,border*bars);
	COLOR=vec4(ink.rgb,alpha);
}
