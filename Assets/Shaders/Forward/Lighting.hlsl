#pragma once
#include "../Library/Surface.hlsl"
#include "../Library/Face.hlsl"
#include "../Library/Lighting.hlsl"

#ifdef _IS_FACE
Texture2D<float> _FaceShadowMap;
SamplerState sampler_FaceShadowMap;
#endif

void SetupForwardShadowFactor(Varyings input, Light light, half3 normalWS, inout ShadowParams shadowParams)
{
    #ifdef _IS_FACE
    float defaultShadow = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, input.uv) * 2 - 1;
    half shadowFactor = GetFaceShadowFactor(defaultShadow, light.direction, TransformObjectToWorld(float3(-1, 0, 0)));
    #else
    half shadowFactor = GetSurfaceShadowFactor(light, normalWS, shadowParams);
    #endif
    shadowParams.factor = shadowFactor;
}

half4 UniversalLighting(Varyings input, InputData inputData, SurfaceData surfaceData, ILMData ilmData, ShadowParams shadowParams, SpecularParams specularParams)
{

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS);
    
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        SetupForwardShadowFactor(input, mainLight, inputData.normalWS, shadowParams);
        lightingData.mainLightColor = RenderLight(shadowParams, surfaceData, mainLight,  inputData.normalWS, inputData.viewDirectionWS);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTERED_LIGHTING
    for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            lightingData.additionalLightsColor += RenderLight(shadowParams, specularParams.color, light,  inputData.normalWS, inputData.viewDirectionWS);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    {
        lightingData.additionalLightsColor += RenderLight(shadowParams, specularParams.color, light,  inputData.normalWS, inputData.viewDirectionWS);
    }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return half4(CalculateLightingColor(lightingData, surfaceData.albedo), surfaceData.alpha);
}
