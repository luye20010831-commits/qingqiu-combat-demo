shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float strength=1.0;
varying vec3 local_p;
void vertex(){local_p=VERTEX;}
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.5);
 float wave=pow(.5+.5*sin(local_p.y*14.0-TIME*3.0),12.0)*.12;
 ALBEDO=vec3(.129,.655,.459);EMISSION=vec3(.733,.804,.773)*rim*.35;
 ALPHA=(rim*.36+wave*.2)*strength;
}
