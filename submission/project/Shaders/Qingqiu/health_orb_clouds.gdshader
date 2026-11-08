shader_type canvas_item;
uniform float mist_layer=0.0;
uniform float orbit_pass=1.0;
uniform float canvas_scale=1.30;
uniform float orbit_speed=.40;
float ellipse(vec2 p,vec2 center,vec2 radii){return (length((p-center)/radii)-1.0)*min(radii.x,radii.y);}
float cloud(vec2 p){
 float d=ellipse(p,vec2(-.35,.025),vec2(.37,.21));
 d=min(d,ellipse(p,vec2(-.07,-.10),vec2(.29,.29)));
 d=min(d,ellipse(p,vec2(.24,.01),vec2(.32,.22)));
 d=min(d,ellipse(p,vec2(.04,.10),vec2(.61,.12)));
 return d;
}
void fragment(){
 vec2 p=(UV-.5)*2.0*canvas_scale;
 vec3 ink=vec3(.224,.184,.255),pale=vec3(.733,.804,.773);
 float alpha=0.0;vec3 paint=pale;
 if(mist_layer<.5){
  for(int i=0;i<4;i++){
   float n=float(i);
   float a=TIME*orbit_speed+n*1.5707963+.20*sin(n*2.4);
   float front=smoothstep(-.18,.18,sin(a));
   float pass=mix(1.0-front,front,orbit_pass);
   float depth=.76+.24*(sin(a)*.5+.5);
   vec2 center=vec2(cos(a)*.99,.20+sin(a)*.39+cos(a)*.10);
   vec2 q=(p-center)/vec2(.37*depth,.37*depth);
   q.x*=cos(a)>.0?1.0:-1.0;
   float d=cloud(q);
   float body=1.0-smoothstep(-.015,.02,d);
   float line=(1.0-smoothstep(.008,.035,abs(d)))*.62;
   float curl=1.0-smoothstep(.010,.030,abs(length(q-vec2(-.09,-.035))-.145));
   curl*=1.0-smoothstep(.04,.10,q.y);
   float current=body*pass*mix(.38,.58,orbit_pass);
   vec3 color=mix(pale,ink,max(line,curl*.38));
   color=mix(color,ink,smoothstep(.04,.21,q.y)*.12);
   if(current>alpha){alpha=current;paint=color;}
  }
  // Broken connecting wisps suggest a complete orbit without drawing a solid ring.
  vec2 ring=vec2(p.x/.99,(p.y-.20-p.x*.10)/.39);
  float radius=length(ring);float angle=atan(ring.y,ring.x);
  float front=smoothstep(-.18,.18,sin(angle));
  float pass=mix(1.0-front,front,orbit_pass);
  float strands=pow(max(0.0,sin(angle*3.0-TIME*orbit_speed*3.0)),5.0);
  float wisp=exp(-pow((radius-1.0)/.033,2.0))*strands*pass*.14;
  alpha=max(alpha,wisp);
 }else{
  vec2 q=p;
  float wav=sin(q.x*5.0-TIME*.45)*.022+sin(q.x*8.0+TIME*.33)*.014;
  float band=exp(-pow((q.y+.50+wav)/.12,2.0));
  float mask=1.0-smoothstep(.57,.86,length(q));
  alpha=band*mask*(.65+.35*sin(q.x*8.0-TIME*.65))*.105;
 }
 COLOR=vec4(paint,alpha);
}
