shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform vec4 albedo : hint_color;
uniform bool method;
uniform sampler2D texture_albedo : hint_albedo;
uniform sampler2D texture_noise : hint_albedo;
uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform float point_size : hint_range(0,128);
uniform sampler2D texture_metallic : hint_white;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_white;
uniform vec4 roughness_texture_channel;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16);
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;


 
float sum( vec4 v ) { return v.x+v.y+v.z; }

vec2 hash2D2D (vec2 s)
{
    //magic numbers
    return fract(sin(mod(vec2(dot(s, vec2(127.1,311.7)), dot(s, vec2(269.5,183.3))), 3.14159))*43758.5453);
}
 
//stochastic sampling
vec4 textureStochastic(sampler2D tex, vec2 uv)
{
	float k = texture(texture_noise, 0.005 * uv).x; // cheap (cache friendly) lookup
   
    float l = k*8.0;
    float f = fract(l);
    float ia;
    float ib;
   
    if(method){
        ia = floor(l); // my method
        ib = ia + 1.0;
    }else{
        ia = floor(l+0.5); // suslik's method (see comments)
        ib = floor(l);
        f = min(f, 1.0-f)*2.0;
    }
    //triangle vertices and blend weights
    //BW_vx[0...2].xyz = triangle verts
    //BW_vx[3].xy = blend weights (z is unused)
    mat4 BW_vx;
 
    //uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
    vec2 newUV = (mat2(vec2(1.0 , 0.0) , vec2(-0.57735027 , 1.15470054))* uv * 3.464);
 
    //vertex IDs and barycentric coords
    vec2 vxID = vec2 (floor(newUV));
    vec3 fracted = vec3 (fract(newUV), 0);
    fracted.z = 1.0-fracted.x-fracted.y;
 
    BW_vx = ((fracted.z>0.0) ?
        mat4(vec4(vxID, 0,0), vec4(vxID + vec2(0, 1), 0,0), vec4(vxID + vec2(1, 0), 0,0), vec4(fracted,0)) :
        mat4(vec4(vxID + vec2 (1, 1), 0,0), vec4(vxID + vec2 (1, 0), 0,0), vec4(vxID + vec2 (0, 1), 0,0), vec4(-fracted.z, 1.0-fracted.y, 1.0-fracted.x,0)));
 
    //calculate derivatives to avoid triangular grid artifacts
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
 
    //blend samples with calculated weights
    vec4 colora =  (textureGrad(tex, uv + hash2D2D(BW_vx[0].xy), dx, dy) * BW_vx[3].x +
	       textureGrad(tex, uv + hash2D2D(BW_vx[1].xy), dx, dy) * BW_vx[3].y +
           textureGrad(tex, uv + hash2D2D(BW_vx[2].xy), dx, dy) * BW_vx[3].z);
	vec4 colorb = (textureGrad(tex, uv + vec2(3,9) +hash2D2D(BW_vx[0].xy), dx, dy) * BW_vx[3].x +
	       textureGrad(tex, uv + vec2(3,9) + hash2D2D(BW_vx[1].xy), dx, dy) * BW_vx[3].y +
           textureGrad(tex, uv +vec2(3,9) + hash2D2D(BW_vx[2].xy), dx, dy) * BW_vx[3].z);
	return mix( colora, colorb, smoothstep(0.2,0.8,f-0.1*sum(colora-colorb)));
}
float aastep(float threshold, float value){
	float afwidth = length(vec2(dFdx(value), dFdy(value))) * 0.70710678118654757;
	return smoothstep(threshold-afwidth, threshold+afwidth, value);
}
vec4 textureaa(vec4 input, float threshold){
	return vec4(aastep(threshold, input.x), aastep(threshold, input.y), aastep(threshold, input.z), aastep(threshold, input.a));
}

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
}




void fragment() {
	vec2 base_uv = UV;
	vec4 noise = texture(texture_noise, UV);//, dFdx(UV), dFdy(UV));
	vec4 albedo_tex = mix(textureStochastic(texture_albedo,base_uv), textureStochastic(texture_albedo, base_uv+vec2(10,5)), noise);
	
	
	float f = albedo_tex.x*8.0;
	//albedo_tex = mix( albedo_tex_a, albedo_tex_b, smoothstep(0.2,0.8,f-0.1*(albedo_tex_a-albedo_tex_b)));
	
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(textureStochastic(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	float roughness_tex = dot(textureStochastic(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMALMAP = mix(textureStochastic(texture_normal,base_uv),textureStochastic(texture_normal,base_uv+vec2(10,5)), noise).rgb;
	NORMALMAP_DEPTH = normal_scale;
}
