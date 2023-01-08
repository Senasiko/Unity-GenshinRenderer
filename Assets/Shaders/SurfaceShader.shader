Shader "Custom/SurfaceShader"
{
    Properties
    {
        [Enum(Surface, 1, Face, 2)]_ShadingModel("ShadingModel", Float) = 1
        [MainTexture]_BaseMap("BaseTex", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        _BaseColorIntensity ("BaseColorIntensity", Float) = 1
        // Shadow
        _ShadowColor ("ShadowColor", Color) = (0.5, 0.5, 0.5, 0.5)
        _ShadowMid ("ShadowMid", Range(0,1)) = 0.5
        _ShadowHardness ("ShadowHardness", Range(0,1)) = 0.3
        // Specular
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _SpecularIntensity ("SpecularIntensity", Float) = 2
        _ILMTexture("ILMTex ", 2D) = "white" {}
        // Outline
        [Header(Outline)]
        [Space(10)][Toggle(_OUTLINE)] _OUTLINE ("Outline", Float) = 1
        _OutlineColor ("OutlineColor", Color) = (0, 0, 0, 1)
        _OutlineWeight ("OutlineWeight", Range(0, 1)) = 0.01
    }

    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 200
        
        HLSLINCLUDE
            #pragma shader_feature_fragment _ _OUTLINE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SPECULAR_SETUP
            #pragma enable_d3d11_debug_symbols
        ENDHLSL
        Pass {
            Name "Lit"
            
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

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "./Library/Surface.hlsl"
            #include "./Library/Outline.hlsl"
            #include "./Deferred/GBuffer.hlsl"
            
            Varyings vert(Attributes input)
            {
                return LitGBufferPassVertex(input);
            }

            float _BaseColorIntensity;
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

                ILMData ilmData;
                InitializeILMData(input.uv, ilmData);
                
                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(input.uv, surfaceData);
                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, inputData);
                
                ShadowParams shadowParams;
                InitializeShadowParams(shadowParams);

                SpecularParams specularParams;
                InitializeSpecularParams(ilmData, specularParams);
                
                surfaceData.albedo *= _BaseColorIntensity;
                surfaceData.metallic = ilmData.metallic;
                surfaceData.specular = specularParams.color;
                surfaceData.smoothness = ilmData.metallic * 0.3;

                SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
                // #ifdef _OUTLINE
                //     color.rgb = MixOutlineColor(color, input.normalWS, GetWorldSpaceNormalizeViewDir(input.positionWS));
                // #endif
                uint materialFlags = 0;
                // just test                                                                
                if (surfaceData.metallic > 0.5)
                {
                    materialFlags += kMaterialFlagSSR;
                }
                return EncodeGBuffer(inputData, surfaceData, materialFlags, _ShadingModel, half3(shadowParams.mid, shadowParams.hardness, shadowParams.factor));
            }
            ENDHLSL
        }
        
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
            #include "./Library/Outline.hlsl"
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
                surfaceData.metallic = ilmData.metallic;
                surfaceData.specular = step(0.5, ilmData.specular);
                surfaceData.smoothness = ilmData.metallic * 0.3;

                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, inputData);

                ShadowParams shadowParams;
                InitializeShadowParams(shadowParams);

                SpecularParams specularParams;
                InitializeSpecularParams(ilmData, specularParams);
                
                SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
                half4 color = UniversalLighting(input, inputData, surfaceData, ilmData, shadowParams, specularParams);

                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                #ifdef _OUTLINE
                    color.rgb = MixOutlineColor(color, input.normalWS, GetWorldSpaceNormalizeViewDir(input.positionWS));
                #endif
                
                color.a = OutputAlpha(color.a, _Surface);
                
                return color;

            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
