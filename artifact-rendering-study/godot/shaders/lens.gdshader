shader_type canvas_item;
uniform sampler2D screen_tex:hint_screen_texture,filter_linear_mipmap;
uniform bool styled=false;
uniform float streak_strength:hint_range(0.0,1.0)=0.2;
uniform float grade_strength:hint_range(0.0,1.0)=0.5;
void fragment(){
 vec2 uv=SCREEN_UV;vec3 c=textureLod(screen_tex,uv,0.0).rgb;
 if(styled){vec3 streak=vec3(0.0);float weights=0.0;
 for(int i=-12;i<=12;i++){float x=float(i);float w=exp(-x*x/55.0);vec3 s=textureLod(screen_tex,uv+vec2(x*0.008,0.0),2.0).rgb;
 float lum=max(s.r,max(s.g,s.b));streak+=s*smoothstep(0.65,0.95,lum)*w;weights+=w;}
 c+=streak/weights*streak_strength*vec3(0.65,0.85,1.0);
 float l=dot(c,vec3(0.2126,0.7152,0.0722));
 vec3 tint=mix(vec3(0.88,1.015,1.07),vec3(1.07,1.015,0.94),smoothstep(0.15,0.8,l));c=mix(c,c*tint,grade_strength);
 float vig=1.0-smoothstep(0.25,0.8,length(uv-0.5))*0.18;c*=vig;}
 COLOR=vec4(c,1.0);
}
