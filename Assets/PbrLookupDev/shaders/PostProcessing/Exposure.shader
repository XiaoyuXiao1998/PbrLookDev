Shader "PostProcessing/Exposure"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

    }
    SubShader
    {

	    Pass
        {
        	Cull Off ZWrite Off ZTest Always
	 
	        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "physicalCamera.hlsl"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
	        	
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            Texture2D _MainTex;
	        SamplerState sampler_MainTex;

	        float _aperture;
	        float _shutterSpeed;
	        float _iso;
	        
            float4 _MainTex_ST;
     

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
    
    
            float4  frag(v2f i): SV_Target
            {

                float exposure = getSaturationBasedExposure(_aperture,
                                 _shutterSpeed,
                                 _iso);
                float3 color = _MainTex.Sample(sampler_MainTex,i.uv);
                return float4(color.rgb* exposure,1.0);
                
            }
    
            ENDCG
        }

    }
}