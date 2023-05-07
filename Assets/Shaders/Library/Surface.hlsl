#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct ILMData
{
    half metallic;
    half shadow;
    half specular;
};

struct ShadowParams
{
    half3 color;
    half mid;
    half hardness;
    half factor;
    uint bIsRamp;
};

struct SpecularParams
{
    half3 color;
};

Texture2D _ILMTexture;
SamplerState sampler_ILMTexture;

void InitializeILMData(float2 uv, out ILMData ilmData)
{
    half4 ilm = SAMPLE_TEXTURE2D(_ILMTexture, sampler_ILMTexture, uv);
    ilmData.metallic = ilm.r;
    ilmData.shadow = ilm.g;
    ilmData.specular = ilm.b;
}

float3 _ShadowColor;
float _ShadowMid;
float _ShadowHardness;
float _IsRampShadow;
void InitializeShadowParams(out ShadowParams shadowParams)
{
    shadowParams.color = _ShadowColor;
    shadowParams.mid = _ShadowMid;
    shadowParams.hardness = _ShadowHardness;
    shadowParams.factor = 0;
    shadowParams.bIsRamp = _IsRampShadow;
}

float3 _SpecularColor;
float _SpecularIntensity;
Texture2D _MetalMap;
SamplerState sampler_MetalMap;
void InitializeSpecularParams(float2 uv, ILMData ilmData, out SpecularParams specularParams)
{
    // specularParams.color = _SpecularColor * _SpecularIntensity * ilmData.specular;
    specularParams.color = SAMPLE_TEXTURE2D(_MetalMap, sampler_MetalMap, uv);
}

half GetSurfaceShadowFactor(Light light, half3 normalWS, ShadowParams shadowParams)
{
    half3 N = normalWS;
    half3 L = light.direction;
    half NoL = dot(N,L);
    half shadowFactor = smoothstep(shadowParams.mid - shadowParams.hardness, shadowParams.mid + shadowParams.hardness, NoL * 4);
    shadowFactor *= light.shadowAttenuation;
    return shadowFactor;
}

Texture2D _ShadowRampMap;
SamplerState sampler_ShadowRampMap;

float3 GetRampShadowColor(float y)
{
    float3 color = SAMPLE_TEXTURE2D(_ShadowRampMap, sampler_ShadowRampMap, float2(y, 0));
    return color;
}