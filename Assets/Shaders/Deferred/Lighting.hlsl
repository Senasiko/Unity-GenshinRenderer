#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Deferred.hlsl"
#include "../Library/Surface.hlsl"
#include "../Library/Lighting.hlsl"
#include "./GBuffer.hlsl"

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 screenUV : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void DeferredInitializeSurfaceData(GBufferData gBufferData, inout SurfaceData surfaceData)
{
    surfaceData.metallic = gBufferData.metallic * 0.6;
    half oneMinusReflectivity = OneMinusReflectivityMetallic(surfaceData.metallic);
    surfaceData.albedo = gBufferData.albedo * oneMinusReflectivity;
    surfaceData.specular = lerp(kDieletricSpec.rgb, gBufferData.albedo, gBufferData.metallic);
}

void DeferredInitializeShadowParams(GBufferData gBufferData, inout ShadowParams shadowParams, Light light)
{
    [BRANCH]
    if (gBufferData.shadingModel == SHADING_MODEL_SURFACE)
    {
        shadowParams.color = 0;
        shadowParams.mid = gBufferData.customData.r;
        shadowParams.hardness = gBufferData.customData.g;
        shadowParams.factor = light.shadowAttenuation * GetSurfaceShadowFactor(light, gBufferData.normal, shadowParams);
    } else if (gBufferData.shadingModel == SHADING_MODEL_FACE)
    {
        shadowParams.factor = light.shadowAttenuation * GetFaceShadowFactor(gBufferData.customData.r, light.direction, half3(gBufferData.customData.gb, 0));
    } else
    {
        shadowParams.factor = light.shadowAttenuation * saturate(dot(gBufferData.normal, light.direction));
    }
}

half3 MixShadow(half shadingModel, half3 color, half shadowFactor)
{
    if (shadingModel == SHADING_MODEL_SURFACE)
    {
        return lerp(color * 0.3, color, shadowFactor);
    }
    if (shadingModel == SHADING_MODEL_FACE)
    {
        return lerp(color * 0.3, color, shadowFactor);
    }
    return color * shadowFactor;
}

half4 AnimeDeferredLighting(GBufferData gBufferData, Light light, half3 viewDirectionWS) 
{
    // InputData inputData, SurfaceData surfaceData, ILMData ilmData, Light light, ShadowParams shadowParams, SpecularParams specularParams
    SurfaceData surfaceData = (SurfaceData)0;
    DeferredInitializeSurfaceData(gBufferData, surfaceData);
    ShadowParams shadowParams = (ShadowParams)0;
    DeferredInitializeShadowParams(gBufferData, shadowParams, light);
    // return half4(1,1,0,1);
    // RenderLight(shadowParams, gBufferData.specular, light, gBufferData.normal, viewDirectionWS)
    #if defined(_DIRECTIONAL) && defined(_DEFERRED_FIRST_LIGHT)
    // half3 diffuseColor = CalcDiffuse(shadowParams, light);
    float specularTerm = CalcSpecularTerm(surfaceData.metallic, light.direction, viewDirectionWS, gBufferData.normal);
    half3 finalColor = lerp(surfaceData.albedo, surfaceData.specular, specularTerm);
    return half4(finalColor * 0.5 + MixShadow(gBufferData.shadingModel, finalColor, shadowParams.factor), 1); 
    #else
    half3 finalColor = RenderLight(shadowParams, surfaceData.specular, light, gBufferData.normal, viewDirectionWS);
    return half4(MixShadow(gBufferData.shadingModel, finalColor, shadowParams.factor), 1); 
    #endif

}