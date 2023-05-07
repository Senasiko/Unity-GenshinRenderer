#pragma once
#include "../Deferred/GBuffer.hlsl"

static float2 RimSamplePoints[9] = {
    float2(-1, 1), float2(0, 1), float2(1, 1),
    float2(-1, 0), float2(0, 0), float2(1, 0),
    float2(-1, -1), float2(0, -1), float2(1, -1),
};

static float RimXMatrix[9] = {
    1, 0, -1,
    2, 0, -2,
    1, 0, -1,
};

static float RimYMatrix[9] = {
    -1, -2, -1,
    0, 0, 0,
    1, 2, 1,
};

float GetRimLight(float2 uv)
{
    float _Thickness = 0.001;
    float2 rim = 0;
    for (int i = 0; i < 9; ++i)
    {
        float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, my_point_clamp_sampler, uv + RimSamplePoints[i] * _Thickness);
        rim += depth * float2(RimXMatrix[i], RimYMatrix[i]);
    }

    return length(rim);
}