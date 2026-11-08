float charm_heart_distance(vec2 p){
 float u=dot(p,p)-.58;
 float f=u*u*u-p.x*p.x*p.y*p.y*p.y;
 vec2 gradient=vec2(6.0*p.x*u*u-2.0*p.x*p.y*p.y*p.y,6.0*p.y*u*u-3.0*p.x*p.x*p.y*p.y);
 return f/max(length(gradient),.035);
}
