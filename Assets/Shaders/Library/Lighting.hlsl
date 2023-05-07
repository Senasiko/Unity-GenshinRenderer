#pragma once
#include "../Deferred/GBuffer.hlsl"
#include "./Surface.hlsl"
#include "./Face.hlsl"

TEXTURE2D(_MatMap);

float CalcSpecularTerm(float metallic, half3 lightDirectionWS, half3 viewDirectionWS, half3 normalWS)
{
    float2 normalVS = TransformWorldToViewDir(normalWS) * 0.5 + 0.5;
    return SAMPLE_TEXTURE2D_X(_MatMap, my_point_clamp_sampler, normalVS) * metallic;

    float2 metallicUV = dot(normalWS, normalize(lightDirectionWS + viewDirectionWS));

    return  metallicUV.x * metallic;
    float NdV = dot(normalWS, viewDirectionWS); 
    float NdL = dot(normalWS, lightDirectionWS);


    return (smoothstep(0.7, 0.8, metallicUV.y) * 0.7 + smoothstep(0.3, 0.4, metallicUV.y) * 0.3) * metallic;
}


half3 CalcDiffuse(ShadowParams shadowParams, Light light)
{
    return lerp(shadowParams.color, saturate(light.color), shadowParams.factor);
}

half3 RenderLight(ShadowParams shadowParams, SurfaceData surfaceData, Light light, half3 normalWS, half3 viewDirectionWS )
{
    half distanceAttenuation = min(1,light.distanceAttenuation);
    half3 diffuseColor = CalcDiffuse(shadowParams, light);
    return distanceAttenuation * diffuseColor;
}
