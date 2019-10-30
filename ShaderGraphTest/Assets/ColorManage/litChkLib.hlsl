#ifndef SEGATB_CHS_INCLUDED
#define SEGATB_CHS_INCLUDED
// ------------------------------------------------------------------------------------
// SEGATB _ COMMON FOR ALL PASS
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
CBUFFER_START(UnityPerCamera)
float4 _Time;	float3 _WorldSpaceCameraPos;	float4 _ProjectionParams;	float4 _ScreenParams;	float4 _ZBufferParams;	float4 unity_OrthoParams;
CBUFFER_END
CBUFFER_START(UnityPerCameraRare)
float4x4 unity_CameraToWorld;
CBUFFER_END
CBUFFER_START(UnityLighting)
float4 _WorldSpaceLightPos0;
float4 unity_4LightPosX0;	float4 unity_4LightPosY0;	float4 unity_4LightPosZ0;	half4 unity_4LightAtten0;	half4 unity_LightColor[8];
half4 unity_DynamicLightmap_HDR;
CBUFFER_END
CBUFFER_START(UnityShadows)
float4 unity_LightShadowBias;
CBUFFER_END
CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;	float4x4 unity_WorldToObject;	float4 unity_LODFade;	float4 unity_WorldTransformParams;
real4 unity_SpecCube0_HDR;
float4 unity_LightmapST;	float4 unity_DynamicLightmapST;
real4 unity_SHAr;	real4 unity_SHAg;	real4 unity_SHAb;	real4 unity_SHBr;	real4 unity_SHBg;	real4 unity_SHBb;	real4 unity_SHC;
CBUFFER_END
CBUFFER_START(UnityPerFrame)
float4x4 glstate_matrix_projection;	float4x4 unity_MatrixV;	float4x4 unity_MatrixInvV;	float4x4 unity_MatrixVP;
CBUFFER_END
CBUFFER_START(UnityReflectionProbes)
float4 unity_SpecCube0_BoxMax;	float4 unity_SpecCube0_BoxMin;	float4 unity_SpecCube0_ProbePosition;
CBUFFER_END
#define UNITY_MATRIX_M     unity_ObjectToWorld
#define UNITY_MATRIX_I_M   unity_WorldToObject
#define UNITY_MATRIX_V     unity_MatrixV
#define UNITY_MATRIX_I_V   unity_MatrixInvV
#define UNITY_MATRIX_P     OptimizeProjectionMatrix(glstate_matrix_projection)
#define UNITY_MATRIX_VP    unity_MatrixVP
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

float4x4 OptimizeProjectionMatrix(float4x4 M)
{
	M._21_41 = 0;
	M._12_42 = 0;
	return M;
}

float3 CheckColorValue(float3 color, float targetValue, float targetScale, float range)
{
	targetValue *= targetScale;
	float lum = dot(color, float3(0.2126729, 0.7151522, 0.072175));
	float3 outColor;
	outColor.g = saturate(max(range - abs(lum - targetValue), 0.0) * 10000) * 1.2; // just in range
	outColor.r = saturate(max(lum - targetValue + range, 0.0) * 10000) - outColor.g * 0.5; // over    range
	outColor.b = saturate(max(targetValue - lum + range, 0.0) * 10000) - outColor.g * 0.5; // under   range

	float rhythm = sin(lum / targetScale * 10.0 + _Time.w) * 0.35;
	outColor.g += 0.123;
	return outColor * (0.65 + rhythm);
}

// ------------------------------------------------------------------------------------
//
#ifdef SEGATB_FORWARD

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

float _ChkTargetValue, _ChkTargetScale, _ChkRange;
half4 _LightColor0;

UNITY_INSTANCING_BUFFER_START(PerInstance)
UNITY_DEFINE_INSTANCED_PROP(float4, _AlbedoColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float, _Anisotropy)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_DEFINE_INSTANCED_PROP(float, _EmitIntensity)
UNITY_INSTANCING_BUFFER_END(PerInstance)

TEXTURE2D_SHADOW(_ShadowMapTexture);	SAMPLER(sampler_ShadowMapTexture);
TEXTURECUBE(unity_SpecCube0);			SAMPLER(samplerunity_SpecCube0);
TEXTURE2D(unity_Lightmap);				SAMPLER(samplerunity_Lightmap);
TEXTURE2D(unity_LightmapInd);
TEXTURE2D(unity_DynamicLightmap);		SAMPLER(samplerunity_DynamicLightmap);
TEXTURE2D(unity_DynamicDirectionality);
TEXTURE2D(_MainTex);					SAMPLER(sampler_MainTex);
TEXTURE2D(_MetallicGlossMap);			SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_NormalMap);					SAMPLER(sampler_NormalMap);

// ------------------------------------------------------------------
struct VertexInput
{
	float4 posOS	 : POSITION;
	float3 normalOS  : NORMAL;
	float4 tangentOS : TANGENT;
	float4 uv0		 : TEXCOORD0;
	float2 uvLM		 : TEXCOORD1;
	float2 uvDLM	 : TEXCOORD2;
	float4 vColor	 : COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct VertexOutput
{
	float4 posCS					 : SV_POSITION;
	float4 uv						 : TEXCOORD0;
	float4 tangentToWorldAndPosWS[3] : TEXCOORD1;
	float3 viewDirWS				 : TEXCOORD4;
	float4 posNDC					 : TEXCOORD5;
	float4 ambientOrLightmapUV		 : TEXCOORD6;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct GeometrySTB
{
	float3 posWS;
	float3 verNormalWS;
	float3 normalWS;
	float3 tangentWS;
	float3 binormalWS;
};
struct CameraSTB
{
	float3 posWS;
	float3 dirWS;
	float  distanceWS;
	float2 pixelPosSCS;
};
struct LightSTB
{
	float3 dirWS;
	float3 color;
	float  atten;
};
struct SubLightsGeometrySTB
{
	float3 lightVectorWS[4];
	float  distanceSqr[4];
	float  lightAtten[4];
};
struct MaterialSTB
{
	float3 albedoColor;
	float3 reflectColor;
	float  grazingTerm;
	float  alpha;
	float  perceptualRoughness;
	float2 anisoRoughness;
	float  surfaceReduction;
	float  microOcclusion;
	float3 emitColor;
	float3 testValue;
	float  reflectOneForTest;
};
struct LitParamPerViewSTB
{
	float  specOcclusion;
	float  NdotV;
	float  envRefl_fv;
	float3 reflViewWS;
	float  partLambdaV;
};
struct LitParamPerLightSTB
{
	float3 specularColor;
	float3 diffuseColor;
	float3 testValue;
};
struct LitParamPerEnvironmentSTB
{
	float3 reflectColor;
	float3 diffuseColor;
	float3 testValue;
};

float4 GetPosNDC(float4 posCS)
{
	float4 posNDC;
	float4 ndc = posCS * 0.5f;
	posNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
	posNDC.zw = posCS.zw;
	return posNDC;
}

float F_Pow5(float u)
{
	float x = 1.0 - u;
	float x2 = x * x;
	float x5 = x * x2 * x2;
	return x5;
}

float3 BoxProjectedCubemapDirection(float3 reflViewWS, float3 posWS, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{
	UNITY_BRANCH if (cubemapCenter.w > 0.0)
	{
		float3 nrdir = normalize(reflViewWS);
		float3 rbmax = (boxMax.xyz - posWS) / nrdir;
		float3 rbmin = (boxMin.xyz - posWS) / nrdir;
		float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;
		float  fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
		posWS -= cubemapCenter.xyz;
		reflViewWS = posWS + nrdir * fa;
	}
	return reflViewWS;
}

// ------------------------------------------------------------------
GeometrySTB GetGeometry(VertexOutput input, float2 uv)
{
	GeometrySTB output;
	output.posWS = float3(input.tangentToWorldAndPosWS[0].w, input.tangentToWorldAndPosWS[1].w, input.tangentToWorldAndPosWS[2].w);
	float3 verTangentWS = input.tangentToWorldAndPosWS[0].xyz;
	float3 verBinormalWS = input.tangentToWorldAndPosWS[1].xyz;
	output.verNormalWS = normalize(input.tangentToWorldAndPosWS[2].xyz);

#ifdef _NORMALMAP
	half4  normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv);
	float3 normalMapTS;
	normalMapTS.xy = normalMap.wy *2.0 - 1.0;
	normalMapTS.z = sqrt(1.0 - saturate(dot(normalMapTS.xy, normalMapTS.xy)));
	output.normalWS = normalize(verTangentWS * normalMapTS.x + verBinormalWS * normalMapTS.y + output.verNormalWS * normalMapTS.z);
	output.tangentWS = normalize(verTangentWS - dot(verTangentWS, output.normalWS) * output.normalWS);
	float3 newBB = cross(output.normalWS, output.tangentWS);
	output.binormalWS = newBB * FastSign(dot(newBB, verBinormalWS));
#else
	output.normalWS = output.verNormalWS;
	output.tangentWS = normalize(verTangentWS);
	output.binormalWS = normalize(verBinormalWS);
#endif
	return output;
}

CameraSTB GetCamera(VertexOutput input, GeometrySTB geo)
{
	CameraSTB output;
	output.posWS = _WorldSpaceCameraPos;
	output.dirWS = normalize(input.viewDirWS);
	output.distanceWS = LinearEyeDepth(geo.posWS, UNITY_MATRIX_V);
	output.pixelPosSCS = input.posNDC.xy / input.posNDC.w;
	return output;
}

LightSTB GetMainLight(CameraSTB cam)
{
	LightSTB output;
#if defined (DIRECTIONAL) || defined (DIRECTIONAL_COOKIE)
#if defined(_NOPIDIV) && !defined(_VSUN_LIGHT_COLOR) && !defined(_VPOINT_LIGHT_COLOR)
	output.color = _LightColor0.rgb *PI;
#else
	output.color = _LightColor0.rgb;
#endif
	half atten = 1.0;
#if defined(SHADOWS_SCREEN)
	atten = SAMPLE_TEXTURE2D(_ShadowMapTexture, sampler_ShadowMapTexture, cam.pixelPosSCS).x;
#endif
	output.atten = atten;
	output.dirWS = _WorldSpaceLightPos0.xyz;
#else
	output.color = 0;
	output.atten = 0;
	output.dirWS = float3(0, 0, 1);
#endif
	return output;
}

SubLightsGeometrySTB GetSubLightsGeometry(GeometrySTB geo)
{
	SubLightsGeometrySTB output;
	float4 toLightX = unity_4LightPosX0 - geo.posWS.x;
	float4 toLightY = unity_4LightPosY0 - geo.posWS.y;
	float4 toLightZ = unity_4LightPosZ0 - geo.posWS.z;
	float4 distanceSqr = 0.0;
	distanceSqr += toLightX * toLightX;
	distanceSqr += toLightY * toLightY;
	distanceSqr += toLightZ * toLightZ;
	output.lightVectorWS[0] = float3(toLightX.x, toLightY.x, toLightZ.x);
	output.lightVectorWS[1] = float3(toLightX.y, toLightY.y, toLightZ.y);
	output.lightVectorWS[2] = float3(toLightX.z, toLightY.z, toLightZ.z);
	output.lightVectorWS[3] = float3(toLightX.w, toLightY.w, toLightZ.w);
	output.distanceSqr[0] = distanceSqr.x;
	output.distanceSqr[1] = distanceSqr.y;
	output.distanceSqr[2] = distanceSqr.z;
	output.distanceSqr[3] = distanceSqr.w;
	output.lightAtten[0] = unity_4LightAtten0.x;
	output.lightAtten[1] = unity_4LightAtten0.y;
	output.lightAtten[2] = unity_4LightAtten0.z;
	output.lightAtten[3] = unity_4LightAtten0.w;
	return output;
}

LightSTB GetSubLight(uint index, SubLightsGeometrySTB subLightsGeo)
{
	LightSTB output;
#if defined(_NOPIDIV) && !defined(_VSUN_LIGHT_COLOR) && !defined(_VPOINT_LIGHT_COLOR)
	output.color = unity_LightColor[index].xyz * PI;
#else
	output.color = unity_LightColor[index].xyz;
#endif

	UNITY_BRANCH if ((output.color.r + output.color.g + output.color.b) != 0.0)
	{
		float distanceSqr = max(subLightsGeo.distanceSqr[index], (PUNCTUAL_LIGHT_THRESHOLD * PUNCTUAL_LIGHT_THRESHOLD));
#if defined(_NOPIDIV)
		output.atten = 1.0 / (1.0 + distanceSqr * subLightsGeo.lightAtten[index]);
#else
		float invDistanceSqr = 1.0 / distanceSqr;
		float lightAttenFactor = distanceSqr * subLightsGeo.lightAtten[index] * 0.04;
		lightAttenFactor *= lightAttenFactor;
		lightAttenFactor = saturate(1.0 - lightAttenFactor);
		lightAttenFactor *= lightAttenFactor;
		output.atten = max(invDistanceSqr * lightAttenFactor, 0.0);
#endif
		output.dirWS = SafeNormalize(subLightsGeo.lightVectorWS[index]);
	}
	else
	{
		output.atten = 0.0;
		output.dirWS = float3(0, 0, 1);
	}
	return output;
}

MaterialSTB GetMaterial(float2 uv)
{
	MaterialSTB output;
	half4 colParams = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
	half4 matParams = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
	float4 matColor = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _AlbedoColor);
	float  metallic = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Metallic);
	float  anisotropy = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Anisotropy);
	float  smoothness = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Smoothness);
	float  emmision = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _EmitIntensity);
	float  occlusion = 1.0;
#ifdef _COLMAP
	matColor *= colParams;
#endif
#ifdef _METMAP
	metallic *= matParams.x;
#endif
#ifdef _OCCMAP
	occlusion *= matParams.y;
#endif
#ifdef _SMTMAP
	smoothness *= matParams.w;
#endif

	float oneMinusReflectivity = (1.0 - metallic) * 0.96;
	output.albedoColor = matColor.rgb * oneMinusReflectivity;
	output.reflectColor = lerp(half3(0.04, 0.04, 0.04), matColor.rgb, metallic);
	output.grazingTerm = saturate(smoothness + (1.0 - oneMinusReflectivity));
	output.alpha = matColor.a;
	output.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
	ConvertAnisotropyToRoughness(output.perceptualRoughness, anisotropy, output.anisoRoughness.x, output.anisoRoughness.y);
	output.anisoRoughness.x = max(output.anisoRoughness.x, 0.0005);
	output.anisoRoughness.y = max(output.anisoRoughness.y, 0.0005);
	output.surfaceReduction = 1.0 / (output.perceptualRoughness * output.perceptualRoughness + 1.0);
	output.microOcclusion = occlusion;
	output.emitColor = matColor.rgb * emmision;

#if defined(_VMAT_COLOR)
	output.testValue = matColor.rgb;
#elif defined(_VMAT_DIFFUSE_COLOR)
	output.testValue = output.albedoColor;
#elif defined(_VMAT_METALLIC)
	output.testValue = metallic;
#elif defined(_VMAT_SMOOTHNESS)
	output.testValue = smoothness;
#elif defined(_VMAT_OCCLUSION)
	output.testValue = occlusion;
#else
	output.testValue = 0;
#endif
	output.reflectOneForTest = lerp(0.04, 1.0, metallic);
	return output;
}

LitParamPerViewSTB GetLitParamPerView(GeometrySTB geo, CameraSTB cam, MaterialSTB mat)
{
	LitParamPerViewSTB output;
	output.specOcclusion = GetHorizonOcclusion(cam.dirWS, geo.normalWS, geo.verNormalWS, 0.8);
	output.NdotV = ClampNdotV(dot(geo.normalWS, cam.dirWS));
	output.envRefl_fv = F_Pow5(saturate(output.NdotV));
	output.reflViewWS = reflect(-cam.dirWS, geo.normalWS);
	float TdotV = dot(geo.tangentWS, cam.dirWS);
	float BdotV = dot(geo.binormalWS, cam.dirWS);
	output.partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, output.NdotV, mat.anisoRoughness.x, mat.anisoRoughness.y);
	return output;
}

LitParamPerLightSTB GetLitByTheLight(GeometrySTB geo, CameraSTB cam, MaterialSTB mat, LitParamPerViewSTB lip, LightSTB theLight)
{
	LitParamPerLightSTB output;
	float NdotL = dot(geo.normalWS, theLight.dirWS);
#if defined(_VSUN__) && defined(_VPOINT__)
	UNITY_BRANCH if (NdotL > 0.0)
	{
#endif
		float3 halfDir = SafeNormalize(theLight.dirWS + cam.dirWS);
		float LdotV = dot(theLight.dirWS, cam.dirWS);
		float NdotH = dot(geo.normalWS, halfDir);
		float LdotH = dot(theLight.dirWS, halfDir);
		float TdotL = dot(geo.tangentWS, theLight.dirWS);
		float BdotL = dot(geo.binormalWS, theLight.dirWS);
		float TdotH = dot(geo.tangentWS, halfDir);
		float BdotH = dot(geo.binormalWS, halfDir);
		float spec_fv = F_Pow5(saturate(LdotH));
		float  occlusion = ComputeMicroShadowing(mat.microOcclusion * 1.6 + 0.2, NdotL, 1.0);
		float3 occlusionCol = GTAOMultiBounce(occlusion, mat.albedoColor);

		float  specTermD = D_GGXAniso(TdotH, BdotH, NdotH, mat.anisoRoughness.x, mat.anisoRoughness.y);
		float  specTermG = V_SmithJointGGXAniso(0, 0, lip.NdotV, TdotL, BdotL, NdotL, mat.anisoRoughness.x, mat.anisoRoughness.y, lip.partLambdaV);
		float3 specTermF = mat.reflectColor + (1 - mat.reflectColor) * spec_fv;
		output.specularColor = (specTermD * specTermG * saturate(NdotL) * theLight.atten * occlusion * lip.specOcclusion) * specTermF * theLight.color;

		float  diffuseTerm = DisneyDiffuse(lip.NdotV, NdotL, LdotV, mat.perceptualRoughness);
		output.diffuseColor = (diffuseTerm * saturate(NdotL) * theLight.atten * occlusionCol) * theLight.color;

#if defined(_VSUN_LIGHT_COLOR) || defined(_VPOINT_LIGHT_COLOR)
		output.testValue = theLight.color;
#elif defined(_VSUN_LIGHT_ILLUMINANCE) || defined(_VPOINT_LIGHT_ILLUMINANCE) || defined(_VGET_TOTAL_ILLUMINANCE)
		output.testValue = theLight.color *saturate(NdotL) * theLight.atten * occlusion;
#elif defined(_VSUN_SHADE_LAMBERT) || defined(_VPOINT_SHADE_LAMBERT)
		output.testValue = theLight.color *saturate(NdotL) * theLight.atten * occlusion *INV_PI;
#elif defined(_VSUN_SHADE_SPECULAR) || defined(_VPOINT_SHADE_SPECULAR) || defined(_VGET_TOTAL_REFLECTION)
		output.testValue = (specTermD * specTermG * saturate(NdotL) * theLight.atten * occlusion * lip.specOcclusion) * (mat.reflectOneForTest + (1 - mat.reflectOneForTest) * spec_fv) * theLight.color;
#elif defined(_VSUN_SHADE_SPEC_DGF) || defined(_VPOINT_SHADE_SPEC_DGF)
		output.testValue.r = specTermD;
		output.testValue.g = specTermG;
		output.testValue.b = specTermF;
#elif defined(_VSUN_SHADE_SPEC_D) || defined(_VPOINT_SHADE_SPEC_D)
		output.testValue = specTermD;
#elif defined(_VSUN_SHADE_SPEC_G) || defined(_VPOINT_SHADE_SPEC_G)
		output.testValue = specTermG;
#elif defined(_VSUN_SHADE_SPEC_F) || defined(_VPOINT_SHADE_SPEC_F)
		output.testValue = mat.reflectOneForTest + (1 - mat.reflectOneForTest) * spec_fv;
#else
		output.testValue = 0;
#endif
#if defined(_VSUN__) && defined(_VPOINT__)
	}
	else
	{
		output.specularColor = 0.0;
		output.diffuseColor = 0.0;
		output.testValue = 0;
	}
#endif
	return output;
}

LitParamPerEnvironmentSTB GetLitByEnvironment(VertexOutput input, GeometrySTB geo, MaterialSTB mat, LitParamPerViewSTB lip)
{
	LitParamPerEnvironmentSTB output;
	float  occlusion = ComputeMicroShadowing(mat.microOcclusion * 0.8 + 0.3, lip.NdotV, 1.0);
	float3 occlusionCol = GTAOMultiBounce(saturate(mat.microOcclusion *1.2), mat.albedoColor);

#if defined(LIGHTPROBE_SH)
	output.diffuseColor = max(SHEvalLinearL0L1(geo.normalWS, unity_SHAr, unity_SHAg, unity_SHAb) + input.ambientOrLightmapUV.rgb, 0.0);
#elif defined(DIRLIGHTMAP_COMBINED)
	half4 decodeInstructions = half4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0h, 0.0h);
	{
		float4 direction = SAMPLE_TEXTURE2D(unity_LightmapInd, samplerunity_Lightmap, input.ambientOrLightmapUV.xy);
		float4 encodedIlluminance = SAMPLE_TEXTURE2D(unity_Lightmap, samplerunity_Lightmap, input.ambientOrLightmapUV.xy);
		float3 illuminance = DecodeLightmap(encodedIlluminance, decodeInstructions);
		float  halfLambert = dot(geo.normalWS, direction.xyz - 0.5) + 0.5;
		output.diffuseColor = illuminance * halfLambert / max(1e-4, direction.w);
	}
#if defined(DYNAMICLIGHTMAP_ON)
	{
		float4 direction = SAMPLE_TEXTURE2D(unity_DynamicDirectionality, samplerunity_DynamicLightmap, input.ambientOrLightmapUV.zw);
		float4 encodedIlluminance = SAMPLE_TEXTURE2D(unity_DynamicLightmap, samplerunity_DynamicLightmap, input.ambientOrLightmapUV.zw);
		float3 illuminance = DecodeLightmap(encodedIlluminance, decodeInstructions);
		float  halfLambert = dot(geo.normalWS, direction.xyz - 0.5) + 0.5;
		output.diffuseColor += illuminance * halfLambert / max(1e-4, direction.w);
	}
#endif
#else
	output.diffuseColor = 0.0;
#endif
	output.diffuseColor *= occlusionCol;

#if defined(UNITY_SPECCUBE_BOX_PROJECTION)
	float3 reflViewWS = BoxProjectedCubemapDirection(lip.reflViewWS, geo.posWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
#else
	float3 reflViewWS = lip.reflViewWS;
#endif
	half  reflMipLevel = PerceptualRoughnessToMipmapLevel(mat.perceptualRoughness);
	half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflViewWS, reflMipLevel);
#if !defined(UNITY_USE_NATIVE_HDR)
	half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
#else
	half3 irradiance = encodedIrradiance.rbg;
#endif
	output.reflectColor = mat.microOcclusion * mat.surfaceReduction * irradiance * lerp(mat.reflectColor, mat.grazingTerm, lip.envRefl_fv);

#if defined(_VENV_LIGHT_ILLUMINANCE)
	output.testValue = output.diffuseColor *PI;
#elif defined(_VENV_SHADE_LAMBERT)
	output.testValue = output.diffuseColor;
#elif defined(_VENV_SHADE_REFLECTION)
	output.testValue = mat.microOcclusion * mat.surfaceReduction * irradiance * lerp(1.0, mat.grazingTerm, lip.envRefl_fv);
#elif defined(_VMAT_SPECULAR_COLOR)
	output.testValue = lerp(mat.reflectColor, mat.grazingTerm, lip.envRefl_fv);
#elif defined(_VGET_TOTAL_ILLUMINANCE)
	output.testValue = output.diffuseColor *PI;
#elif defined(_VGET_TOTAL_REFLECTION)
	output.testValue = occlusion * mat.surfaceReduction * irradiance;
#else
	output.testValue = 0;
#endif
	return output;
}

// ------------------------------------------------------------------
VertexOutput ChsForwardVertex(VertexInput input)
{
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);

	float4 posWS = mul(UNITY_MATRIX_M, float4(input.posOS.xyz, 1.0));
	output.posCS = mul(UNITY_MATRIX_VP, posWS);

	float3   camPosWS = _WorldSpaceCameraPos;
	output.viewDirWS = camPosWS - posWS.xyz;

	float3   normalWS = normalize(mul((float3x3) UNITY_MATRIX_M, input.normalOS));
	float4   tangentWS = float4(normalize(mul((float3x3) UNITY_MATRIX_M, input.tangentOS.xyz)), input.tangentOS.w);
	float    sign = tangentWS.w * unity_WorldTransformParams.w;
	float3   binormalWS = cross(normalWS, tangentWS.xyz) * sign;

	float4 ndc = output.posCS * 0.5f;
	output.posNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
	output.posNDC.zw = output.posCS.zw;

#ifdef DIRLIGHTMAP_COMBINED
	output.ambientOrLightmapUV.xy = input.uvLM.xy  * unity_LightmapST.xy + unity_LightmapST.zw;
#ifdef DYNAMICLIGHTMAP_ON
	output.ambientOrLightmapUV.zw = input.uvDLM.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#else
	output.ambientOrLightmapUV.zw = 0;
#endif
#elif LIGHTPROBE_SH
	output.ambientOrLightmapUV.rgb = SHEvalLinearL2(normalWS, unity_SHBr, unity_SHBg, unity_SHBb, unity_SHC);
	output.ambientOrLightmapUV.w = 0;
#else
	output.ambientOrLightmapUV = 0;
#endif

	output.uv.xy = input.uv0.xy;
	output.uv.zw = 0;
	output.tangentToWorldAndPosWS[0].xyz = tangentWS.xyz;
	output.tangentToWorldAndPosWS[1].xyz = binormalWS;
	output.tangentToWorldAndPosWS[2].xyz = normalWS;
	output.tangentToWorldAndPosWS[0].w = posWS.x;
	output.tangentToWorldAndPosWS[1].w = posWS.y;
	output.tangentToWorldAndPosWS[2].w = posWS.z;
	return output;
}

float4 ChsForwardFragment(VertexOutput input) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(input);
	float2             uv = input.uv.xy;
	GeometrySTB        geo = GetGeometry(input, uv);
	CameraSTB          cam = GetCamera(input, geo);
	MaterialSTB        mat = GetMaterial(uv);
	LitParamPerViewSTB lip = GetLitParamPerView(geo, cam, mat);

	LightSTB            sun = GetMainLight(cam);
	LitParamPerLightSTB litSun = GetLitByTheLight(geo, cam, mat, lip, sun);

	LitParamPerEnvironmentSTB litEnv = GetLitByEnvironment(input, geo, mat, lip);

	LitParamPerLightSTB litSubLights;
	litSubLights.diffuseColor = 0.0;
	litSubLights.specularColor = 0.0;
	litSubLights.testValue = 0.0;
#ifdef LIGHTPROBE_SH
 #ifdef VERTEXLIGHT_ON
	SubLightsGeometrySTB subLightsGeo = GetSubLightsGeometry(geo);
	for (int i = 0; i < 3; i++) {
		LightSTB subLight = GetSubLight(i, subLightsGeo);
		UNITY_BRANCH if (subLight.atten != 0.0)
		{
			LitParamPerLightSTB litSubLight = GetLitByTheLight(geo, cam, mat, lip, subLight);
			litSubLights.diffuseColor += litSubLight.diffuseColor;
			litSubLights.specularColor += litSubLight.specularColor;
			litSubLights.testValue += litSubLight.testValue;
		}
	}
 #endif
#endif

	float3 color = (litSun.diffuseColor + litEnv.diffuseColor + litSubLights.diffuseColor) * mat.albedoColor + litSun.specularColor + litEnv.reflectColor + litSubLights.specularColor + mat.emitColor;
	float  alpha = mat.alpha;

#if defined(_VMAT_COLOR) || defined(_VMAT_DIFFUSE_COLOR) || defined(_VMAT_METALLIC) || defined(_VMAT_SMOOTHNESS) || defined(_VMAT_OCCLUSION)
	color = mat.testValue;
#elif defined(_VGET_TOTAL_ILLUMINANCE) || defined(_VGET_TOTAL_REFLECTION)
	color = litSun.testValue + litEnv.testValue + litSubLights.testValue;
#elif defined(_VGET_SUN_ONLY)
	color = litSun.diffuseColor * mat.albedoColor + litSun.specularColor;
#elif defined(_VGET_ENV_ONLY)
	color = litEnv.diffuseColor * mat.albedoColor + litEnv.reflectColor;
#elif defined(_VGET_POINTLIGHT_ONLY)
	color = litSubLights.diffuseColor * mat.albedoColor + litSubLights.specularColor;
#elif defined(_VSUN_LIGHT_COLOR) || defined(_VSUN_LIGHT_ILLUMINANCE) || defined(_VSUN_SHADE_LAMBERT) || defined(_VSUN_SHADE_SPECULAR) || defined(_VSUN_SHADE_SPEC_DGF) || defined(_VSUN_SHADE_SPEC_D) || defined(_VSUN_SHADE_SPEC_G) || defined(_VSUN_SHADE_SPEC_F)
	color = litSun.testValue;
#elif defined(_VENV_LIGHT_ILLUMINANCE) || defined(_VENV_SHADE_LAMBERT) || defined(_VENV_SHADE_REFLECTION) || defined(_VMAT_SPECULAR_COLOR)
	color = litEnv.testValue;
#elif defined(_VPOINT_LIGHT_COLOR) || defined(_VPOINT_LIGHT_ILLUMINANCE) || defined(_VPOINT_SHADE_LAMBERT) || defined(_VPOINT_SHADE_SPECULAR) || defined(_VPOINT_SHADE_SPEC_DGF) || defined(_VPOINT_SHADE_SPEC_D) || defined(_VPOINT_SHADE_SPEC_G) || defined(_VPOINT_SHADE_SPEC_F)
	color = litSubLights.testValue;
#endif

#ifdef _CHECKVALUE
	color = CheckColorValue(color, _ChkTargetValue, _ChkTargetScale, _ChkRange);
#endif
	return float4(color, alpha);
}

#endif //SEGATB_FORWARD
// ---------------------------------------------------------------------------
//
#ifdef SEGATB_SHADOWCASTER

struct VertexInput
{
	float4 posOS    : POSITION;
	float3 normalOS : NORMAL;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct VertexOutput
{
	float4 posCS : SV_POSITION;
};

// ------------------------------------------------------------------
VertexOutput DepthOnlyVertex(VertexInput input)
{
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);

	float4 posWS = mul(UNITY_MATRIX_M, float4(input.posOS.xyz, 1.0));

	if (unity_LightShadowBias.z != 0.0)
	{
		float3 normalWS = normalize(mul((float3x3) UNITY_MATRIX_M, input.normalOS));
		float3 lightDirWS = normalize(_WorldSpaceLightPos0.xyz - posWS.xyz * _WorldSpaceLightPos0.w);
		float  shadowCos = dot(normalWS, lightDirWS);
		float  shadowSine = sqrt(1 - shadowCos * shadowCos);
		float  normalBias = unity_LightShadowBias.z * shadowSine;
		posWS.xyz -= normalWS * normalBias;
	}

	output.posCS = mul(UNITY_MATRIX_VP, posWS);

	if (unity_LightShadowBias.y != 0.0)
	{
#ifdef UNITY_REVERSED_Z
		output.posCS.z += max(-1, min(unity_LightShadowBias.x / output.posCS.w, 0));
		output.posCS.z = min(output.posCS.z, output.posCS.w * UNITY_NEAR_CLIP_VALUE);
#else
		output.posCS.z += saturate(unity_LightShadowBias.x / output.posCS.w);
		output.posCS.z = max(output.posCS.z, output.posCS.w * UNITY_NEAR_CLIP_VALUE);
#endif
	}
	return output;
}

half4 DepthOnlyFragment(VertexOutput input) : SV_TARGET
{
	return 0;
}

#endif //SEGATB_SHADOWCASTER
// ---------------------------------------------------------------------------
//
#ifdef SEGATB_META

float4 _AlbedoColor;
float  _Metallic, _EmitIntensity;
float  unity_OneOverOutputBoost;
float  unity_MaxOutputValue;
float  unity_UseLinearSpace;

CBUFFER_START(UnityMetaPass)
bool4 unity_MetaVertexControl;	 // x = use uv1 as raster position	// y = use uv2 as raster position
bool4 unity_MetaFragmentControl; // x = return albedo				// y = return normal
CBUFFER_END

TEXTURE2D(_MainTex);            SAMPLER(sampler_MainTex);
TEXTURE2D(_MetallicGlossMap);	SAMPLER(sampler_MetallicGlossMap);

// ------------------------------------------------------------------
struct VertexInput
{
	float4 posOS : POSITION;
	float2 uv0   : TEXCOORD0;
	float2 uvLM  : TEXCOORD1;
	float2 uvDLM : TEXCOORD2;
};
struct VertexOutput
{
	float4 posCS : SV_POSITION;
	float4 uv    : TEXCOORD0;
};
struct MaterialSTB
{
	float3 albedoColor;
	float3 emitColor;
};

// ------------------------------------------------------------------
MaterialSTB GetMaterial(float2 uv)
{
	MaterialSTB output;
	half4 colParams = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
	half4 matParams = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
	float4 matColor = _AlbedoColor;
	float metallic = _Metallic;
	float emmision = _EmitIntensity;
#ifdef _COLMAP
	matColor *= colParams;
#endif
#ifdef _METMAP
	metallic *= matParams.x;
#endif

#if !defined(EDITOR_VISUALIZATION)
	output.albedoColor = matColor.rgb *(1.0 - metallic * 0.5)  *(0.5 + matColor.a *0.5);
#else
	output.albedoColor = matColor;
#endif

	output.emitColor = matColor.rgb * emmision;
	return output;
}

// ------------------------------------------------------------------
VertexOutput MetaVertex(VertexInput input)
{
	VertexOutput output;

	float3 posTXS = input.posOS.xyz;
	if (unity_MetaVertexControl.x)
	{
		posTXS.xy = input.uvLM * unity_LightmapST.xy + unity_LightmapST.zw;
		posTXS.z = posTXS.z > 0 ? REAL_MIN : 0.0f;
	}
	if (unity_MetaVertexControl.y)
	{
		posTXS.xy = input.uvDLM * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
		posTXS.z = posTXS.z > 0 ? REAL_MIN : 0.0f;
	}
	output.posCS = mul(UNITY_MATRIX_VP, float4(posTXS, 1.0));

	output.uv.xy = input.uv0.xy;
	output.uv.zw = 0;
	return output;
}

half4 MetaFragment(VertexOutput input) : SV_TARGET
{
	half4 color = 0;
	float2 uv = input.uv.xy;

	MaterialSTB mat = GetMaterial(uv);

	if (unity_MetaFragmentControl.x)
	{
		color = half4(mat.albedoColor, 1.0);
		unity_OneOverOutputBoost = saturate(unity_OneOverOutputBoost);	// d3d9 shader compiler doesn't like NaNs and infinity.   
		color.rgb = clamp(PositivePow(color.rgb, unity_OneOverOutputBoost), 0, unity_MaxOutputValue);	// Apply Albedo Boost from LightmapSettings.
	}
	if (unity_MetaFragmentControl.y)
	{
		color = half4(mat.emitColor, 1.0);
	}
	return color;
}

#endif //SEGATB_META
// ---------------------------------------------------------------------------
// ------------------------------------------------------------------------------------
#endif //SEGATB_CHS_INCLUDED