Shader "PbrDev/ClearCoat"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)

		_Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
    	
    	_ClearCoat("ClearCoat", Range(0, 1)) = 0
    	_ClearCoatSmoothness("ClearCoatSmoothness", Range(0, 1)) = 0.5
    	
    	_SkyIntensity("Sky Intensity", Range(0, 2)) = 0.5

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
		[Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
    }
    SubShader
    {

	    Pass
        {
        	
	        Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
	        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "BRDF.cginc"
	        #include "ShadowCaster.hlsl"
	        #include "ToneMapping.hlsl"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
	        	
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            	float3 worldPos: TEXCOORD1;
            };

            float4 _MainTex_ST;
            sampler2D _MainTex;

	        samplerCUBE _SkyBox;
            float _SkyBoxReflectSmooth;
	        
            int _DirectionalLightCount;
            float4 _DirectionalLightColors[4];
            float4 _DirectionalLightDirections[4];

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	        UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	        UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	        UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
	         UNITY_DEFINE_INSTANCED_PROP(float, _ClearCoat)
	        UNITY_DEFINE_INSTANCED_PROP(float, _ClearCoatSmoothness)
	        UNITY_DEFINE_INSTANCED_PROP(float, _SkyIntensity)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
            	o.worldPos =  mul(unity_ObjectToWorld,v.vertex).xyz;
                return o;
            }
    
            float4x4 _vpMatrix;
            float4x4 _vpMatrixInv;
            void  frag(v2f i,
            	out float4 GT0 : SV_Target0,
                out float4 GT1 : SV_Target1,
            	out float depthOut : SV_Depth)
            {

                //*********************** get material properties *********************

            	float3 albedo = _BaseColor.rgb * tex2D(_MainTex,i.uv).rgb;
                float metallic = _Metallic;
                float roughness = 1.0 - _Smoothness;

            	float clearCoat = _ClearCoat;
            	float clearCoatRoughness = 1.0 - _ClearCoatSmoothness;


                float3 worldPos =  i.worldPos;
            	
            	

                //****************** light pass ****************************************
            	
                float3 N = normalize(i.normal);
                float4 color = float4(0.0,0.0,0.0,1.0);
            	float3 L = _DirectionalLightDirections[0].xyz;
            	float3 V = normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz);
            	float3 radiance = _DirectionalLightColors[0].rgb;
            	
	            // radiance refers to the light color
            	float3 IBL_Diffuse, IBL_Specular;
            	float3 PBR = ClearCoatLightPass(N, V, L, albedo, radiance, roughness, metallic,
            		clearCoatRoughness,clearCoat,IBL_Diffuse, IBL_Specular)  ;
            	
            	color.rgb +=  PBR;
            	
               	color.rgb = (1.0 - GetMainLightShadowAtten(worldPos,N) )* color.rgb
            	+ (IBL_Diffuse +IBL_Specular) * _SkyIntensity;

            	color.rgb = ACESFilm(color.rgb);

            	GT0 = color;
            	GT1 = float4(i.normal*0.5+0.5, 0);
            	depthOut = i.vertex.z;
            }
    
            ENDCG
        }
    	
    	pass
    	{
    		
    		
	        Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
    		


            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
	        #include "ShadowCaster.hlsl"
            #pragma vertex ShadowCasterVertex
            #pragma fragment ShadowCasterFragment
        
            ENDHLSL
        }
    }
}