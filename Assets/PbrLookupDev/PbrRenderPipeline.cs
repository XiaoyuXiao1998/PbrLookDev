
using System.Linq;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
public class PbrRenderPipeline : RenderPipeline
{
    
    CameraRenderer renderer = new CameraRenderer();
    public static PbrRenderPipelineSettings settings;
    public static SSAOSettings ssaoSettings;
    public static PhysicalCameraSettings physicalCameraSettings;
    public static PbrRenderPipeline instance { get; private set; }

    public PipelineProcessor pipelineProcessor;
    
    public bool IsOnFirstFrame => frameNum == 1; 
		
    private int frameNum = 0;
    
    
    
    //construction function of render pipeline:
    
    public PbrRenderPipeline(PbrRenderPipelineSettings settings, SSAOSettings ssaoSettings, PhysicalCameraSettings physicalCameraSettings)
    {
      
        GraphicsSettings.lightsUseLinearIntensity = true;
        PbrRenderPipeline.instance = this;
        PbrRenderPipeline.settings = settings;
        PbrRenderPipeline.ssaoSettings = ssaoSettings;
        PbrRenderPipeline.physicalCameraSettings = physicalCameraSettings;
        pipelineProcessor = new PipelineProcessor();
        
        renderer.Init();

    }

    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        frameNum++;
        
        // process pipeline settings
        pipelineProcessor.Process(context);
        
        for (int i = 0; i < cameras.Count(); i++) {
            renderer.Render(context, cameras[i]);
        }

    }
    
    

    }