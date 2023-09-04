﻿Shader "PbrDev/TemporalAntiAliasing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
        SubShader
    {
        Pass
        {
            CGPROGRAM


            /*
            float4x4 _LastVP;
            float4x4 _NonJitterVP;
            #define GetScreenPos(pos) ((float(pos.x,pos.y) * 0.5) / pos.w + 0.5)
            inline float2 CalculateMotionVector(float4x4 lastVP,float3 lastWorldPos, float2 screenUV) {
                float4 lastScreenPos = mul(lastVP, float4(lastWorldPos, 1));
                float4 lastScreenUV = GetScreenPos(lastScreenPos);
                return screenUV - lastScreenUV;

            }

            */

            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float4 _MainTex_ST;
            
        

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            Texture2D _MainTex;
            SamplerState sampler_MainTex;
            Texture2D _HistoryBuffer;
            SamplerState  sampler_HistoryBuffer;
            float _BlendAlpha;

            fixed4 frag(v2f i) : SV_Target
            {
                
                   float4 hisotry = _HistoryBuffer.Sample(sampler_HistoryBuffer,i.uv);
                
                
                   float4 current = _MainTex.Sample(sampler_MainTex,i.uv);
                   return lerp(hisotry, current, _BlendAlpha);
     
            }
            ENDCG
        }
    }
}