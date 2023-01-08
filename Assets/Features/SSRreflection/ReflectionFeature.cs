
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ReflectionFeature : ScriptableRendererFeature {
    class ReflectionPass : ScriptableRenderPass
    {
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetHandle destination {get; set;}
        private RenderTargetHandle ReflectID;
        private RenderTargetHandle BlurID;
        private RenderTargetHandle ResultID;
        private int propGroupSizeX = Shader.PropertyToID("_GroupSizeX");
        private int propGroupSizeY = Shader.PropertyToID("_GroupSizeY");
        private int propMaxStep = Shader.PropertyToID("_SSRMaxStep");
        private int propMaxDistance = Shader.PropertyToID("_SSRMaxDistance");
        private int propStepSize = Shader.PropertyToID("_SSRStepSize");
        public ReflectionSettings settings;

        public ReflectionPass(ReflectionSettings settings)
        {
            this.settings = settings;
            ReflectID.Init("_ReflectTex");
            BlurID.Init("_BlurTex");
            ResultID.Init("_SSRResultTex");
        }

        public void Setup(RenderTargetIdentifier source, RenderTargetHandle destination)
        {
            this.source = source;
            this.destination = destination;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("SSRPass");

            RenderTextureDescriptor opaqueDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDescriptor.depthBufferBits = 0;
            opaqueDescriptor.enableRandomWrite = true;

            if (destination == RenderTargetHandle.CameraTarget)
            {
                cmd.GetTemporaryRT(ReflectID.id, opaqueDescriptor, FilterMode.Point);
                cmd.GetTemporaryRT(BlurID.id, opaqueDescriptor, FilterMode.Point);
                cmd.GetTemporaryRT(ResultID.id, opaqueDescriptor, FilterMode.Point);
                var reflectionKernelIndex = settings.reflectionShader.FindKernel("ReflectionMain");
                var blurXKernelIndex = settings.reflectionShader.FindKernel("BlurXMain");
                var blurYKernelIndex = settings.reflectionShader.FindKernel("BlurYMain");
                var mixKernelIndex = settings.reflectionShader.FindKernel("MixMain");
                uint threadSizeX = 0;
                uint threadSizeY = 0;
                uint threadSizeZ = 0;
                settings.reflectionShader.GetKernelThreadGroupSizes(reflectionKernelIndex, out threadSizeX, out threadSizeY, out threadSizeZ);

                int groupSizeX = (int)Mathf.Ceil((float)opaqueDescriptor.width / threadSizeX);
                int groupSizeY = (int)Mathf.Ceil((float)opaqueDescriptor.height / threadSizeY);
                settings.reflectionShader.SetInt(propGroupSizeX, groupSizeX);
                settings.reflectionShader.SetInt(propGroupSizeY, groupSizeY);
                
                // props
                settings.reflectionShader.SetInt(propMaxStep, (int)settings.maxStep);
                settings.reflectionShader.SetFloat(propMaxDistance, settings.maxDistance);
                settings.reflectionShader.SetFloat(propStepSize, settings.stepSize);

                cmd.DispatchCompute(settings.reflectionShader, reflectionKernelIndex, groupSizeX, groupSizeY, 1);
                cmd.DispatchCompute(settings.reflectionShader, blurXKernelIndex, groupSizeX, opaqueDescriptor.height, 1);
                cmd.DispatchCompute(settings.reflectionShader, blurYKernelIndex, opaqueDescriptor.width, groupSizeY, 1);
                cmd.DispatchCompute(settings.reflectionShader, mixKernelIndex, groupSizeX, groupSizeY, 1);
                
                cmd.CopyTexture(ResultID.id, Shader.PropertyToID("_CameraColorAttachmentA"));
                cmd.ReleaseTemporaryRT(ReflectID.id);
                cmd.ReleaseTemporaryRT(BlurID.id);
                cmd.ReleaseTemporaryRT(ResultID.id);
            }
            else Blit(cmd, source, destination.Identifier());


            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {

            if (destination == RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(BlurID.id);
                cmd.ReleaseTemporaryRT(ReflectID.id); 
                cmd.ReleaseTemporaryRT(ResultID.id);
            }
        }

    }


    [System.Serializable]
    public class ReflectionSettings
    {

        public ComputeShader reflectionShader = null;
        public uint maxStep;
        [Range(0, 5)]public float stepSize;
        public float maxDistance;
    }

    public ReflectionSettings settings = new ReflectionSettings();
    ReflectionPass reflectionPass;
    RenderTargetHandle reflectTexture;
    public override void Create()
    {
        reflectionPass = new ReflectionPass(settings);
        reflectionPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        reflectTexture.Init("_MainTex");
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer,ref RenderingData renderingData)
    {
        if (settings.reflectionShader == null)
        {
            Debug.LogWarningFormat("Missing Reflection Shader");
            return;
        }
        reflectionPass.Setup(renderer.cameraColorTarget, RenderTargetHandle.CameraTarget);
        renderer.EnqueuePass(reflectionPass);
    }
}







