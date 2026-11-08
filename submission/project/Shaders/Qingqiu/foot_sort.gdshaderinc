// Forward+ 2.5D card depth: an entire entity shares its foot anchor; its parts
// keep small authored biases. Disabled in workbenches and standalone assets.
instance uniform vec4 foot_sort_anchor=vec4(0.0);
instance uniform float foot_sort_bias=0.0;
varying float foot_sort_main_view;
float foot_vertex(mat4 active_inverse,mat4 main_inverse){
 return 1.0-step(.01,distance(active_inverse[3].xyz,main_inverse[3].xyz));
}
float foot_depth(mat4 view,mat4 projection,float original_depth){
 if(foot_sort_anchor.w<.5 || foot_sort_main_view<.5)return original_depth;
 vec4 point=view*vec4(foot_sort_anchor.xyz,1.0);
 point.z+=foot_sort_bias;
 vec4 clip=projection*point;
 float depth=clip.z/clip.w;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 depth=depth*.5+.5;
 #endif
 return clamp(depth,0.0,1.0);
}
