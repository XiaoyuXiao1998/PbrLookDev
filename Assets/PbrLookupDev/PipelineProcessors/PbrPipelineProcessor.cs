using System;
using UnityEngine;
using UnityEngine.Rendering;


public class PipelineProcessor : IDisposable {
    

    protected ScriptableRenderContext context; 
    protected CommandBuffer cmd; 
    private readonly string profilerTag = "pipleline process";
    
    
    //*******************shader properties ***********
    public static readonly int _PREINTEGRATED_GF_LUT= Shader.PropertyToID("_PreintegratedGFLut");
    public static readonly int _GLOBAL_ENV_MAP_SPECULAR         = Shader.PropertyToID("_GlobalEnvMapSpecular");
    public static readonly int _GLOBAL_ENV_MAP_DIFFUSE= Shader.PropertyToID("_GlobalEnvMapDiffuse");


    public void Process(ScriptableRenderContext context)
    {
        this.context = context;
        cmd = CommandBufferPool.Get(profilerTag);

        FirstFrameSetup();
        DisposeCommandBuffer();

    }

    public void Dispose()
    {
        DisposeCommandBuffer();
    }
        
    public void DisposeCommandBuffer() {
        if (cmd != null) {
            CommandBufferPool.Release(cmd);
            cmd = null;
        }
    }

    public void ExecuteCommand(bool clear = true) {
        context.ExecuteCommandBuffer(cmd);
        if (clear) cmd.Clear();
    }

    public void ExecuteCommand(CommandBuffer buffer, bool clear = true) {
        context.ExecuteCommandBuffer(buffer);
        if (clear) buffer.Clear();
    }
    
    
    //initialize functions
    public void FirstFrameSetup() {
        var settings = PbrRenderPipeline.settings;
      

        if (!PbrRenderPipeline.instance.IsOnFirstFrame) return;
;

        cmd.SetGlobalTexture(_PREINTEGRATED_GF_LUT, settings.specularIBLLut);
        cmd.SetGlobalTexture(_GLOBAL_ENV_MAP_SPECULAR, settings.globalEnvMapSpecular);
        cmd.SetGlobalTexture(_GLOBAL_ENV_MAP_DIFFUSE, settings.globalEnvMapDiffuse);
                
        ExecuteCommand();
    }

 
}