Shader "Custom/OutlineDetection"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "OutlineDetection"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Fragment
            #pragma multi_compile_fragment _ _LINEAR_TO_SRGB_CONVERSION
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma enable_d3d11_debug_symbols

            // Core.hlsl for XR dependencies
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/DebuggingFullscreen.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "./Library/Outline.hlsl"

            float4 Fragment(Varyings input) : SV_Target
            {
                return float4(DetectOutline(input.texcoord), 0, 0, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "OutlineApply"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Fragment
            #pragma multi_compile_fragment _ _LINEAR_TO_SRGB_CONVERSION
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma enable_d3d11_debug_symbols

            // Core.hlsl for XR dependencies
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "./Library/RimLight.hlsl"

            TEXTURE2D(_OutlineBuffer);
            TEXTURE2D(_ColorTargetBlit);
            static const float e = 2.71828;

            float W_f(float x, float e0, float e1)
            {
                if (x <= e0)
                    return 0;
                if (x >= e1)
                    return 1;
                float a = (x - e0) / (e1 - e0);
                return a * a * (3 - 2 * a);
            }

            float H_f(float x, float e0, float e1)
            {
                if (x <= e0)
                    return 0;
                if (x >= e1)
                    return 1;
                return (x - e0) / (e1 - e0);
            }

            float GranTurismoTonemapper(float x)
            {
                float P = 1;
                float a = 1;
                float m = 0.22;
                float l = 0.4;
                float c = 1.33;
                float b = 0;
                float l0 = (P - m) * l / a;
                float L0 = m - m / a;
                float L1 = m + (1 - m) / a;
                float L_x = m + a * (x - m);
                float T_x = m * pow(x / m, c) + b;
                float S0 = m + l0;
                float S1 = m + a * l0;
                float C2 = a * P / (P - S1);
                float S_x = P - (P - S1) * pow(e, -(C2 * (x - S0) / P));
                float w0_x = 1 - W_f(x, 0, m);
                float w2_x = H_f(x, m + l0, m + l0);
                float w1_x = 1 - w0_x - w2_x;
                float f_x = T_x * w0_x + L_x * w1_x + S_x * w2_x;
                return f_x;
            }

            float4 Fragment(Varyings input) : SV_Target
            {
                float outline = SAMPLE_TEXTURE2D_X(_OutlineBuffer, my_point_clamp_sampler, input.texcoord);

                if (outline == 0)
                {
                    float4 originCol = SAMPLE_TEXTURE2D_X(_ColorTargetBlit, my_point_clamp_sampler, input.texcoord);
                    float r = GranTurismoTonemapper(originCol.r);
                    float g = GranTurismoTonemapper(originCol.g);
                    float b = GranTurismoTonemapper(originCol.b);
                    float4 finalColor = float4(r, g, b, originCol.a);

                    float shadingModel = SAMPLE_TEXTURE2D_X(_CustomGBuffer3, my_point_clamp_sampler, input.texcoord - _ScreenSize.w).x;
                    float rimLight = 0;
                    if (shadingModel == SHADING_MODEL_SURFACE)
                    {
                        float2 rimUV = float2(input.texcoord.x, input.texcoord.y + _ScreenSize.w * 5);
                        rimLight = GetRimLight(rimUV);
                    }
                    return lerp(finalColor, finalColor * 2, rimLight);
                    return float4(rimLight.xxx, 1);
                }
                float3 color = float3(0.08, 0.062, 0.062);
                float r = GranTurismoTonemapper(color.r);
                float g = GranTurismoTonemapper(color.g);
                float b = GranTurismoTonemapper(color.b);
                return float4(r, g, b, 1);
            }
            ENDHLSL
        }
    }
}