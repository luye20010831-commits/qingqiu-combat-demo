shader_type canvas_item;
render_mode unshaded,blend_add;
uniform float clock=0.0;
uniform float opacity=0.0;
uniform float pulse=0.0;
uniform float fade=0.0;
uniform float reduced=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float r=length(p),a=atan(p.y,p.x);
 float spin=a-clock*.72+(r-.62)*4.6;
 float tongues=pow(.5+.5*sin(spin*11.0+sin(spin*3.0)*.38),2.6);
 float lip=.66+tongues*.155;
 float body=smoothstep(.54,.585,r)*(1.0-smoothstep(lip-.015,lip+.015,r));
 float gold_band=exp(-pow((r-(.622+.018*sin(spin*11.0)))/.026,2.0));
 float inner_angle=a+clock*.48;
 float inner=exp(-pow((r-.475)/.009,2.0))*smoothstep(-.1,.4,sin(inner_angle*7.0));
 float curl=pow(max(0.0,sin(spin*11.0+(r-.64)*22.0)),5.0)*body;
 float halo=exp(-pow((r-.64)/.13,2.0))*.17;
 float bright=body*.52+gold_band*.65+inner*.62+curl*.28;
 vec3 gold=vec3(1.0,.643,.0),ivory=vec3(.91,.86,.70);
 vec3 paint=mix(gold,ivory,clamp(gold_band+curl*.5,0.0,1.0));
 float sparks=pow(max(0.0,sin((a-clock*.52)*17.0)),28.0)*exp(-pow((r-(.86+.035*sin(a*7.0-clock*1.6)))/.012,2.0));
 float alpha=(bright+halo+sparks*.65)*opacity*(1.0-fade)*(.88+.12*pulse);
 COLOR=vec4(paint,clamp(alpha,0.0,.90)*mix(1.0,.65,reduced));
}
