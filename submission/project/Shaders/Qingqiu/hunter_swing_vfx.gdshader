shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform sampler2D effect_texture:source_color,filter_linear_mipmap,repeat_disable;
uniform float age=0.0;
uniform float flip=1.0;
uniform float strength=1.0;
uniform float impact=0.0;
uniform vec4 tint:source_color=vec4(1.0);
void fragment(){
 vec2 p=UV-.5;p.x*=flip;
 vec2 sample_uv=p+.5;
 vec4 paint=texture(effect_texture,sample_uv);
 float inside=step(0.,sample_uv.x)*step(sample_uv.x,1.)*step(0.,sample_uv.y)*step(sample_uv.y,1.);
 float fade=(1.-smoothstep(.05,1.,age));
 vec3 color=paint.rgb*tint.rgb;
 ALBEDO=color;EMISSION=color*mix(.45,.8,impact);
 ALPHA=paint.a*fade*inside*strength*tint.a;
}
