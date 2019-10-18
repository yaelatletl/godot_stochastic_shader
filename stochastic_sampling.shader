shader_type spatial;
vec2 hash2D2D (vec2 s)
{
    //magic numbers
    return fract(sin(mod(vec2(dot(s, vec2(127.1,311.7)), dot(s, vec2(269.5,183.3))), 3.14159))*43758.5453);
}
 
//stochastic sampling
vec4 textureStochastic(sampler2D tex, vec2 UV)
{
    //triangle vertices and blend weights
    //BW_vx[0...2].xyz = triangle verts
    //BW_vx[3].xy = blend weights (z is unused)
    mat4 BW_vx;
 
    //uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
    vec2 skewUV = (mat2(vec2(1.0 , 0.0) , vec2(-0.57735027 , 1.15470054))* UV * 3.464);
 
    //vertex IDs and barycentric coords
    vec2 vxID = vec2 (floor(skewUV));
    vec3 barry = vec3 (fract(skewUV), 0);
    barry.z = 1.0-barry.x-barry.y;
 
    BW_vx = ((barry.z>0.0) ?
        mat4(vec4(vxID, 0,0), vec4(vxID + vec2(0, 1), 0,0), vec4(vxID + vec2(1, 0), 0,0), vec4(barry,0)) :
        mat4(vec4(vxID + vec2 (1, 1), 0,0), vec4(vxID + vec2 (1, 0), 0,0), vec4(vxID + vec2 (0, 1), 0,0), vec4(-barry.z, 1.0-barry.y, 1.0-barry.x,0)));
 
    //calculate derivatives to avoid triangular grid artifacts
    vec2 dx = dFdx(UV);
    vec2 dy = dFdy(UV);
 
    //blend samples with calculated weights
    return texture(tex, UV + hash2D2D(BW_vx[0].xy), dot(dx, dy)) * BW_vx[3].x +
	       texture(tex, UV + hash2D2D(BW_vx[1].xy), dot(dx, dy)) * BW_vx[3].y +
           texture(tex, UV + hash2D2D(BW_vx[2].xy), dot(dx, dy)) * BW_vx[3].z;
}