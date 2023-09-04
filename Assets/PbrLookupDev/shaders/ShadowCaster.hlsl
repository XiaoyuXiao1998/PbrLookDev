#ifndef SHADOW_CASTER_INCLUDED
#define SHADOW_CASTER_INCLUDED

#include <UnityShaderUtilities.cginc>

#define NUM_SAMPLES 49


#define PI 3.14159265359
#define TWO_PI 3.14159265359 * 2.0

UNITY_DECLARE_TEX2D(_MainShadowMap);



float4x4 _MainLightMatrixWorldToShadowMap;
float4 _ShadowParams;


float2 uniformDisk[NUM_SAMPLES];

float fract(float x)
{
    return x- floor(x);
}

float rand_2to1(float2 uv ) { 
    // 0 - 1
    const  float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot( uv.xy, float2( a,b ) ), sn = dt % PI;
    return fract(sin(sn) * c);
}

 float rand_1to1( float x ) { 
    // -1 -1
    return fract(sin(x)*10000.0);
}

void uniformDiskSamples( const in float2 randomSeed ) {

    float randNum = rand_2to1(randomSeed);
    float sampleX = rand_1to1( randNum ) ;
    float sampleY = rand_1to1( sampleX ) ;

    float angle = sampleX * TWO_PI;
    float radius = sqrt(sampleY);

    for( int i = 0; i < NUM_SAMPLES; i ++ ) {
        uniformDisk[i] = float2( radius * cos(angle) , radius * sin(angle)  );

        sampleX = rand_1to1( sampleY ) ;
        sampleY = rand_1to1( sampleX ) ;

        angle = sampleX * TWO_PI;
        radius = sqrt(sampleY);
    }
}

//persontage closer filter
float PCF(float3 fragPosLightSpace,float filterSize){
    

    float final_shadow = 0;
    uniformDiskSamples(fragPosLightSpace.xy);

    float size_x;
    float size_y;
    _MainShadowMap.GetDimensions(size_x,size_y);
    
    float2 texelSize = 1.0 / float2(size_x,size_y);

    for(int i = 0 ;i < NUM_SAMPLES ;i++){
        // get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
        float closestDepth = UNITY_SAMPLE_TEX2D(_MainShadowMap, fragPosLightSpace.xy + filterSize * uniformDisk[i] * texelSize).r; 
        // get depth of current fragment from light's perspective
        float currentDepth = fragPosLightSpace.z;
        // check whether current frag pos is in shadow
        float shadow;
        #if UNITY_REVERSED_Z
        shadow = currentDepth + 0.01< closestDepth  ? 1.0 : 0.0;
        #else
        shadow = currentDepth - 0.01> closestDepth  ? 1.0 : 0.0;
        #endif
        final_shadow += shadow/NUM_SAMPLES;
    }

    return  final_shadow;

}

///将坐标从世界坐标系转换到主灯光的裁剪空间
float3 WorldToShadowMapPos(float3 positionWS){
    float4 positionCS = mul(_MainLightMatrixWorldToShadowMap,float4(positionWS,1));
    positionCS /= positionCS.w;
    return positionCS;
}

///检查世界坐标是否位于主灯光的阴影之中(0表示不在阴影中，大于0表示在阴影中,数值代表了阴影强度)
float GetMainLightShadowAtten(float3 positionWS,float3 normalWS){

    if(_ShadowParams.z == 0){
        return 0;
    }
    float3 shadowMapPos = WorldToShadowMapPos(positionWS + normalWS * _ShadowParams.y);
    
    return PCF(shadowMapPos,3);
    
 
}


/**
======= Shadow Caster Region =======
**/


struct ShadowCasterAttributes
{
    float4 positionOS   : POSITION;
};

struct ShadowCasterVaryings
{
    float4 positionCS   : SV_POSITION;
};

ShadowCasterVaryings ShadowCasterVertex(ShadowCasterAttributes input)
{
    ShadowCasterVaryings output;
    float4 positionCS = UnityObjectToClipPos(input.positionOS);
    output.positionCS = positionCS;
    return output;
}

half4 ShadowCasterFragment(ShadowCasterVaryings input) : SV_Target
{
    return 0;
}


#endif
