#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Deferred.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
#include "../../../Shaders/Deferred/GBuffer.hlsl"

uint _SSRMaxStep;
float _SSRMaxDistance;
float _SSRStepSize;

float3 GetSSRColor(float4 color, GBufferData gBufferData, half3 viewDirectionWS, half3 positionWS)
{
    half3 finalCol = color;
    half3 reflectDir = reflect(-viewDirectionWS, gBufferData.normal);
    half originDepth = gBufferData.depth;

    UNITY_LOOP
    for(int i = 0; i <= _SSRMaxStep; i++)
    {
        float3 reflPos = positionWS + reflectDir * _SSRStepSize * i;
        
        if(length(reflPos - positionWS) > _SSRMaxDistance) break;
        
        float4 reflPosCS = TransformWorldToHClip(reflPos);
        uint2 reflUV = GetNormalizedScreenSpaceUV(reflPosCS);
        float reflDepth = _CameraDepthTexture[reflUV.xy].x; 
        
        if(reflUV.x > 0.0 && reflUV.y > 0.0 && reflUV.x < 1.0 && reflUV.y < 1.0 && originDepth >= reflDepth && reflDepth > reflPosCS.z)
        {
            finalCol = _GBuffer0[reflUV.xy];
            break;
        }
                        
    } 
    return finalCol;
}