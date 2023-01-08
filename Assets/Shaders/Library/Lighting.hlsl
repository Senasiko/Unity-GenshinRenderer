#pragma once
#include "./Surface.hlsl"
#include "./Face.hlsl"
float CalcSpecularTerm(float metallic, half3 lightDirectionWS, half3 viewDirectionWS, half3 normalWS)
{
    float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
    float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

    float NoH = saturate(dot(float3(normalWS), halfDir));
    half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

    float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(metallic);
    float roughness           = max(PerceptualRoughnessToRoughness(perceptualRoughness), HALF_MIN_SQRT);
    float roughness2          = max(roughness * roughness, HALF_MIN);
    float normalizationTerm   = roughness * half(4.0) + half(2.0);
    float roughness2MinusOne  = roughness2 - half(1.0);
    float d = NoH * NoH * roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * normalizationTerm);

    return saturate(specularTerm);
}

half3 CalcDiffuse(ShadowParams shadowParams, Light light)
{
    return lerp(shadowParams.color, saturate(light.color), shadowParams.factor);
}

half3 RenderLight(ShadowParams shadowParams, half3 specularColor, Light light, half3 normalWS, half3 viewDirectionWS )
{
    half distanceAttenuation = min(1,light.distanceAttenuation);
    return distanceAttenuation * CalcDiffuse(shadowParams, light);
}
