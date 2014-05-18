Shader "Lux/OrenNayar/Bumped Diffuse ON" {

	Properties {
	_Color ("Diffuse Color", Color) = (1,1,1,1)
	_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
	_BumpMap ("Normalmap", 2D) = "bump" {}
	_DiffuseRough ("Rough Diffuse(RGB) Roughness(A)", 2D) = "white" {}
	_DiffCubeIBL ("Custom Diffuse Cube", Cube) = "black" {}


	[HideInInspector] _AO ("Ambient Occlusion Alpha (A)", 2D) = "white" {}
	[HideInInspector] _DiffuseRoughness ("Diffuse Roughness", Range (0.0, 1.0)) = 1.0
	[HideInInspector] _OverallRoughness ("Overall Roughness ", Range (0.0, 1.0)) = 1.0
	}

	SubShader { 
		Tags { "RenderType"="Opaque" }
		LOD 400

		//	Built in Fog breaks rendering using directX and only one pixel light
		Fog { Mode Off } 
	
		CGPROGRAM
		#pragma surface surf LuxDirect noambient
		#pragma glsl
		#pragma target 3.0
	
		//#pragma multi_compile LUX_LIGHTING_BP LUX_LIGHTING_CT
		#pragma multi_compile LUX_OREN_NAYAR_ON LUX_OREN_NAYAR_OFF
		//#pragma multi_compile LUX_LINEAR //LUX_GAMMA
		//#pragma multi_compile DIFFCUBE_ON DIFFCUBE_OFF
		//#pragma multi_compile SPECCUBE_ON SPECCUBE_OFF
		//#pragma multi_compile LUX_AO_OFF LUX_AO_ON

		//#define LUX_LIGHTING_CT
		#define LUX_LINEAR
		#define LUX_AO_ON
		#define LUX_DIFFUSE
		#define DIFFCUBE_ON

		#include "../LuxCore/LuxLightingDirect.cginc"

		float4 _Color;
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _DiffuseRough;
		float _DiffuseRoughness;
		float _OverallRoughness;
		#ifdef DIFFCUBE_ON
			samplerCUBE _DiffCubeIBL;
		#endif
		#ifdef LUX_AO_ON
			sampler2D _AO;
		#endif
	
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

			fixed4 diff_albedo = tex2D(_MainTex, IN.uv_MainTex);
			fixed4 diff_albedo_rough = tex2D(_DiffuseRough, IN.uv_MainTex);
			diff_albedo_rough = lerp(fixed4(1,1,1,0), diff_albedo_rough, _DiffuseRoughness);
			diff_albedo *= diff_albedo_rough;
			// Diffuse Albedo
			o.Albedo = diff_albedo.rgb * _Color.rgb; 
			o.Specular = diff_albedo_rough * _OverallRoughness;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			//o.Specular = diff_albedo_rough * _OverallRoughness;
			#include "../LuxCore/LuxLightingAmbient.cginc"
		
		}
		ENDCG
	}
	FallBack "Diffuse"
	CustomEditor "LuxMaterialInspector"
}
