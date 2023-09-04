
using UnityEngine;
using UnityEngine.Rendering;

  public class ShadowCasterPass
  {


      private CommandBuffer _commandBuffer = new CommandBuffer();
            

        private ShadowMapTextureHandler _shadowMapHandler = new ShadowMapTextureHandler();

        public ShadowCasterPass(){
            _commandBuffer.name = "ShadowCaster";
        }

        private static int GetShadowMapResolution(Light light){
            switch(light.shadowResolution){
                case LightShadowResolution.VeryHigh:
                return 2048;
                case LightShadowResolution.High:
                return 1024;
                case LightShadowResolution.Medium:
                return 512;
                case LightShadowResolution.Low:
                return 256;
            }
            return 256;
        }

        private void SetupShadowCasterView(ScriptableRenderContext context,int shadowMapResolution,ref Matrix4x4 matrixView,ref Matrix4x4 matrixProj){
            _commandBuffer.Clear();
            _commandBuffer.SetViewport(new Rect(0,0,shadowMapResolution,shadowMapResolution));
            //set view and proj matrix
            _commandBuffer.SetViewProjectionMatrices(matrixView,matrixProj);
          
            _commandBuffer.SetRenderTarget(_shadowMapHandler.renderTargetIdentifier,_shadowMapHandler.renderTargetIdentifier);
            _commandBuffer.ClearRenderTarget(true,true,Color.black,1);
            context.ExecuteCommandBuffer(_commandBuffer);
        }

  
        static Matrix4x4 GetWorldToShadowMapSpaceMatrix(Matrix4x4 proj, Matrix4x4 view)
        {
            // check whether the z buffer is reversed
            if (SystemInfo.usesReversedZBuffer)
            {
                proj.m20 = -proj.m20;
                proj.m21 = -proj.m21;
                proj.m22 = -proj.m22;
                proj.m23 = -proj.m23;
            }

            // uv_depth = xyz * 0.5 + 0.5. 
            Matrix4x4 worldToShadow = proj * view;
            var textureScaleAndBias = Matrix4x4.identity;
            textureScaleAndBias.m00 = 0.5f;
            textureScaleAndBias.m11 = 0.5f;
            textureScaleAndBias.m22 = 0.5f;
            textureScaleAndBias.m03 = 0.5f;
            textureScaleAndBias.m23 = 0.5f;
            textureScaleAndBias.m13 = 0.5f;

            return textureScaleAndBias * worldToShadow;
        }
        public void Execute(ScriptableRenderContext context,Camera camera,ref CullingResults cullingResults,ref Lighting lightData){
            if(!lightData.hasMainLight()){
                //表示场景无主灯光
                Shader.SetGlobalVector(ShaderProperties.ShadowParams,new Vector4(0,0,0,0));
                return;
            }
            //假设场景中只有一个方向光
            int mainLightIndex = 0;
            if(!cullingResults.GetShadowCasterBounds(mainLightIndex,out var lightBounds)){
                Shader.SetGlobalVector(ShaderProperties.ShadowParams,new Vector4(0,0,0,0));
                return;
            }
            var mainLight = cullingResults.visibleLights[0];
            var lightComp = mainLight.light;
            var shadowMapResolution = GetShadowMapResolution(lightComp);
            //get light matrixView,matrixProj,shadowSplitData
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(mainLightIndex,0,1,
            new Vector3(1,0,0),shadowMapResolution,lightComp.shadowNearPlane,out var matrixView,out var matrixProj,out var shadowSplitData);
            var matrixWorldToShadowMapSpace = GetWorldToShadowMapSpaceMatrix(matrixProj,matrixView);
            // Debug.Log(shadowSplitData.cullingSphere);
            //generate ShadowDrawingSettings
            ShadowDrawingSettings shadowDrawSetting = new ShadowDrawingSettings(cullingResults,mainLightIndex);
            shadowDrawSetting.splitData = shadowSplitData;
            
            //setup shader params
            Shader.SetGlobalMatrix(ShaderProperties.MainLightMatrixWorldToShadowSpace,matrixWorldToShadowMapSpace);
            Shader.SetGlobalVector(ShaderProperties.ShadowParams,new Vector4(lightComp.shadowBias,lightComp.shadowNormalBias,lightComp.shadowStrength,0));

            //生成ShadowMapTexture
            _shadowMapHandler.AcquireRenderTextureIfNot(shadowMapResolution);

            //set params for shadow caster view
            SetupShadowCasterView(context,shadowMapResolution,ref matrixView,ref matrixProj);
         
            context.DrawShadows(ref shadowDrawSetting);
        }

        public class ShadowMapTextureHandler{
            private RenderTargetIdentifier _renderTargetIdentifier = "_MainShadowMap";
            private int _shadowmapId = Shader.PropertyToID("_MainShadowMap");
            private RenderTexture _shadowmapTexture;    

            public RenderTargetIdentifier renderTargetIdentifier{
                get{
                    return _renderTargetIdentifier;
                }
            }


            public void AcquireRenderTextureIfNot(int resolution){
                if(_shadowmapTexture && _shadowmapTexture.width != resolution){
                    //resolution changed
                    RenderTexture.ReleaseTemporary(_shadowmapTexture);
                    _shadowmapTexture = null;
                }

                if(!_shadowmapTexture){
                    _shadowmapTexture = RenderTexture.GetTemporary(resolution,resolution,16,RenderTextureFormat.Shadowmap);
                    Shader.SetGlobalTexture(ShaderProperties.MainShadowMap,_shadowmapTexture);
                    _renderTargetIdentifier = new RenderTargetIdentifier(_shadowmapTexture);
                }
            }

        }


        public static class ShaderProperties{

            public static readonly int MainLightMatrixWorldToShadowSpace = Shader.PropertyToID("_MainLightMatrixWorldToShadowMap");

            //x: depthBias,y: normalBias,z: shadowStrength
            public static readonly int ShadowParams = Shader.PropertyToID("_ShadowParams");
            public static readonly int MainShadowMap = Shader.PropertyToID("_MainShadowMap");

        }
    }
