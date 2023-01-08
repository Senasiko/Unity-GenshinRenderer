#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

float GetFaceShadowFactor(float defaultShadow, half3 lightDirectionWS, half3 rightDirectionWS)
{
    // float3 objectLightDir = TransformWorldToObject(lightDirectionWS);
    // // float3 shadowDir = cross(float3(1, 0, 0), float3(objectLightDir.x, objectLightDir.y, 0));
    // // shadowDir /= abs(shadowDir);
    // // float fac = (1 - dot(objectLightDir, half3(0, -1, 0))) * shadowDir.z;
    float rol = clamp(-1, 1, dot(normalize(lightDirectionWS), normalize(rightDirectionWS)));
    if (rol > 0)
    {
        return step(rol, 1 - defaultShadow);
    }
    return step(-rol, defaultShadow);
    // float y = dot(objectLightDir, half3(0, -1, 0));
    // float isFront = (y + abs(y)) / abs(y) / 2;
    // float shadowFactor = fac < 0 ? step(-fac, 1 - defaultShadow) : step(fac, defaultShadow);
    // return shadowFactor * isFront * 0.5;
    // return (1 - fac < 0 ? -fac - defaultShadow : fac - defaultShadow);
}
