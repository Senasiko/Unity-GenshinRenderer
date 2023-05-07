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
    surfaceData.metallic = gBufferData.metallic;
    if ((gBufferData.materialFlags & kMaterialFlagSpecularSetup) != 0)
    {
        surfaceData.albedo = gBufferData.albedo;
        surfaceData.specular = gBufferData.specular;
    } else
    {
        surfaceData.albedo = lerp(gBufferData.albedo, pow(gBufferData.albedo, gBufferData.metallic + 2), gBufferData.metallic);
        surfaceData.specular = gBufferData.albedo;
    }
}

void DeferredInitializeShadowParams(GBufferData gBufferData, SurfaceData surfaceData, Light light, inout ShadowParams shadowParams)
{
    [BRANCH]
    if (gBufferData.shadingModel == SHADING_MODEL_SURFACE)
    {
        shadowParams.color = surfaceData.albedo * 0.6;
        shadowParams.mid = gBufferData.customData.r;
        shadowParams.bIsRamp = gBufferData.customData.g;
        shadowParams.hardness = gBufferData.customData.b / 1.3;
        shadowParams.factor = GetSurfaceShadowFactor(light, gBufferData.normal, shadowParams);

        if (shadowParams.bIsRamp == 1)
        {
            float3 rampShadowColor = GetRampShadowColor(smoothstep(0, 1, 1 - shadowParams.factor));
            shadowParams.color = lerp(shadowParams.color, rampShadowColor, smoothstep(0, 1, shadowParams.factor));   
        }   
    } else if (gBufferData.shadingModel == SHADING_MODEL_FACE)
    {
        shadowParams.color = pow(surfaceData.albedo, 1.3);
        shadowParams.factor = light.shadowAttenuation * GetFaceShadowFactor(gBufferData.customData.r, light.direction, half3(gBufferData.customData.gb, 0));
    } else
    {
        shadowParams.factor = light.shadowAttenuation * saturate(dot(gBufferData.normal, light.direction));
    }
}

half3 AnimeDeferredLighting(GBufferData gBufferData, Light light, half3 viewDirectionWS) 
{
    // InputData inputData, SurfaceData surfaceData, ILMData ilmData, Light light, ShadowParams shadowParams, SpecularParams specularParams
    SurfaceData surfaceData = (SurfaceData)0;
    DeferredInitializeSurfaceData(gBufferData, surfaceData);
    ShadowParams shadowParams = (ShadowParams)0;
    DeferredInitializeShadowParams(gBufferData, surfaceData, light, shadowParams);
    
    #if defined(_DIRECTIONAL) && defined(_DEFERRED_FIRST_LIGHT)
    // half3 diffuseColor = CalcDiffuse(shadowParams, light);
    float specularTerm = CalcSpecularTerm(surfaceData.metallic, light.direction, viewDirectionWS, gBufferData.normal);
    float3 finalColor = surfaceData.albedo + specularTerm * surfaceData.specular;
    finalColor = lerp(shadowParams.color, finalColor, shadowParams.factor);
    return finalColor; 
    #else
    half3 finalColor = RenderLight(shadowParams, surfaceData, light, gBufferData.normal, viewDirectionWS);
    return finalColor; 
    #endif
}