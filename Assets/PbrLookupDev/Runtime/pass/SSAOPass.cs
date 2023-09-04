using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


using UnityEngine;


public class SSAO 
{
    private Material mat_ao, mat_blur;
    private readonly string profilerTag = "SSAO PASS";

    private RenderTargetIdentifier _gNormalID;
    private RenderTargetIdentifier _gDepthID;
    
    private ref SSAOSettings ssaoSettings => ref PbrRenderPipeline.ssaoSettings;
    
    
    public static readonly int _GDEPTH = Shader.PropertyToID("_gDepth");
    public static readonly int _GNORMAL = Shader.PropertyToID("_gNormal");
    public void Setup(RenderTexture gNormal, RenderTexture gDepth)
    {
        mat_ao = GetMaterial("Hidden/SSAO");
        mat_blur = GetMaterial("Hidden/BilateralBlur");
        
        _gNormalID = gNormal;
        _gDepthID = gDepth;
        


        Shader.SetGlobalTexture(_GDEPTH, gDepth);
        Shader.SetGlobalTexture(_GNORMAL, gNormal);
    }


    public void excute(RenderTexture source,RenderTexture desc,ref Camera camera, ref ScriptableRenderContext context)
    {
        CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
        if (mat_ao == null)
        {
            cmd.Blit(source, desc);
            context.ExecuteCommandBuffer(cmd);
            cmd.Release();
            return;
        }


        else
        {
            SetMatData(ref camera);
            if (ssaoSettings.aoOnly)
            {
                cmd.Blit(source,desc,mat_ao,0);
                context.ExecuteCommandBuffer(cmd);
                cmd.Release();
                return;

            }
            
            RenderTexture temp1 = RenderTexture.GetTemporary(camera.pixelWidth, camera.pixelHeight);
            cmd.Blit(source,temp1,mat_ao,0);
            

            RenderTexture temp2 = RenderTexture.GetTemporary(camera.pixelWidth/2, camera.pixelHeight/2);
            
            cmd.SetGlobalTexture("_AOTex", temp1);
            
          //  mat_blur.SetTexture("_AOTex", temp1);
            cmd.Blit(temp1, temp2, mat_blur, 0);
            // mat_blur.SetTexture("_AOTex", temp2);
            cmd.SetGlobalTexture("_AOTex", temp2);
             
             RenderTexture temp3 = RenderTexture.GetTemporary(camera.pixelWidth, camera.pixelHeight);
             cmd.Blit(temp2, temp3, mat_blur, 1);
            

            mat_ao.SetTexture("_AOTex", temp3);
            mat_ao.SetTexture("_ColorTex",source);
            cmd.Blit(source,desc , mat_ao, 1);

            RenderTexture.ReleaseTemporary(temp1);
            RenderTexture.ReleaseTemporary(temp2);
            RenderTexture.ReleaseTemporary(temp3);
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Release();



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

        Matrix4x4 vp_Matrix = cam.projectionMatrix * cam.worldToCameraMatrix;
        mat_ao.SetMatrix("_VPMatrix_invers", vp_Matrix.inverse);

        Matrix4x4 v_Matrix = cam.worldToCameraMatrix;
        mat_ao.SetMatrix("_VMatrix", v_Matrix);

        Matrix4x4 p_Matrix = cam.projectionMatrix;
        mat_ao.SetMatrix("_PMatrix", p_Matrix);

        mat_ao.SetFloat("_SampleCount", ssaoSettings.sampleCount);
        mat_ao.SetFloat("_Radius", ssaoSettings.radius);
        mat_ao.SetFloat("_RangeCheck", ssaoSettings.rangeCheck);
        mat_ao.SetFloat("_AOInt", ssaoSettings.aoInt);
        mat_ao.SetColor("_AOCol", ssaoSettings.aoColor);

        mat_blur.SetFloat("_BlurRadius", ssaoSettings.blurRadius);
        mat_blur.SetFloat("_BilaterFilterFactor", ssaoSettings.bilaterFilterFactor);
    }
}