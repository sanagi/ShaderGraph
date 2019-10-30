Shader "SegaTechBlog/lightingChecker" {
	Properties{
		[Header(__ Material Params __________)][Space(5)]
		_AlbedoColor("Color",      Color) = (0.4663, 0.4663, 0.4663, 1)
		_Metallic("Metallic",   Range(0.0, 1.0)) = 0.0
		_Anisotropy("Anisotropy", Range(-1.0, 1.0)) = 0.0
		_Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5[Space(15)]
		[Toggle(_COLMAP)]   _UseColorMap("@ Color Map",                    Float) = 1
		[NoScaleOffset]     _MainTex("Color(RGB), Alpha(A)",            2D) = "white" {}
		[Toggle(_METMAP)]   _UseMetMap("@ Mat Map:Metallic",             Float) = 1
		[Toggle(_OCCMAP)]   _UseOccMap("@ Mat Map:Occlusion",            Float) = 1
		[Toggle(_SMTMAP)]   _UseSmtMap("@ Mat Map:Smoothness",           Float) = 1
		[NoScaleOffset]     _MetallicGlossMap("Metal(R), Occlude(G), Smooth(A)", 2D) = "white" {}
		[Toggle(_NORMALMAP)]_UseNormalMap("@ Normal Map",                   Float) = 0
		[NoScaleOffset]     _NormalMap("Tangent Normal(RGB)",             2D) = "bump" {}
		[Header(__ View One Element ___________)][Space(5)]
				  [KeywordEnum(_,COLOR,DIFFUSE_COLOR,SPECULAR_COLOR,METALLIC,SMOOTHNESS,OCCLUSION)]_VMAT("> View Material Element", Float) = 0
		[Space(5)][KeywordEnum(_,LIGHT_COLOR,LIGHT_ILLUMINANCE,SHADE_LAMBERT,SHADE_SPECULAR,SHADE_SPEC_DGF,SHADE_SPEC_D,SHADE_SPEC_G,SHADE_SPEC_F)]_VSUN("> View Sun Light Element", Float) = 0
		[Space(5)][KeywordEnum(_,LIGHT_ILLUMINANCE,SHADE_LAMBERT,SHADE_REFLECTION)]_VENV("> View Environment Light Element", Float) = 0
		[Space(5)][KeywordEnum(_,LIGHT_COLOR,LIGHT_ILLUMINANCE,SHADE_LAMBERT,SHADE_SPECULAR,SHADE_SPEC_DGF,SHADE_SPEC_D,SHADE_SPEC_G,SHADE_SPEC_F)]_VPOINT("> View Sub Light Element", Float) = 0
		[Space(5)][KeywordEnum(_,TOTAL_ILLUMINANCE,TOTAL_REFLECTION)]_VGET("> View Total Light Amount", Float) = 0
		[Space(15)]
		[Header(__ Measure The Value __________)][Space(5)]
		[Toggle(_CHECKVALUE)]_CheckValue("> Measure The Output Value", Float) = 0
		[Space(5)]_ChkTargetValue(" ORANGE-GREEN-BLUE", Range(-0.1, 5.0)) = 0.1842
		[Enum(x0.01,0.01, x0.1,0.1, x1,1.0, x10,10.0, x100,100.0, x1000,1000.0, x10000,10000.0)]_ChkTargetScale("    (Higher - Hit - Lower)", Range(0.001, 1000.0)) = 1.0
		[Space(8)][PowerSlider(2.0)]_ChkRange(" Tolerance", Range(0.0032, 10.0)) = 0.045
		[Space(30)]
		[Header(__ Other Options ____________)][Space(5)]
		[Toggle(_NOPIDIV)]_NoPiDiv("No INV_PI as UnityStandard", Float) = 0

	}
		SubShader{
			Tags { "RenderType" = "Opaque" }
			LOD 100
			Pass {
				Name "FORWARD"
				Tags{ "LightMode" = "ForwardBase"}
				ZWrite On
				Blend One Zero
				BlendOp Add
				HLSLPROGRAM
				#pragma target 3.5
				#pragma multi_compile_instancing
				#pragma instancing_options assumeuniformscaling
				#pragma multi_compile _ VERTEXLIGHT_ON
				#pragma shader_feature DIRECTIONAL
				#pragma shader_feature SHADOWS_SCREEN
				#pragma multi_compile _ LIGHTPROBE_SH DIRLIGHTMAP_COMBINED
				#pragma multi_compile _ UNITY_USE_NATIVE_HDR UNITY_LIGHTMAP_RGBM_ENCODING UNITY_LIGHTMAP_DLDR_ENCODING
				#pragma shader_feature DYNAMICLIGHTMAP_ON
				#pragma shader_feature _NOPIDIV
				#pragma shader_feature _COLMAP
				#pragma shader_feature _METMAP
				#pragma shader_feature _OCCMAP
				#pragma shader_feature _SMTMAP
				#pragma shader_feature _NORMALMAP
				#pragma multi_compile _ _VMAT_COLOR _VMAT_DIFFUSE_COLOR _VMAT_SPECULAR_COLOR _VMAT_METALLIC _VMAT_SMOOTHNESS _VMAT_OCCLUSION _VSUN_LIGHT_COLOR _VSUN_LIGHT_ILLUMINANCE _VSUN_SHADE_LAMBERT _VSUN_SHADE_SPECULAR _VSUN_SHADE_SPEC_DGF _VSUN_SHADE_SPEC_D _VSUN_SHADE_SPEC_G _VSUN_SHADE_SPEC_F _VENV_LIGHT_ILLUMINANCE _VENV_SHADE_LAMBERT _VENV_SHADE_REFLECTION _VPOINT_LIGHT_COLOR _VPOINT_LIGHT_ILLUMINANCE _VPOINT_SHADE_LAMBERT _VPOINT_SHADE_SPECULAR _VPOINT_SHADE_SPEC_D _VPOINT_SHADE_SPEC_G _VPOINT_SHADE_SPEC_F _VGET_TOTAL_ILLUMINANCE _VGET_TOTAL_REFLECTION
				#pragma multi_compile _ _VSUN__
				#pragma multi_compile _ _VPOINT__
				#pragma shader_feature _CHECKVALUE
				#pragma vertex   ChsForwardVertex
				#pragma fragment ChsForwardFragment
				#define SEGATB_FORWARD
				#include "litChkLib.hlsl"
				ENDHLSL
			}
			Pass {
				Name "ShadowCaster"
				Tags{"LightMode" = "ShadowCaster"}
				ZWrite On
				ColorMask 0
				HLSLPROGRAM
				#pragma target 3.5
				#pragma multi_compile_instancing
				#pragma instancing_options assumeuniformscaling
				#pragma vertex   DepthOnlyVertex
				#pragma fragment DepthOnlyFragment
				#define SEGATB_SHADOWCASTER
				#include "litChkLib.hlsl"
				ENDHLSL
			}
			Pass {
				Name "META"
				Tags{"LightMode" = "Meta"}
				Cull Off
				HLSLPROGRAM
				#pragma shader_feature _COLMAP
				#pragma shader_feature _METMAP
				#pragma shader_feature EDITOR_VISUALIZATION
				#pragma vertex   MetaVertex
				#pragma fragment MetaFragment
				#define SEGATB_META
				#include "litChkLib.hlsl"
				ENDHLSL
			}
		}
}