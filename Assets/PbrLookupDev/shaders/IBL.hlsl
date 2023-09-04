#ifndef IBL_LIGHTING
#define IBL_LIGHTING
#define PI 3.14159265359
#define TWO_PI 3.14159265359 * 2.0





TextureCube _GlobalEnvMapDiffuse;
SamplerState  sampler_GlobalEnvMapDiffuse;

TextureCube _GlobalEnvMapSpecular;
SamplerState  sampler_GlobalEnvMapSpecular;


Texture2D _PreintegratedGFLut;
SamplerState sampler_PreintegratedGFLut;

float __GlobalEnvMapRotation;
#define DIFF_IBL_MAX_MIP (6u)
#define SPEC_IBL_MAX_MIP (6u)





//************************************************************************************************
//*                     offline IBL Functions                                              *******
//*************************************************************************************************


//sample functions 

float3 hemisphereSample_uniform(float u, float v){
	float phi = v * 2 * PI;
	float cosTheta = 1.0f - u;
	float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

	return float3(sinTheta * cos(phi),sinTheta*sin(phi),cosTheta);
}


float RadicalInverse( uint bits ){
          //reverse bit
          //高低16位换位置
          bits = (bits << 16u) | (bits >> 16u); 
          //A是5的按位取反
          bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
          //C是3的按位取反
          bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
          bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
          bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
          return  float(bits) * 2.3283064365386963e-10;
}

float2 Hammersley(uint i,uint N){
          return float2(float(i) / float(N), RadicalInverse(i));
}


float4 Quat_Inverse(float4 q) {
    return float4(-q.xyz, q.w);
}

float3 Quat_Rotate(float4 q, float3 p) {
	// Quat_Mul(Quat_Mul(q, vec4(p, 0)), Quat_Inverse(q)).xyz;

	float4 qp = float4(q.w * p + cross(q.xyz, p), - dot(q.xyz, p));
	float4 invQ = Quat_Inverse(q);
	float3 qpInvQ = qp.w * invQ.xyz + invQ.w * qp.xyz + cross(qp.xyz, invQ.xyz);
	return qpInvQ;
}



float4 Quat_ZTo(float3 to) {
	// from = (0, 0, 1)
	//float cosTheta = dot(from, to);
	//float cosHalfTheta = sqrt(max(0, (cosTheta + 1) * 0.5));
	float cosHalfTheta = sqrt(max(0, (to.z + 1) * 0.5));
	//vec3 axisSinTheta = cross(from, to);
	//    0    0    1
	// to.x to.y to.z
	//vec3 axisSinTheta = vec3(-to.y, to.x, 0);
	float twoCosHalfTheta = 2 * cosHalfTheta;
	return float4(-to.y / twoCosHalfTheta, to.x / twoCosHalfTheta, 0, cosHalfTheta);
}


float2 UniformOnDisk(float Xi) {
    float theta = TWO_PI * Xi;
    return float2(cos(theta), sin(theta));
}

float3 CosOnHalfSphere(float2 Xi) {
    float r = sqrt(Xi.x);
    float2 pInDisk = r * UniformOnDisk(Xi.y);
    float z = sqrt(1 - Xi.x);
    return float3(pInDisk, z);
}

float3 CosOnHalfSphere(float2 Xi, float3 N) {
	float3 p = CosOnHalfSphere(Xi);
	float4 rot = Quat_ZTo(N);
	return Quat_Rotate(rot, p);

}


// Roughness = Alpha
float LinearRoughnessToRoughness(float linearRoughness) {
    return linearRoughness * linearRoughness;
}
float RoughnessToAlphaG2(float roughness) {
    return roughness * roughness;
}

float3 ImportanceSampleGGX(float2 u, float3 N, float alphaG2) {

    // float alphaG2 = roughness * roughness;
	
    float phi = 2.0f * PI * u.x;
    float cosTheta = sqrt((1.0f - u.y) / (1.0f + (alphaG2 * alphaG2 - 1.0f) * u.y));
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
	
    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
	
    float3 up = abs(N.z) < 0.999f ? float3(.0f, .0f, 1.0f) : float3(1.0f, .0f, .0f);
    float3 tangent = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);
	
    return tangent * H.x + bitangent * H.y + N * H.z;
}

float IBL_G_SmithGGX(float NdotV, float NdotL, float alphaG2) {
    // float alphaG2 = LinearRoughnessToAlphaG2(linearRoughness);
    const float lambdaV = NdotL * sqrt((-NdotV * alphaG2 + NdotV) * NdotV + alphaG2);
    const float lambdaL = NdotV * sqrt ((-NdotL * alphaG2 + NdotL) * NdotL + alphaG2);
    return (2 * NdotL) / max(lambdaV + lambdaL, .00001f);
    // return .5f / (lambdaV + lambdaL);
}

float pow5(float b) {
    float pow2 = b * b;
    float pow4 = pow2 * pow2;
    return pow4 * b;
}

float2 PrecomputeSpecularL_DFG(float3 V, float NdotV, float linearRoughness) {
    float roughness = LinearRoughnessToRoughness(linearRoughness);
    float alphaG2 = RoughnessToAlphaG2(roughness);
    float2 r = .0f;
    float3 N = float3(.0f, .0f, 1.0f);
    const uint SAMPLE_COUNT = 2048u;
    for (uint i = 0; i < SAMPLE_COUNT; i++) {
        float2 Xi = Hammersley(i,SAMPLE_COUNT);
        float3 H = ImportanceSampleGGX(Xi, N, alphaG2);
        float3 L = 2.0f * dot(V, H) * H - V;

        float VdotH = saturate(dot(V, H));
        float NdotL = saturate(L.z);
        float NdotH = saturate(H.z);

        if (NdotL > .0f) {
            float G = IBL_G_SmithGGX(NdotV, NdotL, alphaG2);
            float Gv = G * VdotH / NdotH;
            float Fc = pow5(1.0f - VdotH);
            r.x += Gv;
            r.y += Gv * Fc;
        }
    }

    return r / (float) SAMPLE_COUNT;
} 


float4 PrecomputeL_DFG(float NdotV, float linearRoughness) {
    float3 V = float3(sqrt(1.0f - NdotV * NdotV), .0f, NdotV);
    float4 color;
    color.xy = PrecomputeSpecularL_DFG(V, NdotV, linearRoughness);
    color.z = 0.0f;;
    color.w = 1.0f;
    return color;
}

//************************************************************************************************
//*                     Real Time IBL Functions                                              *****
//*************************************************************************************************



//***************************************************************
//*                     diffuse functions                   *****
//***************************************************************

float3 EvaluateDiffuseIBL(float3 kD, float3 N, float3 diffuse) {
    
    float3 indirectDiffuse = _GlobalEnvMapDiffuse.SampleLevel(sampler_GlobalEnvMapDiffuse, N, DIFF_IBL_MAX_MIP).rgb;
    indirectDiffuse *= diffuse * kD / PI;
    return indirectDiffuse;
}


// maxMipLevel: start from 0
float LinearRoughnessToMipmapLevel(float linearRoughness, uint maxMipLevel) {
    // return linearRoughness * maxMipLevel;
    //linearRoughness = linearRoughness * (2.0f - linearRoughness);
     linearRoughness = linearRoughness * (1.7f - .7f * linearRoughness);
    return linearRoughness * maxMipLevel;
}
//***************************************************************
//*                     Specular functions                   ****
//***************************************************************
float ComputeHorizonSpecularOcclusion(float3 R, float3 vertexNormal) {
    const float horizon = saturate(1.0f + dot(R, vertexNormal));
    return horizon * horizon;
}


float3 CompensateDirectBRDF(float2 envGF, inout float3 energyCompensation, float3 specularColor) {
    float3 reflectionGF = lerp(envGF.ggg, envGF.rrr, specularColor);
    energyCompensation = 1.0f + specularColor * (1.0f / envGF.r - 1.0f);
    
    return reflectionGF;
}

float3 GetGFFromLut(inout float3 energyCompensation, float3 specularColor, float roughness, float NdotV) {

    float2 envGF = _PreintegratedGFLut.SampleLevel(sampler_PreintegratedGFLut, float2(NdotV, roughness), 0).rg;
    return CompensateDirectBRDF(envGF, energyCompensation, specularColor);
}



float3 SampleGlobalEnvMapSpecular(float3 dir, float mipLevel) {
    return _GlobalEnvMapSpecular.SampleLevel(sampler_GlobalEnvMapSpecular, dir, mipLevel).rgb;
}

float3 EvaluateSpecularIBL(float3 kS, float3 R, float linearRoughness,float3 f0,float NdotV, out float3 specularEnergyCompensation) {
    float3 energyCompensation;

    float roughness = LinearRoughnessToRoughness(linearRoughness);
    float3 GF = GetGFFromLut(energyCompensation, f0, roughness, NdotV);
    float3 indirectSpecular = SampleGlobalEnvMapSpecular(R, LinearRoughnessToMipmapLevel(linearRoughness, SPEC_IBL_MAX_MIP));
    indirectSpecular *= GF * kS * energyCompensation;
    specularEnergyCompensation= energyCompensation;
    return indirectSpecular;
}

#endif
