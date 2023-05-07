#pragma once
#include "../Deferred/GBuffer.hlsl"
float4x4 _ScreenToWorld[2];

float FresnelEffect(float3 normalWS, float3 viewDirWS, float power)
{
    return pow(1.0 - saturate(dot(normalize(normalWS), viewDirWS)), power);
}

float4 _OutlineColor;
float _OutlineWeight;

half3 MixOutlineColor(half4 color, float3 normalWS, float3 viewDirWS, float3 vertexColor = float3(0, 0, 0))
{
    float outline = FresnelEffect(normalWS, viewDirWS, 2);
    #ifdef _OUTLINE_USE_VERTEX_COLOR
        outline *= vertexColor.r;
    #endif
    return lerp(color, _OutlineColor, step(1 - _OutlineWeight, outline));
}

float DetectDepthOutline(float2 leftBottomUV, float2 rightTopUV, float2 rightBottomUV, float2 leftTopUV)
{
    float _DepthThreshold = 3;
    float _DepthNormalThreshold = 0.5;
    float _DepthNormalThresholdScale = 5;
    
    float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, my_point_clamp_sampler, leftBottomUV);
    float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, my_point_clamp_sampler, rightTopUV);
    float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, my_point_clamp_sampler, rightBottomUV);
    float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, my_point_clamp_sampler, leftTopUV);
    
    float depthFiniteDifference0 = depth1 - depth0;
    float depthFiniteDifference1 = depth3 - depth2;

    float3 normal0 = SAMPLE_TEXTURE2D_X(_GBuffer2, my_point_clamp_sampler, leftBottomUV);
    float4 posWS = mul(_ScreenToWorld[0], float4(leftBottomUV * _ScreenSize, depth0, 1.0));
    posWS.xyz *= rcp(posWS.w);
    
    float NdV = dot(normalize(normal0), GetWorldSpaceNormalizeViewDir(posWS));

    float normalThreshold01 = saturate((NdV - _DepthNormalThreshold) / (1 - _DepthNormalThreshold));
    float normalThreshold = normalThreshold01 * _DepthNormalThresholdScale + 1;
    float depthThreshold = _DepthThreshold * depth0 * normalThreshold;

    float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
    edgeDepth = edgeDepth > depthThreshold ? 1 : 0;
    return edgeDepth;
}

float DetectNormalOutline(float2 leftBottomUV, float2 rightTopUV, float2 rightBottomUV, float2 leftTopUV)
{
    float _NormalThreshold = 2;

    float shadingModel = SAMPLE_TEXTURE2D_X(_CustomGBuffer3, my_point_clamp_sampler, leftBottomUV).r;
    if (shadingModel == SHADING_MODEL_FACE) return 0;

    float3 normal0 = UnpackNormal(SAMPLE_TEXTURE2D_X(_GBuffer2, my_point_clamp_sampler, leftBottomUV));
    float3 normal1 = UnpackNormal(SAMPLE_TEXTURE2D_X(_GBuffer2, my_point_clamp_sampler, rightTopUV));
    float3 normal2 = UnpackNormal(SAMPLE_TEXTURE2D_X(_GBuffer2, my_point_clamp_sampler, rightBottomUV));
    float3 normal3 = UnpackNormal(SAMPLE_TEXTURE2D_X(_GBuffer2, my_point_clamp_sampler, leftTopUV));
    
    float3 normalFiniteDifference0 = normal1 - normal0;
    float3 normalFiniteDifference1 = normal3 - normal2;

    float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
    edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;

    return edgeNormal;
}

float DetectOutline(float2 uv)
{
    float _Scale = 2;
    float halfScaleFloor = floor(_Scale * 0.5);
    float halfScaleCeil = ceil(_Scale * 0.5);

    float2 _TexelSize = _ScreenSize.zw;

    float2 leftBottomUV = uv - float2(_TexelSize.x, _TexelSize.y) * halfScaleFloor;
    float2 rightTopUV = uv + float2(_TexelSize.x, _TexelSize.y) * halfScaleCeil;  
    float2 rightBottomUV = uv + float2(_TexelSize.x * halfScaleCeil, -_TexelSize.y * halfScaleFloor);
    float2 leftTopUV = uv + float2(-_TexelSize.x * halfScaleFloor, _TexelSize.y * halfScaleCeil);
    
    float edgeDepth = DetectDepthOutline(leftBottomUV, rightTopUV, rightBottomUV, leftTopUV);
    float edgeNormal = DetectNormalOutline(leftBottomUV, rightTopUV, rightBottomUV, leftTopUV);
    float edge = max(edgeDepth, edgeNormal);
    return edge;
}