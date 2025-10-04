//
//  GlassEffects.metal
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Input Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float2 screenPos;
};

// MARK: - Uniforms

struct GlassUniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float2 resolution;
    float time;
    float intensity;
    float blurAmount;
    float distortionStrength;
    float4 tintColor;
};

// MARK: - Vertex Shader

vertex VertexOut glassVertexShader(const VertexIn in [[stage_in]],
                                  constant GlassUniforms& uniforms [[buffer(0)]]) {
    VertexOut out;
    
    // Transform position
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    
    // Pass through texture coordinates
    out.texCoord = in.texCoord;
    
    // Calculate screen position for effects
    out.screenPos = out.position.xy / uniforms.resolution;
    
    return out;
}

// MARK: - Fragment Shader

fragment float4 glassFragmentShader(VertexOut in [[stage_in]],
                                    texture2d<float> texture [[texture(0)]],
                                    texture2d<float> noiseTexture [[texture(1)]],
                                    sampler textureSampler [[sampler(0)]],
                                    sampler noiseSampler [[sampler(1)]],
                                    constant GlassUniforms& uniforms [[buffer(0)]]) {
    
    // Sample base texture
    float4 baseColor = texture.sample(textureSampler, in.texCoord);
    
    // Sample noise for distortion
    float2 noiseCoord = in.texCoord + uniforms.time * 0.1;
    float4 noise = noiseTexture.sample(noiseSampler, noiseCoord);
    
    // Apply distortion
    float2 distortedCoord = in.texCoord;
    distortedCoord.x += sin(in.texCoord.y * 10.0 + uniforms.time) * uniforms.distortionStrength * noise.r;
    distortedCoord.y += cos(in.texCoord.x * 10.0 + uniforms.time) * uniforms.distortionStrength * noise.g;
    
    // Sample distorted texture
    float4 distortedColor = texture.sample(textureSampler, distortedCoord);
    
    // Apply blur effect
    float4 blurredColor = float4(0.0);
    float blurSize = uniforms.blurAmount / uniforms.resolution.x;
    int blurSamples = 5;
    
    for (int i = -blurSamples; i <= blurSamples; i++) {
        for (int j = -blurSamples; j <= blurSamples; j++) {
            float2 offset = float2(i, j) * blurSize;
            blurredColor += texture.sample(textureSampler, in.texCoord + offset);
        }
    }
    blurredColor /= float((blurSamples * 2 + 1) * (blurSamples * 2 + 1));
    
    // Create glass effect
    float4 glassColor = mix(distortedColor, blurredColor, uniforms.intensity);
    
    // Apply tint
    glassColor.rgb = mix(glassColor.rgb, uniforms.tintColor.rgb, uniforms.tintColor.a * 0.3);
    
    // Add refraction effect
    float2 refractedCoord = in.texCoord + (noise.rg - 0.5) * 0.02 * uniforms.intensity;
    float4 refractedColor = texture.sample(textureSampler, refractedCoord);
    glassColor = mix(glassColor, refractedColor, 0.3);
    
    // Add edge glow
    float edgeFactor = length(in.texCoord - float2(0.5)) * 2.0;
    float glow = 1.0 - smoothstep(0.8, 1.0, edgeFactor);
    glassColor.rgb += glow * uniforms.tintColor.rgb * 0.2;
    
    return glassColor;
}

// MARK: - Liquid Glass Effect

fragment float4 liquidGlassFragmentShader(VertexOut in [[stage_in]],
                                          texture2d<float> texture [[texture(0)]],
                                          texture2d<float> noiseTexture [[texture(1)]],
                                          sampler textureSampler [[sampler(0)]],
                                          sampler noiseSampler [[sampler(1)]],
                                          constant GlassUniforms& uniforms [[buffer(0)]]) {
    
    // Enhanced liquid glass effect with time-based animation
    float2 uv = in.texCoord;
    
    // Create flowing liquid effect
    float2 flowUV = uv;
    flowUV.x += sin(uv.y * 8.0 + uniforms.time * 2.0) * 0.02;
    flowUV.y += cos(uv.x * 6.0 + uniforms.time * 1.5) * 0.02;
    
    // Sample noise for liquid distortion
    float4 noise1 = noiseTexture.sample(noiseSampler, flowUV + uniforms.time * 0.05);
    float4 noise2 = noiseTexture.sample(noiseSampler, flowUV * 1.5 - uniforms.time * 0.03);
    
    // Combine noise layers
    float liquidNoise = (noise1.r + noise2.g) * 0.5;
    
    // Apply liquid distortion
    float2 liquidUV = uv;
    liquidUV += (noise1.rg - 0.5) * 0.03 * uniforms.intensity;
    liquidUV += (noise2.rg - 0.5) * 0.02 * uniforms.intensity;
    
    // Sample base texture with liquid distortion
    float4 baseColor = texture.sample(textureSampler, liquidUV);
    
    // Create liquid transparency effect
    float transparency = 0.7 + liquidNoise * 0.3 * uniforms.intensity;
    
    // Apply liquid blur
    float4 liquidBlur = float4(0.0);
    float liquidBlurSize = uniforms.blurAmount * 1.5 / uniforms.resolution.x;
    int liquidSamples = 7;
    
    for (int i = -liquidSamples; i <= liquidSamples; i++) {
        for (int j = -liquidSamples; j <= liquidSamples; j++) {
            float2 offset = float2(i, j) * liquidBlurSize;
            float2 sampleUV = liquidUV + offset;
            sampleUV += sin(sampleUV * 10.0 + uniforms.time) * 0.01;
            liquidBlur += texture.sample(textureSampler, sampleUV);
        }
    }
    liquidBlur /= float((liquidSamples * 2 + 1) * (liquidSamples * 2 + 1));
    
    // Combine effects
    float4 finalColor = mix(baseColor, liquidBlur, uniforms.intensity * 0.6);
    finalColor.a = transparency;
    
    // Add liquid shimmer
    float shimmer = sin(uv.x * 20.0 + uniforms.time * 3.0) * cos(uv.y * 15.0 + uniforms.time * 2.0);
    finalColor.rgb += shimmer * 0.05 * uniforms.intensity;
    
    return finalColor;
}

// MARK: - Frosted Glass Effect

fragment float4 frostedGlassFragmentShader(VertexOut in [[stage_in]],
                                           texture2d<float> texture [[texture(0)]],
                                           texture2d<float> noiseTexture [[texture(1)]],
                                           sampler textureSampler [[sampler(0)]],
                                           sampler noiseSampler [[sampler(1)]],
                                           constant GlassUniforms& uniforms [[buffer(0)]]) {
    
    float2 uv = in.texCoord;
    
    // Create frosted effect with multiple noise samples
    float4 frostedColor = float4(0.0);
    float frostedBlur = uniforms.blurAmount * 2.0 / uniforms.resolution.x;
    int frostedSamples = 9;
    
    for (int i = -frostedSamples; i <= frostedSamples; i++) {
        for (int j = -frostedSamples; j <= frostedSamples; j++) {
            float2 offset = float2(i, j) * frostedBlur;
            
            // Add random noise for frosted effect
            float4 noise = noiseTexture.sample(noiseSampler, uv + offset * 0.1);
            float2 randomOffset = (noise.rg - 0.5) * frostedBlur * 0.5;
            
            frostedColor += texture.sample(textureSampler, uv + offset + randomOffset);
        }
    }
    frostedColor /= float((frostedSamples * 2 + 1) * (frostedSamples * 2 + 1));
    
    // Add frost crystallization effect
    float4 frostNoise = noiseTexture.sample(noiseSampler, uv * 5.0);
    float crystallization = step(0.7, frostNoise.r);
    frostedColor.rgb += crystallization * 0.1;
    
    // Apply frost tint
    frostedColor.rgb = mix(frostedColor.rgb, float3(0.9, 0.95, 1.0), 0.1);
    
    return frostedColor;
}