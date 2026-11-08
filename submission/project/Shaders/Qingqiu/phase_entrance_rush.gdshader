shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image:hint_screen_texture,filter_linear,repeat_disable;
uniform float power=0.0;
uniform float clock=0.0;
uniform float reduced=0.0;
uniform vec2 center=vec2(.5,.46);
uniform vec4 tint:source_color=vec4(.733,.804,.773,1);
void fragment(){
 vec2 ray=SCREEN_UV-center;
 float strength=power*mix(1.0,.28,reduced);
 vec3 smear=texture(screen_image,SCREEN_UV).rgb*.4;
 for(int i=1;i<=5;i++)smear+=texture(screen_image,SCREEN_UV+ray*float(i)*.012*strength).rgb*.12;
 float angle=atan(ray.y,ray.x);
 float lines=pow(max(0.0,sin(angle*126.0+sin(angle*17.0)*1.2+clock*5.0)),32.0);
 float rim=smoothstep(.17,.65,length(ray));
 smear+=tint.rgb*lines*rim*strength*.28;
 COLOR=vec4(smear,clamp(strength*.88,0.0,.88));
}
