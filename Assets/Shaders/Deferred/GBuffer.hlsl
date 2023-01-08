#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
#include "./ShadingModel.hlsl"

#undef GBUFFER_SHADOWMASK
#define GBUFFER_SHADOWMASK GBuffer5

#undef GBUFFER_LIGHT_LAYERS
#define GBUFFER_LIGHT_LAYERS GBuffer6


TEXTURE2D_X(_CameraDepthTexture);
TEXTURE2D_X_HALF(_GBuffer0);
TEXTURE2D_X_HALF(_GBuffer1);
TEXTURE2D_X_HALF(_GBuffer2);
TEXTURE2D_X(_CustomGBuffer3);
SamplerState my_point_clamp_sampler;

#if _RENDER_PASS_ENABLED

#define GBUFFER0 0
#define GBUFFER1 1
#define GBUFFER2 2
#define GBUFFER3 3

FRAMEBUFFER_INPUT_HALF(GBUFFER0);
FRAMEBUFFER_INPUT_HALF(GBUFFER1);
FRAMEBUFFER_INPUT_HALF(GBUFFER2);
FRAMEBUFFER_INPUT_FLOAT(GBUFFER3);
#else
#ifdef GBUFFER_OPTIONAL_SLOT_1
TEXTURE2D_X_HALF(_GBuffer4);
#endif
#endif

#if defined(GBUFFER_OPTIONAL_SLOT_2) && _RENDER_PASS_ENABLED
TEXTURE2D_X_HALF(_GBuffer5);
#elif defined(GBUFFER_OPTIONAL_SLOT_2)
TEXTURE2D_X(_GBuffer5);
#endif
#ifdef GBUFFER_OPTIONAL_SLOT_3
TEXTURE2D_X(_GBuffer6);
#endif

#define kMaterialFlagSSR            16

struct EncodedGBufferData
{
    half4 GBuffer0 : SV_Target0; // diffuse           diffuse         diffuse         materialFlags   (sRGB rendertarget)
    half4 GBuffer1 : SV_Target1; // metallic          specular        specular-color   occlusion
    half4 GBuffer2 : SV_Target2; // encoded-normal    encoded-normal  encoded-normal  smoothness
    // half4 GBuffer3 : SV_Target3; // GI                GI              GI              [optional: see OutputAlpha()] (lighting buffer)
    half4 GBuffer3 : SV_Target3; // shading_model     custom-data     custom-data     custom-data 
    #ifdef OUTPUT_SHADOWMASK
    half4 GBUFFER_SHADOWMASK : SV_Target5;
    #endif
    #ifdef _LIGHT_LAYERS
    half4 GBUFFER_LIGHT_LAYERS : SV_Target6;
    #endif
};

struct GBufferData
{
    float depth;
    half3 albedo;
    half metallic;
    half3 specular;
    half3 normal;
    half smoothness; 
    half3 GI;
    half shadingModel;
    half3 customData;
    uint materialFlags;
};

EncodedGBufferData EncodeGBuffer(InputData inputData, SurfaceData surfaceData, uint flags, uint shadingModel, float3 customData = float3(0, 0, 0))
{
    EncodedGBufferData buffer = (EncodedGBufferData)0;
    half3 packedNormalWS = PackNormal(inputData.normalWS);
    
    uint materialFlags = 0;

    materialFlags |= flags;
    
    #ifdef _RECEIVE_SHADOWS_OFF
    materialFlags |= kMaterialFlagReceiveShadowsOff;
    #endif
    
    half3 packedSpecular;
    
    #ifdef _SPECULAR_SETUP
    materialFlags |= kMaterialFlagSpecularSetup;
    packedSpecular = surfaceData.specular.rgb;
    #else
    packedSpecular.r = surfaceData.metallic;
    packedSpecular.gb = 0.0;
    #endif

    #ifdef _SPECULARHIGHLIGHTS_OFF
    // During the next deferred shading pass, we don't use a shader variant to disable specular calculations.
    // Instead, we can either silence specular contribution when writing the gbuffer, and/or reserve a bit in the gbuffer
    // and use this during shading to skip computations via dynamic branching. Fastest option depends on platforms.
    materialFlags |= kMaterialFlagSpecularHighlightsOff;
    packedSpecular = 0.0.xxx;
    #endif
    
    #if defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
    materialFlags |= kMaterialFlagSubtractiveMixedLighting;
    #endif
    
    buffer.GBuffer0 = half4(surfaceData.albedo.rgb, PackMaterialFlags(materialFlags));  // diffuse           diffuse         diffuse         materialFlags   (sRGB rendertarget)
    buffer.GBuffer1 = half4(packedSpecular, surfaceData.occlusion);                              // metallic/specular specular        specular        occlusion
    buffer.GBuffer2 = half4(packedNormalWS, surfaceData.smoothness);                             // encoded-normal    encoded-normal  encoded-normal  smoothness
    buffer.GBuffer3 = half4(shadingModel,  customData);
    #if OUTPUT_SHADOWMASK
    output.GBUFFER_SHADOWMASK = inputData.shadowMask; // will have unity_ProbesOcclusion value if subtractive lighting is used (baked)
    #endif
    #ifdef _LIGHT_LAYERS
    uint renderingLayers = GetMeshRenderingLightLayer();
    // Note: we need to mask out only 8bits of the layer mask before encoding it as otherwise any value > 255 will map to all layers active
    buffer.GBUFFER_LIGHT_LAYERS = float4((renderingLayers & 0x000000FF) / 255.0, 0.0, 0.0, 0.0);
    #endif

    return buffer;
}

GBufferData DecodeGBuffer(float depth, half4 gbuffer0, half4 gbuffer1, half4 gbuffer2, half4 gbuffer3)
{
    GBufferData buffer = (GBufferData)0;
    buffer.depth = depth;
    buffer.albedo = half3(gbuffer0.rgb);
    buffer.materialFlags = UnpackMaterialFlags(gbuffer0.a);
    buffer.normal = UnpackNormal(gbuffer2.xyz);
    buffer.smoothness = gbuffer2.w;
    buffer.customData = gbuffer3.yzw;
    buffer.shadingModel = gbuffer3.x;

    if ((buffer.materialFlags & kMaterialFlagSpecularSetup) != 0)
    {
        buffer.metallic = 0;
        buffer.specular = gbuffer1.rgb;
    }
    else
    {
        buffer.metallic = gbuffer1.r;
        buffer.specular = 0;
    }
    return buffer;
}

