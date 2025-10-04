#include <metal_stdlib>
using namespace metal;

constant float2 downOffsets[4] = {
    float2(-0.5, -0.5),
    float2(0.5, -0.5),
    float2(-0.5, 0.5),
    float2(0.5, 0.5)
};

constant float2 upOffsets[8] = {
    float2(-1.0, 0.0),
    float2(-0.5, 0.5),
    float2(0.0, 1.0),
    float2(0.5, 0.5),
    float2(1.0, 0.0),
    float2(0.5, -0.5),
    float2(0.0, -1.0),
    float2(-0.5, -0.5)
};

struct KawaseParams {
    float2 texel;
    float offset;
};

struct FresnelParams {
    half3 tintColor;
    half fresnelStrength;
    half blurMix;
    half ior;
};

struct VertexOut {
    float4 position [[position]];
    half2 texCoord [[user(locn0)]];
};

kernel void kawaseDown(
    texture2d<half, access::sample> src [[texture(0)]],
    texture2d<half, access::write> dst [[texture(1)]],
    constant KawaseParams& params [[buffer(0)]],
    sampler smp [[sampler(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) {
        return;
    }
    
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    
    half4 center = src.sample(smp, uv);
    half4 sum = center * 4.0h;
    
    for (int i = 0; i < 4; i++) {
        float2 offset = downOffsets[i] * params.offset * params.texel;
        sum += src.sample(smp, uv + offset);
    }
    
    dst.write(sum / 8.0h, gid);
}

kernel void kawaseUp(
    texture2d<half, access::sample> low [[texture(0)]],
    texture2d<half, access::sample> src [[texture(1)]],
    texture2d<half, access::write> dst [[texture(2)]],
    constant KawaseParams& params [[buffer(0)]],
    sampler smp [[sampler(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) {
        return;
    }
    
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    
    half4 lowSample = low.sample(smp, uv);
    
    half4 sum = 0.0h;
    constant half weights[8] = {1.0h, 2.0h, 1.0h, 2.0h, 1.0h, 2.0h, 1.0h, 2.0h};
    
    for (int i = 0; i < 8; i++) {
        float2 offset = upOffsets[i] * params.offset * params.texel;
        sum += src.sample(smp, uv + offset) * weights[i];
    }
    
    half4 result = lowSample + sum / 12.0h;
    dst.write(result, gid);
}

vertex VertexOut vertexGlass(uint vid [[vertex_id]]) {
    constant float2 positions[6] = {
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, -1.0),
        float2(1.0, 1.0),
        float2(-1.0, 1.0)
    };
    
    constant float2 texCoords[6] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0),
        float2(0.0, 0.0)
    };
    
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.texCoord = half2(texCoords[vid]);
    return out;
}

fragment half4 fragmentGlass(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> backdrop [[texture(0)]],
    texture2d<half, access::sample> blurred [[texture(1)]],
    constant FresnelParams& params [[buffer(0)]],
    sampler smp [[sampler(0)]]
) {
    half4 backdropColor = backdrop.sample(smp, float2(in.texCoord));
    half4 blurredColor = blurred.sample(smp, float2(in.texCoord));
    
    half2 centeredUV = in.texCoord - half2(0.5h);
    half distFromCenter = length(centeredUV);
    half viewAngle = saturate(distFromCenter * 2.0h);
    
    half n1 = 1.0h;
    half n2 = params.ior;
    half F0 = pow((n1 - n2) / (n1 + n2), 2.0h);
    
    half cosTheta = 1.0h - viewAngle;
    half fresnel = F0 + (1.0h - F0) * pow(1.0h - cosTheta, 5.0h);
    fresnel *= params.fresnelStrength;
    
    half4 mixed = mix(backdropColor, blurredColor, params.blurMix);
    half4 tinted = half4(mixed.rgb * params.tintColor, mixed.a);
    
    half4 final = tinted + half4(fresnel);
    return half4(final.rgb, 1.0h);
}
