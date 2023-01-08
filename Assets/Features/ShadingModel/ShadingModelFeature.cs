using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
public class ShadingModelPass : ScriptableRenderPass
{
    private int gBuffer3Id = Shader.PropertyToID("_CustomGBuffer3");
    private int colorId = Shader.PropertyToID("_CameraColorAttachmentA");
    private int depthId = Shader.PropertyToID("_CameraDepthAttachment");
    private static readonly ProfilingSampler ShadingModelInfo = new ProfilingSampler("ShadingModel");

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, ShadingModelInfo))
        {
            var camera = renderingData.cameraData.camera;
            cmd.GetTemporaryRT(gBuffer3Id, renderingData.cameraData.cameraTargetDescriptor);
            cmd.Blit(colorId, gBuffer3Id);
            cmd.SetRenderTarget(colorId, depthId);
            cmd.ClearRenderTarget(false, true, Color.clear, 1);
        }   
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}
public class ShadingModelFeature : ScriptableRendererFeature
{
    private ShadingModelPass _pass;
    public override void Create()
    {
        _pass = new ShadingModelPass
        {
            renderPassEvent = RenderPassEvent.AfterRenderingGbuffer
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_pass);
    }
}
