Shader "Lux/Lux Bumped Diffuse ON" {

	Properties {
		_Color ("Diffuse Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
		_BumpMap ("Normalmap", 2D) = "bump" {}
		_Roughness ("Roughness", Range(0.0,1.0)) = 1
		_DiffCubeIBL ("Custom Diffuse Cube", Cube) = "black" {}

		[HideInInspector] _Shininess ("Shininess (only for Lightmapper)", Float) = 0.5
	}

	SubShader { 
		Tags { "RenderType"="LuxOpaque" }
		LOD 400

		//	Built in Fog breaks rendering using directX and only one pixel light
		Fog { Mode Off } 
	
		CGPROGRAM
		#pragma surface surf LuxDiffuseON noambient exclude_path:prepass fullforwardshadows vertex:vert nodirlightmap nolightmap finalcolor:customFogExp2
		#pragma glsl
		#pragma target 3.0
	
		#define LUX_LIGHTING_BP
		#define LUX_LINEAR
		#pragma multi_compile DIFFCUBE_ON DIFFCUBE_OFF

		#include "LuxCore/LuxLightingDirect.cginc"

		float4 _Color;
		sampler2D _MainTex;
		sampler2D _BumpMap;
		float _Roughness;

	#ifdef DIFFCUBE_ON
		samplerCUBE _DiffCubeIBL;
	#endif
	
		// Is set by script
		float4 ExposureIBL;

		struct Input {
			float2 uv_MainTex;
			// distance needed by custom fog
			float2 PureLightAtten_Distance;
			float3 viewDir;
			float3 worldNormal;
			float3 worldRefl;
			INTERNAL_DATA
		};
		
		//#define SurfaceOutputLux SurfaceOutputLuxSkin
		
		// Define LUX_CAMERADISTANCE as PureLightAtten_Distance.y
		#define LUX_CAMERADISTANCE IN.PureLightAtten_Distance.y
		#include "LuxCore/LuxCustomFog.cginc"

		void vert (inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input,o);
			o.PureLightAtten_Distance = 1;
			#ifdef POINT
				float3 myLightCoord = mul(_LightMatrix0, mul(_Object2World, v.vertex)).xyz;
				// o.PureLightAtten = tex2D(_LightTexture0, dot(myLightCoord,myLightCoord).rr).UNITY_ATTEN_CHANNEL;
				// dx11 needs tex2Dlod here
				o.PureLightAtten_Distance.x = tex2Dlod(_LightTexture0, float4( dot(myLightCoord,myLightCoord).rr, 0, 1) ).UNITY_ATTEN_CHANNEL;
			#endif
			#ifdef SPOT
			float4 myLightCoord = mul(_LightMatrix0, mul(_Object2World, v.vertex));
				// o.PureLightAtten = UnitySpotCookie(myLightCoord.xyzw) * UnitySpotAttenuate(myLightCoord.xyz);
				// dx11 needs tex2Dlod here
				o.PureLightAtten_Distance.x = float( tex2Dlod(_LightTexture0, float4(myLightCoord.xy / myLightCoord.w + 0.5, 0, 1)) .a); // UnitySpotCookie
				o.PureLightAtten_Distance.x *= tex2Dlod(_LightTexture0, float4( dot(myLightCoord,myLightCoord).rr, 0, 1) ).UNITY_ATTEN_CHANNEL; // UnitySpotAttenuate
			#endif
			#ifdef DIRECTIONAL
				o.PureLightAtten_Distance.x = 1;
			#endif
			// Calc distance for custom fog function
			o.PureLightAtten_Distance.y = length(mul(UNITY_MATRIX_MV, v.vertex).xyz);

		}

		void surf (Input IN, inout SurfaceOutputLux o) {



			fixed4 diff_albedo = tex2D(_MainTex, IN.uv_MainTex);
			// Diffuse Albedo
			o.Albedo = diff_albedo.rgb * _Color.rgb; 
			o.Alpha = diff_albedo.a * _Color.a;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
		
			#include "LuxCore/LuxLightingAmbient.cginc"
		
		}

		inline fixed4 LightingLuxDiffuseON(SurfaceOutputLux s, fixed3 lightDir, fixed3 viewDir, fixed atten) {

 //roughness A and B
float roughness = _Roughness;
float roughness2=roughness*roughness;
float2 oren_nayar_fraction = roughness2/(roughness2 + float2(0.33,0.09));
float2 oren_nayar = float2(1, 0) + float2(-0.5, 0.45) * oren_nayar_fraction;
 
//Theta and phi
float2 cos_theta = saturate(float2(dot(s.Normal,lightDir),dot(s.Normal,viewDir)));
float2 cos_theta2 = cos_theta * cos_theta;
float sin_theta = sqrt((1-cos_theta2.x)*(1-cos_theta2.y));
float3 light_plane = normalize(lightDir - cos_theta.x*s.Normal);
float3 view_plane = normalize(viewDir - cos_theta.y*s.Normal);
float cos_phi = saturate(dot(light_plane, view_plane));
 
//composition
 
float diffuse_oren_nayar = cos_phi * sin_theta / max(cos_theta.x, cos_theta.y);
 
float diffuse = cos_theta.x * (oren_nayar.x + oren_nayar.y * diffuse_oren_nayar);
float4 col;
col.rgb =s.Albedo * _LightColor0.rgb*(diffuse*atten);
col.a = s.Alpha;
return col;
		}
		ENDCG
	}
	FallBack "Diffuse"
	CustomEditor "LuxMaterialInspector"
}
