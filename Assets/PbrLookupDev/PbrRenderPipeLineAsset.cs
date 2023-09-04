using System;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/PbrRenderPipeline")]
public class PbrRenderPipelineAsset : RenderPipelineAsset
{
	public PbrRenderPipelineSettings pbrRenderPipelineSettings;
	public SSAOSettings ssaoSettings;

    protected override RenderPipeline CreatePipeline()
    {

        return new PbrRenderPipeline(pbrRenderPipelineSettings,ssaoSettings);
    }
     
       
}


[Serializable]
public class PbrRenderPipelineSettings {
	[Header("Image Based Lighting")]
	public Texture2D specularIBLLut;
	public Cubemap globalEnvMapDiffuse;
	public Cubemap globalEnvMapSpecular;
}

[Serializable]

public class SSAOSettings
{
	[Header("SSAO Settings")]
	[Range(1, 128)]public int sampleCount = 20;
	[Range(0f, 0.8f)]public float radius = 0.5f;
	[Range(0f, 10f)]public float rangeCheck = 1.0f;
	[Range(0f, 10f)]public float aoInt = 1f;
	[Range(0f, 3f)]public float blurRadius = 1f;
	[Range(0f, 1f)]public float bilaterFilterFactor = 0.1f;
	public Color aoColor = Color.black;
	public bool aoOnly = false;
	public bool useAO = true;
}

