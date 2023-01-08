float FresnelEffect(float3 normalWS, float3 viewDirWS, float power)
{
    return pow(1.0 - saturate(dot(normalize(normalWS), viewDirWS)), power);
}

#ifdef _OUTLINE
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
#endif
