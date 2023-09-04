using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer {

	const string bufferName = "Render Camera";

	static ShaderTagId
		unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"),
		litShaderTagId = new ShaderTagId("CustomLit");

	CommandBuffer buffer = new CommandBuffer {
		name = bufferName
	};

	ScriptableRenderContext context;

	Camera camera;

	CullingResults cullingResults;
	
	static int frameBufferId = Shader.PropertyToID("_CameraFrameBuffer");
	
	//*****************************************
	//            g buffers        ************
	//*****************************************
	
	RenderTexture gdepth;  
	RenderTexture[] gbuffers = new RenderTexture[2];                
	
	RenderTargetIdentifier gdepthID;
	RenderTargetIdentifier[] gbufferID = new RenderTargetIdentifier[2];


	//*****************************************
	//            light setup      ************
	//*****************************************
	Lighting lighting = new Lighting();
	//*****************************************
	//            Shadow Caster      **********
	//*****************************************
	private ShadowCasterPass shadowCastPass = new ShadowCasterPass();

	//*****************************************
	//            SSAO Pass           *********
	//*****************************************
	private SSAO ssao = new SSAO();


	public void Init()
	{
		
		
		gdepth = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);
		gbuffers[0] = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
		gbuffers[1] = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
		

		gdepthID = gdepth;
		gbufferID[0] = gbuffers[0];
		gbufferID[1] = gbuffers[1];
		
		
		ssao.Setup(gbuffers[1],gdepth);

	}





	

	public void Render (
		ScriptableRenderContext context, Camera camera
	) {
		this.context = context;
		this.camera = camera;

		PrepareBuffer();
		PrepareForSceneWindow();
		if (!Cull()) {
			return;
		}
		
		buffer.BeginSample(SampleName);
		ExecuteBuffer();
		
		
		//*******************************set up lighting*****************************
		lighting.Setup(context, cullingResults);
		//*******************************caster shader********************************
		shadowCastPass.Execute(context,camera,ref cullingResults, ref lighting);
		
		buffer.EndSample(SampleName);
		Setup();
		DrawVisibleGeometry();


		if (!PbrRenderPipeline.ssaoSettings.IsUnityNull() && PbrRenderPipeline.ssaoSettings.useAO )
		{
			ssao.excute(gbuffers[0], camera.targetTexture, ref camera, ref context);
		}
		//buffer.Blit(gbuffers[0],camera.targetTexture);
		
		DrawUnsupportedShaders();
		
		DrawGizmos();
		lighting.Cleanup();
		Cleanup();
		Submit();
	}

	bool Cull () {
		if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
		{
			p.shadowDistance = camera.farClipPlane;
			cullingResults = context.Cull(ref p);
			return true;
		}
		return false;
	}

	void Setup () {
		context.SetupCameraProperties(camera);
		CameraClearFlags flags = camera.clearFlags;
		
		buffer.GetTemporaryRT(
			frameBufferId, camera.pixelWidth, camera.pixelHeight,
			32, FilterMode.Bilinear, RenderTextureFormat.Default
		);
		
		buffer.SetRenderTarget(gbufferID,gdepth);


		buffer.ClearRenderTarget(
			flags <= CameraClearFlags.Depth,
			flags <= CameraClearFlags.Color,
			flags == CameraClearFlags.Color ?
				camera.backgroundColor.linear : Color.clear
		);
		
		buffer.BeginSample(SampleName);
		ExecuteBuffer();
	}

	void Submit () {
		buffer.EndSample(SampleName);
		ExecuteBuffer();
		context.Submit();
	}

	void ExecuteBuffer () {
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}

	void DrawVisibleGeometry () {
		var sortingSettings = new SortingSettings(camera) {
			criteria = SortingCriteria.CommonOpaque
		};
		var drawingSettings = new DrawingSettings(
			unlitShaderTagId, sortingSettings
		);
		drawingSettings.SetShaderPassName(1, litShaderTagId);

		var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

		context.DrawRenderers(
			cullingResults, ref drawingSettings, ref filteringSettings
		);

		context.DrawSkybox(camera);
		
		

		sortingSettings.criteria = SortingCriteria.CommonTransparent;
		drawingSettings.sortingSettings = sortingSettings;
		filteringSettings.renderQueueRange = RenderQueueRange.transparent;

		context.DrawRenderers(
			cullingResults, ref drawingSettings, ref filteringSettings
		);
	}
	
	void Cleanup () {
		lighting.Cleanup();
		
		buffer.ReleaseTemporaryRT(frameBufferId);
		
	}
}