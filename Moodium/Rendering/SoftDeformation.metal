#include <metal_stdlib>
using namespace metal;
struct Vertex { float3 position; float3 normal; float2 uv; float2 pad; float3 tangent; float3 bitangent; };
struct Parameters { float3 touch; float3 inward; float3 grab; float radius; float depth; float weight; float grabRadius; uint count; };
float falloff(float distance, float radius) { float w=1-clamp(distance/max(.0001f,radius),0.f,1.f); return w*w*(3-2*w); }
kernel void deformSoft(const device Vertex* source [[buffer(0)]], device Vertex* result [[buffer(1)]], constant Parameters& p [[buffer(2)]], uint id [[thread_position_in_grid]]) {
    if(id>=p.count)return;
    Vertex v=source[id];float d=distance(v.position,p.touch);
    v.position += p.inward*(p.depth*falloff(d,p.radius)*p.weight)+p.grab*falloff(d,p.grabRadius);
    result[id]=v;
}
// Recalculate from the actual deformed indexed triangles, as Unity does, rather than
// retaining the rest-pose normals (which makes dents appear painted onto a rigid mesh).
kernel void normalsSoft(device Vertex* vertices [[buffer(0)]], const device uint* indices [[buffer(1)]], const device uint* offsets [[buffer(2)]], const device uint* faces [[buffer(3)]], constant uint& count [[buffer(4)]], uint id [[thread_position_in_grid]]) {
    if(id>=count)return;
    float3 n=0,t=0,b=0;
    for(uint a=offsets[id];a<offsets[id+1];a++) {
        uint f=faces[a]*3;Vertex v0=vertices[indices[f]],v1=vertices[indices[f+1]],v2=vertices[indices[f+2]];
        float3 e1=v1.position-v0.position,e2=v2.position-v0.position;
        n+=cross(e1,e2);
        float2 u1=v1.uv-v0.uv,u2=v2.uv-v0.uv;float det=u1.x*u2.y-u1.y*u2.x;
        if(abs(det)>1e-10f){t+=(e1*u2.y-e2*u1.y)/det;b+=(e2*u1.x-e1*u2.x)/det;}
    }
    if(length_squared(n)>1e-16f)vertices[id].normal=normalize(n);
    if(length_squared(t)>1e-16f)vertices[id].tangent=normalize(t);
    if(length_squared(b)>1e-16f)vertices[id].bitangent=normalize(b);
}
