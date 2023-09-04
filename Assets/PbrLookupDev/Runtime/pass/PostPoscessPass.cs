using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


using UnityEngine;


public class PostPrecess
{
    private Material mat_Exposure;
    private readonly string profilerTag = "POST PROCESSING PASS";

    public ref PhysicalCameraSettings physicalCameraSettings =>  ref PbrRenderPipeline.physicalCameraSettings;
    
    
    public void Setup()
    {
        mat_Exposure = GetMaterial("PostProcessing/Exposure");
    }


    public void excute(int source,RenderTexture desc,ref Camera camera, ref ScriptableRenderContext context)
    {
        CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
        
        if (mat_Exposure == null)
        {
            cmd.Blit(source, desc);
            context.ExecuteCommandBuffer(cmd);
            cmd.Release();
            return;
        }
        
        else
        {
            SetMatData(ref camera);
            cmd.Blit(source,desc,mat_Exposure,0);
            context.ExecuteCommandBuffer(cmd);
            cmd.Release();
            return;
        }   
       
    }
    
    private Material GetMaterial(string shaderName)
    {
        Shader s = Shader.Find(shaderName);
        if (s == null)
        {
            Debug.Log("shader not found");
            return null;
        }
        Material mat = new Material(s);
        mat.hideFlags = HideFlags.HideAndDontSave;
        return mat;
    }
    private void SetMatData(ref Camera cam)
    {
        mat_Exposure.SetFloat("_iso",physicalCameraSettings.iso);
        mat_Exposure.SetFloat("_shutterSpeed",physicalCameraSettings.shutterSpeed);
        mat_Exposure.SetFloat("_aperture",physicalCameraSettings.aperture);

    }
}