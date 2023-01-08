Shader "Custom/OutlineShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        [Header(Outline)]
        [Space(10)][Toggle(_OUTLINE)] _OUTLINE ("Outline", Float) = 1
        [Toggle(_OUTLINE_USE_VERTEX_COLOR)] _OUTLINE_USE_VERTEX_COLOR ("Outline Use Vertex olor", Float) = 1
        _OutlineColor ("OutlineColor", Color) = (0, 0, 0, 1)
        _OutlineWeight ("OutlineWeight", Range(0, 1)) = 0.01
    }
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }
        LOD 200

        Pass {
            Name "Lit"
            
            Tags {
                "LightMode" = "UniversalForward"
            }
            
            Cull Back
            ZTest LEqual
            ZWrite On
            Blend One Zero
            
            HLSLPROGRAM

            #pragma shader_feature_fragment _ _OUTLINE
            #pragma shader_feature_fragment _ _OUTLINE_USE_VERTEX_COLOR
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SPECULAR_SETUP 
            #pragma enable_d3d11_debug_symbols

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            #include "./Library/Outline.hlsl"
            
            struct OutlineAttributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                float3 outlineWeight : COLOR;
                float2 staticLightmapUV   : TEXCOORD1;
                float2 dynamicLightmapUV  : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct OutlineVaryings
            {
                float2 uv                       : TEXCOORD0;
                float outlineWeight              : OUTLINE_WEIGHT;
                float3 positionWS               : TEXCOORD1;
                float3 normalWS                 : TEXCOORD2;
                float3 viewDirWS                : TEXCOORD3;
                float4 positionCS               : SV_POSITION;
            };

                
            OutlineVaryings vert(OutlineAttributes input)
            {
                OutlineVaryings output;
                Attributes vertexInput;
                vertexInput.texcoord = input.texcoord;
                vertexInput.positionOS = input.positionOS;
                vertexInput.normalOS = input.normalOS;
                vertexInput.tangentOS = input.tangentOS;
                vertexInput.texcoord = input.texcoord;
                vertexInput.staticLightmapUV = input.staticLightmapUV;
                vertexInput.dynamicLightmapUV = input.dynamicLightmapUV;
                Varyings baseOutput = LitPassVertex(vertexInput);
                output.uv = baseOutput.uv;
                output.normalWS = baseOutput.normalWS;
                output.positionWS = baseOutput.positionWS;
                output.viewDirWS = baseOutput.viewDirWS;
                output.positionCS = baseOutput.positionCS;
                output.outlineWeight = input.outlineWeight;
                
                return output;
            }

            float4 _Color;
            half4 frag (OutlineVaryings input): SV_TARGET
            {
                // return half4(input.outlineWeight, 0, 0, 0);
                #ifdef _OUTLINE
                    return half4(MixOutlineColor(_Color, input.normalWS, GetWorldSpaceNormalizeViewDir(input.positionWS), input.outlineWeight), 1);
                #endif
                return half4(1,1,1,1);
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
