#ifndef  BRDF_INCLUDED
#define  BRDF_INCLUDED
#include "IBL.hlsl"

#define PI 3.14159265359


float3 V_Kelemen(float LdotH){
	return 0.25/(LdotH *  LdotH);
}

float3 FreshnelSchlick(float3 F0, float3 LdotH) {

	return F0 + (1.0 - F0) * pow(clamp(1.0 -LdotH,0.0,1.0), 5);
}

float3 FreshnelSchlick(float3 F0, float3 V, float3 H) {
	float CosTheta = max(dot(V, H), .0001f);
	return F0 + (1.0 - F0) * pow(clamp(1.0 -CosTheta,0.0,1.0), 5);
}

float DistributionGGX(float3 N, float3 H, float roughness) {
	float alpha = roughness * roughness;
	float alpha_2 = alpha * alpha;
	float NdotH = max(dot(N, H),.0001f);
	return alpha_2 / PI / pow(NdotH * NdotH * (alpha_2 - 1.0) + 1.0, 2.0);
}

float GeometrySchlickGGX(float NdotV, float k)
{
	return NdotV / (NdotV * (1.0 - k) + k);
}
float GeometrySmith(float3 N, float3 V, float3 L, float roughness) {
	float k = pow(roughness + 1.0, 2) / 8.0;
	float NdotV = max(dot(N, V), .0001f);
	float NdotL = max(dot(N, L), .0001f);
	return GeometrySchlickGGX(NdotV, k) * GeometrySchlickGGX(NdotL, k);

}

float3 CookTorranceBRDF(float3 N, float3 V, float3 L, float3 albedo, float3 radiance, float roughness, float metallic, out float3 IBL_Diffuse, out float3 IBL_Specular) {

	// V and L are both shooted from the object
	//make  sure that both N,V and L are normalized;
	float3 H = normalize(L + V);
	float NdotL = max(dot(N, L), .0001f);
	float NdotV = max(dot(N, V), .0001f);

	float G = GeometrySmith(N, V, L, roughness);
	float NDF = DistributionGGX(N, H, roughness);

	float3 F0 = float3(0.04,0.04,0.04);
	F0 = lerp(F0, albedo, metallic);
	float3 F = FreshnelSchlick(F0, V, H);
	float3 KS = F;
	float3 KD = (1.0 - KS) * (1.f - metallic);



	float3 numerator = NDF * G * F;
	float denominator = max((4.0 * NdotL * NdotV), 0.001);
	float3 specular = numerator / denominator;


	//*********************compute indirect diffuse IBL************************
	IBL_Diffuse = EvaluateDiffuseIBL(KD, N, albedo);
	//*********************compute direct specular IBL*************************

	float3 R = reflect(-V, N);
	float3 specularEnergyConpensation;
	IBL_Specular =  EvaluateSpecularIBL(KS,R, roughness,F0,NdotV,specularEnergyConpensation);
	

	return  (specular * specularEnergyConpensation + KD * albedo / PI) * radiance * NdotL ;

}

float3 ClearCoatLightPass(float3 N, float3 V, float3 L, float3 albedo, float3 radiance, float roughness, float metallic,
	float clearCoatRoughness, float clearCoat, out float3 IBL_Diffuse, out float3 IBL_Specular)
{
	// V and L are both shooted from the object
	//make  sure that both N,V and L are normalized;
	float3 H = normalize(L + V);
	float NdotL = max(dot(N, L), .0001f);
	float NdotV = max(dot(N, V), .0001f);

	//***************************************
	// compute clear coat BRDF    ***********
	//***************************************
	float LdotH = max(saturate(dot(L, H)), .0001f);
	float Dc = DistributionGGX(N, H, clearCoatRoughness);
	float Gc = V_Kelemen(LdotH);
	float Fc = FreshnelSchlick(.04f, LdotH).r * clearCoat;
	float Frc = Dc * Gc * Fc / max((4.0 * NdotL * NdotV), 0.001);
	float baseLayerLoss = 1.0f - Fc;
	//***************************************
	// compute base layer BRDF    ***********
	//***************************************
	float G = GeometrySmith(N, V, L, roughness);
	float D = DistributionGGX(N, H, roughness);

	float3 F0 = float3(0.04,0.04,0.04);
	F0 = lerp(F0, albedo, metallic);
	float3 F = FreshnelSchlick(F0, LdotH);
	float3 KS = F;
	float3 KD = (1.0 - KS) * (1.f - metallic);

	float3 fd = KD * albedo / PI;
	float3 fr = F * G * D / max((4.0 * NdotL * NdotV), 0.001);

	//***************************************
	// compute IBL                ***********
	//***************************************
	IBL_Diffuse = EvaluateDiffuseIBL(KD, N, albedo);
	float3 R = reflect(-V, N);

	// base layer IBL
	float3 specularEnergyConpensation;
	float3 SpecularIBL =  EvaluateSpecularIBL(KS,R, roughness,F0,NdotV,specularEnergyConpensation);

	//***************************************
	// merge two layer                *******
	//***************************************

	float3 color = fd + fr * specularEnergyConpensation;
	

	color *= baseLayerLoss;
	color *= radiance * NdotL;
	color += Frc * radiance * NdotL;
	

	float fc_i = FreshnelSchlick(0.04f ,NdotV).r *  clearCoat;
	float baseLayerLoss_i = 1.0f - fc_i;

	IBL_Diffuse *= baseLayerLoss_i;
	//clear coat layer IBL 
	float linearClearCoatRoughness = LinearRoughnessToRoughness(clearCoatRoughness);
	float3 clearCoatSpecularIBL = SampleGlobalEnvMapSpecular(R, LinearRoughnessToMipmapLevel(linearClearCoatRoughness, SPEC_IBL_MAX_MIP));
	
	
	IBL_Specular  = fc_i * clearCoatSpecularIBL + baseLayerLoss_i * SpecularIBL;
	return color;
}


#endif // ! BRDF_INCLUDED
