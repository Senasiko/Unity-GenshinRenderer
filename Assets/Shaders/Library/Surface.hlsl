#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "./Face.hlsl"

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
void InitializeShadowParams(out ShadowParams shadowParams)
{
    shadowParams.color = _ShadowColor;
    shadowParams.mid = _ShadowMid;
    shadowParams.hardness = _ShadowHardness;
    shadowParams.factor = 0;
}

float3 _SpecularColor;
float _SpecularIntensity;
void InitializeSpecularParams(ILMData ilmData, out SpecularParams specularParams)
{
    specularParams.color = _SpecularColor * _SpecularIntensity * ilmData.specular;
}

half GetSurfaceShadowFactor(Light light, half3 normalWS, ShadowParams shadowParams)
{
    half3 N = normalWS;
    half3 L = light.direction;
    half NoL = dot(N,L);
    half shadowFactor = smoothstep(shadowParams.mid-shadowParams.hardness, shadowParams.mid+shadowParams.hardness, NoL);
    shadowFactor *= light.shadowAttenuation;
    return shadowFactor;
}