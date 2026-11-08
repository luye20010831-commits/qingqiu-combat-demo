shader_type canvas_item;
render_mode unshaded;
uniform sampler2D seal_atlas:source_color,filter_linear_mipmap,repeat_disable;
uniform vec2 cell=vec2(0);
uniform vec2 atlas_grid=vec2(4);
uniform float charge=0.0;
uniform float opacity=0.0;
uniform float pulse=0.0;
uniform float fade=0.0;
uniform float clock=0.0;
uniform float channeling=0.0;
void fragment(){
 vec4 glyph=texture(seal_atlas,(UV+cell)/atlas_grid);
 float flicker=channeling*(.045*sin(clock*8.5)+.025*sin(clock*14.3));
 vec3 paint=glyph.rgb*(.94+.06*charge+flicker);
 paint=mix(paint,vec3(.95,.91,.76),pulse*.20);
 COLOR=vec4(paint,glyph.a*opacity*(1.0-fade));
}
