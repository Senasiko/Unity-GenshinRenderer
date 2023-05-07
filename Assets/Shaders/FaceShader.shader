Shader "Custom/FaceShader"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        _BaseColorIntensity ("BaseColorIntensity", Float) = 1
        _ShadowColor ("ShadowColor", Color) = (0.5, 0.5, 0.5, 0.5)
        _FaceShadowMap("_ShadowTex", 2D) = "black" {}
        _ShadowHardness ("ShadowHardness", Range(0,1)) = 0.3
        [MainTexture]_BaseMap("_BaseTex (Albedo)", 2D) = "white" {}
    }
    
    HLSLINCLUDE
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile_fragment _ _SHADOWS_SOFT
        #pragma multi_compile_fragment _ _SPECULAR_SETUP
        #pragma enable_d3d11_debug_symbols

        #define _IS_FACE
    ENDHLSL
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }
        LOD 200

        Pass {
            Name "ForwardLit"
            
            Tags {
                "LightMode" = "UniversalForward"
            } 
            
            Cull Back
            ZTest LEqual
            ZWrite On
            Blend One Zero
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            #include "./Library/Surface.hlsl"
            #include "./Forward/Lighting.hlsl"

            Varyings vert(Attributes input)
            {
                return LitPassVertex(input);
            }

            float _BaseColorIntensity;
            half4 frag(Varyings input) : SV_Target
            {
                 UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if defined(_PARALLAXMAP)
                #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                    half3 viewDirTS = input.viewDirTS;
                #else
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
                #endif
                    ApplyPerPixelDisplacement(viewDirTS, input.uv);
                #endif

                ILMData ilmData;
                InitializeILMData(input.uv, ilmData);
                
                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(input.uv, surfaceData);
                surfaceData.albedo *= _BaseColorIntensity;

                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, inputData);
                
                ShadowParams shadowParams;
                InitializeShadowParams(shadowParams);

                SpecularParams specularParams;
                InitializeSpecularParams(input.uv, ilmData, specularParams);
                
                SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
                half4 color = UniversalLighting(input, inputData, surfaceData, ilmData, shadowParams, specularParams);

                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                color.a = OutputAlpha(color.a, _Surface);
                
                return color;

            }
            ENDHLSL
        }
        
         Pass {
            Name "GBuffer"
            
            Tags {
                "LightMode" = "UniversalGBuffer"
            } 
            
            Cull Back
            ZTest LEqual
            ZWrite On
            Blend One Zero
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #define _IS_FACE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
            #include "./Deferred/GBuffer.hlsl"
            #include "./Deferred/ShadingModel.hlsl"
            #include "./Library/Surface.hlsl"
            
            Varyings vert(Attributes input)
            {
                return LitGBufferPassVertex(input);
            }

            float _BaseColorIntensity;
            Texture2D<float> _FaceShadowMap;
            SamplerState sampler_FaceShadowMap;
            
            EncodedGBufferData frag(Varyings input)
            {
                 UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if defined(_PARALLAXMAP)
                #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                    half3 viewDirTS = input.viewDirTS;
                #else
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
                #endif
                    ApplyPerPixelDisplacement(viewDirTS, input.uv);
                #endif

                half defaultShadow = SAMPLE_TEXTURE2D_X_LOD(_FaceShadowMap, sampler_FaceShadowMap, input.uv, 0);

                ILMData ilmData;
                InitializeILMData(input.uv, ilmData);
                
                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(input.uv, surfaceData);

                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, inputData);
                
                SpecularParams specularParams;
                InitializeSpecularParams(input.uv, ilmData, specularParams);
                
                surfaceData.albedo *= _BaseColorIntensity;
                surfaceData.metallic = ilmData.metallic;
                surfaceData.specular = specularParams.color;
                // surfaceData.smoothness = ilmData.metallic * 0.3;
                SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
                half2 rightDirWS = TransformObjectToWorld(float3(-1, 0, 0));
                return EncodeGBuffer(inputData, surfaceData, surfaceData.albedo + surfaceData.emission, SHADING_MODEL_FACE, half3(defaultShadow, rightDirWS));
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
