﻿Shader "Lux/Parallax/Bumped Specular Parallax" {

Properties {
	_Color ("Diffuse Color", Color) = (1,1,1,1)
	_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
	_SpecTex ("Specular Color (RGB) Roughness (A)", 2D) = "black" {}
	_BumpMap ("Normalmap", 2D) = "bump" {}
	_ParallaxMap ("Heightmap (A)", 2D) = "black" {}
	_Parallax ("Height", Range (0.005, 0.08)) = 0.02
	_DiffCubeIBL ("Custom Diffuse Cube", Cube) = "black" {}
	_SpecCubeIBL ("Custom Specular Cube", Cube) = "black" {}
	
	// _Shininess property is needed by the lightmapper - otherwise it throws errors
	[HideInInspector] _Shininess ("Shininess (only for Lightmapper)", Float) = 0.5
	[HideInInspector] _AO ("Ambient Occlusion Alpha (A)", 2D) = "white" {}
	[HideInInspector] _DiffuseRoughness ("Diffuse Roughness", Range (0.0, 1.0)) = 1.0
	[HideInInspector] _OverallRoughness ("Overall Roughness ", Range (0.0, 1.0)) = 1.0
}

SubShader { 
	Tags { "RenderType"="Opaque" }
	LOD 400
	
	CGPROGRAM
	#pragma surface surf LuxDirect noambient
	#pragma glsl
	#pragma target 3.0

	// #pragma debug

	#pragma multi_compile LUX_LIGHTING_BP LUX_LIGHTING_CT
	#pragma multi_compile LUX_OREN_NAYAR_ON LUX_OREN_NAYAR_OFF
	//#pragma multi_compile LUX_LINEAR LUX_GAMMA
	//#pragma multi_compile DIFFCUBE_ON DIFFCUBE_OFF
	//#pragma multi_compile SPECCUBE_ON SPECCUBE_OFF
	//#pragma multi_compile LUX_AO_OFF LUX_AO_ON

//#define LUX_LIGHTING_CT
	#define LUX_LINEAR
	#define DIFFCUBE_ON
	#define SPECCUBE_ON
	#define LUX_AO_ON

	// include should be called after all defines
	#include "../LuxCore/LuxLightingDirect.cginc"

	float _OverallRoughness;
	float _DiffuseRoughness;

	float4 _Color;
	sampler2D _MainTex;
	sampler2D _SpecTex;
	sampler2D _BumpMap;
	#ifdef DIFFCUBE_ON
		samplerCUBE _DiffCubeIBL;
	#endif
	#ifdef SPECCUBE_ON
		samplerCUBE _SpecCubeIBL;
	#endif
	#ifdef LUX_AO_ON
		sampler2D _AO;
	#endif
	
	// shader specific inputs
	float _Parallax;
	sampler2D _ParallaxMap;

	// Is set by script
	float4 ExposureIBL;

	struct Input {
		float2 uv_MainTex;
		float2 uv_BumpMap;
		#ifdef LUX_AO_ON
			float2 uv_AO;
		#endif
		float3 viewDir;
		float3 worldNormal;
		float3 worldRefl;
		INTERNAL_DATA
	};
	
	void surf (Input IN, inout SurfaceOutputLux o) {
		// Parallax
		half h = tex2D (_ParallaxMap, IN.uv_BumpMap).w;
		float2 offset = ParallaxOffset (h, _Parallax, IN.viewDir);
		IN.uv_MainTex += offset;
		IN.uv_BumpMap += offset;
		//
		fixed4 diff_albedo = tex2D(_MainTex, IN.uv_MainTex);
		fixed4 spec_albedo = tex2D(_SpecTex, IN.uv_MainTex);
		// Diffuse Albedo
		o.Albedo = diff_albedo.rgb * _Color.rgb;
		o.Alpha = diff_albedo.a * _Color.a;
		o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
		// Specular Color
		o.SpecularColor = spec_albedo.rgb;
		// Roughness – gamma for BlinnPhong / linear for CookTorrence
		#if defined (LUX_OREN_NAYAR_ON)
			diff_albedo *= lerp(fixed4(1,1,1,0), spec_albedo, _DiffuseRoughness);
			o.Specular = LuxAdjustSpecular(spec_albedo.a + diff_albedo.a) * _OverallRoughness;
		#else
			o.Specular = LuxAdjustSpecular(spec_albedo.a); 
		#endif
		#include "../LuxCore/LuxLightingAmbient.cginc"
	}
ENDCG
}
FallBack "Specular"
CustomEditor "LuxMaterialInspector"
}
