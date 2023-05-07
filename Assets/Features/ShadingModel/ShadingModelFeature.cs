using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Reflection;
using JetBrains.Annotations;

public class ShadingModelPass : ScriptableRenderPass
{
    public Texture MatMap;
    public Texture ShadowRampMap;

    private RTHandle _gBuffer3;
    private RTHandle _outlineBuffer;
    private static readonly ProfilingSampler ShadingModelInfo = new ProfilingSampler("ShadingModel");

    private class DeferredTextures
    {
        public RTHandle gBuffer3;
    }

    private DeferredTextures? _deferredTextures = null;

    private Material _outlineMaterial;
    
    [CanBeNull]
    private DeferredTextures GetGBufferDeferredTextures(ScriptableRenderer renderer)
    {
        FieldInfo lightsInfo = typeof(UniversalRenderer).GetField("m_DeferredLights", BindingFlags.NonPublic | BindingFlags.Instance);
        var lights = lightsInfo?.GetValue((UniversalRenderer)renderer);
        Type lightType = lights?.GetType();
        PropertyInfo attachmentInfo = lightType?.GetProperty("GbufferAttachments", BindingFlags.NonPublic | BindingFlags.Instance);
        var attachments = (RTHandle[])attachmentInfo?.GetValue(lights);

        if (attachments != null && attachments[3].rt != null)
        {
            return new DeferredTextures()
            {
                gBuffer3 = attachments[3],
            };
        }

        return null;
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        if (_outlineMaterial == null)
        {
            _outlineMaterial = new Material(Shader.Find("Custom/OutlineDetection"));

        }
        var textureDescriptor = cameraTextureDescriptor;
        textureDescriptor.graphicsFormat = GraphicsFormat.R16G16B16A16_SFloat;
        textureDescriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _gBuffer3, textureDescriptor, FilterMode.Point, TextureWrapMode.Repeat, false, 1, 0, "_CustomGBuffer3");

        var outlineTextureDescriptor = cameraTextureDescriptor;
        outlineTextureDescriptor.graphicsFormat = GraphicsFormat.R16G16B16A16_SFloat;
        outlineTextureDescriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _outlineBuffer, outlineTextureDescriptor, FilterMode.Point, TextureWrapMode.Repeat, false, 1, 0, "_OutlineBuffer");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        _deferredTextures = GetGBufferDeferredTextures(renderingData.cameraData.renderer);
        if (_deferredTextures != null && renderingData.cameraData.renderType == CameraRenderType.Base)
        {
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, ShadingModelInfo))
            {
                cmd.SetGlobalTexture("_MatMap", MatMap);
                cmd.SetGlobalTexture("_ShadowRampMap", ShadowRampMap);
                cmd.SetGlobalTexture(_gBuffer3.name, _gBuffer3);
                cmd.SetGlobalTexture(_outlineBuffer.name, _outlineBuffer);
                cmd.Blit(_deferredTextures.gBuffer3, _gBuffer3);
                Blitter.BlitTexture(cmd, renderingData.cameraData.renderer.cameraColorTargetHandle, _outlineBuffer, _outlineMaterial, 0);
                cmd.SetRenderTarget(_deferredTextures.gBuffer3);
                cmd.ClearRenderTarget(false, true, Color.clear, 1);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
    
    
    public void Dispose()
    {
        _gBuffer3?.Release();
        _outlineBuffer?.Release();
    }
}

public class OutlinePass : ScriptableRenderPass
{
    private Material _outlineMaterial;
    private RTHandle _colorTargetBlit;

    public OutlinePass()
    {
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        if (_outlineMaterial == null)
        {
            _outlineMaterial = new Material(Shader.Find("Custom/OutlineDetection"));
        }
        var textureDescriptor = cameraTextureDescriptor;
        textureDescriptor.graphicsFormat = GraphicsFormat.R16G16B16A16_SFloat;
        textureDescriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _colorTargetBlit, textureDescriptor, FilterMode.Point, TextureWrapMode.Repeat, false, 1, 0, "_ColorTargetBlit");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.renderType == CameraRenderType.Base && renderingData.cameraData.renderer.cameraColorTargetHandle != null && _colorTargetBlit != null)
        {
            var cmd = CommandBufferPool.Get("OutlineApply");
            cmd.SetGlobalTexture(_colorTargetBlit.name, _colorTargetBlit);
            cmd.Blit(renderingData.cameraData.renderer.cameraColorTargetHandle, _colorTargetBlit);
            Blitter.BlitTexture(cmd, _colorTargetBlit, renderingData.cameraData.renderer.cameraColorTargetHandle, _outlineMaterial, 1);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    public void Dispose()
    {
        _colorTargetBlit?.Release();
    }
}

public class ShadingModelFeature : ScriptableRendererFeature
{
    private ShadingModelPass _pass;
    private OutlinePass _outlinePass;

    public Texture MatMap;
    public Texture ShadowRampMap;

    public override void Create()
    {
        _pass = new ShadingModelPass
        {
            renderPassEvent = RenderPassEvent.AfterRenderingGbuffer,
            MatMap = MatMap,
            ShadowRampMap = ShadowRampMap
        };

        _outlinePass = new OutlinePass
        {
            renderPassEvent = RenderPassEvent.AfterRenderingDeferredLights
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_pass);
        renderer.EnqueuePass(_outlinePass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass.Dispose();
        _outlinePass.Dispose();
    }
}