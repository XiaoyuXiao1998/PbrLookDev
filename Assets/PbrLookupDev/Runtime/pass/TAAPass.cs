using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;

public enum SAMPLE_METHOD
{
    HALTON_X2_Y3,
}

public class TAA 
{
    // Start is called before the first frame update

    static int Samples = 16;
    static float  BlendAlpha = 0.1f;
    int FrameID;
    SAMPLE_METHOD sampleMethod;
    List<Vector2> samplePatterns;

    //reprojection variables for reprojection
    Matrix4x4 previousViewProjection;
    Vector2 previousOffset;
    Vector2 currentOffset;
    
    RenderTexture HistoryBuffer, OutputTAA;
    RenderTargetIdentifier HistoryBufferID;

    private static Material _TAAMaterial;
    
    private readonly string profilerTag = "TAA PASS";

    private bool initialzed = false;
    
    
    private static Material TAAMaterial
    {
        get
        {
            if (_TAAMaterial == null)
                _TAAMaterial = new Material(Shader.Find("PbrDev/TemporalAntiAliasing"));
            return _TAAMaterial;
        }
    }







    public TAA(SAMPLE_METHOD _sampleMethod)
    {
        sampleMethod = sampleMethod;
        FrameID = 0;
        if(sampleMethod == SAMPLE_METHOD.HALTON_X2_Y3)
        {
            samplePatterns = Sampler.HaltonSequence(2, 3).Skip(1).Take(Samples).ToList();
        }
        
    }
    
    void InitTAATexture(ref CommandBuffer cmd,ref Camera camera)
    {
        HistoryBuffer = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0);
        HistoryBuffer.Create(); ;

        if (Application.isPlaying)
        {
            var texture = ScreenCapture.CaptureScreenshotAsTexture();
            Graphics.CopyTexture(texture, HistoryBuffer);
        }

        OutputTAA = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0);
        OutputTAA.Create();
        HistoryBuffer.dimension = TextureDimension.Tex2D;
       
        HistoryBufferID = HistoryBuffer;
        cmd.SetGlobalTexture("_HistoryBuffer", HistoryBuffer);
        cmd.SetGlobalFloat("_BlendAlpha", BlendAlpha);

    }
    

    public Vector2 getOffset()
    {
        return samplePatterns[(FrameID++) % Samples];

    }

    public void setJitterProjectionMatrix(ref Matrix4x4 jitteredProjection, ref Camera camera)
    {
        Vector2 offset = samplePatterns[(FrameID++) % Samples];
        jitteredProjection.m02 += (offset.x * 2 - 1) / Screen.width;
        jitteredProjection.m12 += (offset.y * 2 - 1) / Screen.height;
    }
    
    public void TAAPass(ref ScriptableRenderContext context, ref Camera camera)
    {
    
  
        Vector2 offset = this.getOffset();// ... Get a sampling offset from sampling pattern.
        var jitteredProjection = camera.projectionMatrix;
        jitteredProjection.m02 += (offset.x * 2 - 1) / camera.pixelWidth;
        jitteredProjection.m12 += (offset.y * 2 - 1) / camera.pixelHeight;
        var cmd = CommandBufferPool.Get(profilerTag);
        if(!initialzed)
        {
            InitTAATexture(ref cmd,ref camera);
            initialzed = true;
            
        }
        
        cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, jitteredProjection);
        
        cmd.Blit(camera.targetTexture, OutputTAA, TAAMaterial);

        cmd.Blit(OutputTAA, HistoryBuffer); // Save current frame for next frame.

        

       if (camera.cameraType == CameraType.SceneView)
       {
           cmd.Blit(HistoryBuffer, camera.targetTexture); // Blit to screen.
       }
       else
       {
           cmd.Blit(HistoryBuffer, camera.targetTexture, new Vector2(1.0f, -1.0f), new Vector2(0.0f, 1.0f));
       }

       

        context.ExecuteCommandBuffer(cmd);

        context.Submit();
        cmd.Release();

      //  FrameID++;
    }

    
}



