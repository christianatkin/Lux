Shader "Lux/Translucent/Lux Trans Bumped Specular ON" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_SpecTex ("Specular Color (RGB) Roughness (A)", 2D) = "black" {}
		_BumpMap ("Normal (Normal)", 2D) = "bump" {} 

		_Thickness ("Thickness (G)", 2D) = "bump" {}
		
		_Power ("Subsurface Power (1.0 - 5.0)", Float) = 2.0
		_Distortion ("Subsurface Distortion (0.0 - 0.5)", Float) = 0.1
		_Scale ("Subsurface Scale (1.0 - )", Float) = 2.0
		_SubColor ("Subsurface Color", Color) = (1.0, 1.0, 1.0, 1.0)

		_DiffCubeIBL ("Custom Diffuse Cube", Cube) = "black" {}
		_SpecCubeIBL ("Custom Specular Cube", Cube) = "black" {}

		// _Shininess property is needed by the lightmapper - otherwise it throws errors
		[HideInInspector] _Shininess ("Shininess (only for Lightmapper)", Float) = 0.5
		[HideInInspector] _AO ("Ambient Occlusion Alpha (A)", 2D) = "white" {}
		[HideInInspector] _RoughnessFac ("Roughness Factor", Range(0.0,1.0)) = 0
	
	}
	SubShader {
		Tags { "RenderType"="LuxOpaque" }
		LOD 400
	//	Built in Fog breaks rendering using directX and only one pixel light
		Fog { Mode Off } 

		CGPROGRAM
		#pragma surface surf LuxTranslucent noambient exclude_path:prepass fullforwardshadows vertex:vert nodirlightmap nolightmap finalcolor:customFogExp2
		#pragma glsl
		#pragma target 3.0


		#pragma multi_compile LUX_LIGHTING_BP LUX_LIGHTING_CT
		#pragma multi_compile LUX_OREN_NAYAR_ON LUX_OREN_NAYAR_OFF
		#define LUX_LINEAR
		#define DIFFCUBE_ON
		#define SPECCUBE_ON

	//	#define LUX_AO_OFF

		float _RoughnessFac;

		// include should be called after all defines
		#include "../LuxCore/LuxLightingDirect.cginc" 


		sampler2D _MainTex;
		sampler2D _SpecTex;
		sampler2D _BumpMap; 
		sampler2D _Thickness;
		#ifdef DIFFCUBE_ON
			samplerCUBE _DiffCubeIBL;
		#endif
		#ifdef SPECCUBE_ON
			samplerCUBE _SpecCubeIBL;
		#endif
		#ifdef LUX_AO_ON
			sampler2D _AO;
		#endif
		
		fixed4 _Color;
		float _Scale;
		float _Power;
		float _Distortion;
		fixed3 _SubColor;

		// Is set by script
		float4 ExposureIBL;

		struct Input {
			float2 uv_MainTex;
			// distance needed by custom fog
			float2 PureLightAtten_Distance;
			#ifdef LUX_AO_ON
				float2 uv_AO;
			#endif
			float3 viewDir;
			float3 worldNormal;
			float3 worldRefl;
			INTERNAL_DATA
		};
		
		//#define SurfaceOutputLux SurfaceOutputLuxSkin
		
		// Define LUX_CAMERADISTANCE as PureLightAtten_Distance.y
		#define LUX_CAMERADISTANCE IN.PureLightAtten_Distance.y
		#include "../LuxCore/LuxCustomFog.cginc"

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
			fixed4 spec_albedo = tex2D(_SpecTex, IN.uv_MainTex);
			o.Albedo = diff_albedo * _Color.rgb;
			o.Alpha = tex2D(_Thickness, IN.uv_MainTex).g * IN.PureLightAtten_Distance.x;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			// Specular Color
			o.SpecularColor = spec_albedo.rgb;
			// Roughness – gamma for BlinnPhong / linear for CookTorrence
			o.Specular = LuxAdjustSpecular(spec_albedo.a); 

			#include "../LuxCore/LuxLightingAmbient.cginc"
		}

		inline fixed4 LightingLuxTranslucent (SurfaceOutputLux s, fixed3 lightDir, fixed3 viewDir, fixed atten)
		{		
			viewDir = normalize ( viewDir );
			lightDir = normalize ( lightDir );
			 
			half3 h = normalize (lightDir + viewDir);
			// dotNL has to have max
			float dotNL = max (0, dot (s.Normal, lightDir));
			float dotNH = max (0, dot (s.Normal, h)); 

			float alpha;
			float alpha2;

			// Translucency
			half3 transLightDir = lightDir + s.Normal * _Distortion;
			float transDot = pow ( saturate(dot ( viewDir, -transLightDir ) ), _Power ) * _Scale;
			fixed3 transLight = (s.Alpha * 2) * ( transDot * _SubColor.rgb );
			fixed3 transAlbedo = s.Albedo * _LightColor0.rgb * transLight;

		//	////////////////////////////////////////////////////////////
		//	Blinn Phong	
			#if defined (LUX_LIGHTING_BP)
			// bring specPower into a range of 0.25 – 2048
			float specPower = exp2(10 * s.Specular + 1) - 1.75;

		//	Specular: Phong lobe normal distribution function
			float spec = specPower * 0.125 * pow(dotNH, specPower); 



		//	Visibility: Schlick-Smith
			alpha = 2.0 / sqrt( Pi * (specPower + 2) );
			float visibility = 1.0 / ( (dotNL * (1 - alpha) + alpha) * ( saturate(dot(s.Normal, viewDir)) * (1 - alpha) + alpha) ); 
			spec *= visibility;
			#endif


			//	////////////////////////////////////////////////////////////
			//	Cook Torrrence like
			//	from The Order 1886 // http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf

			#if defined (LUX_LIGHTING_CT)
			float dotNV = max(0, dot(s.Normal, normalize(viewDir) ) );

			//	Please note: s.Specular must be linear
			alpha = (1.0 - s.Specular); // alpha is roughness
			alpha *= alpha;
			alpha2 = alpha * alpha; 

			//	Specular Normal Distribution Function: GGX Trowbridge Reitz
			float denominator = (dotNH * dotNH) * (alpha2 - 1) + 1;
			denominator = Pi * denominator * denominator;
			float spec = alpha2 / denominator;

			//	Geometric Shadowing: Smith
			float V_ONE = dotNL + sqrt(alpha2 + (1 - alpha2) * dotNL * dotNL );
			float V_TWO = dotNV + sqrt(alpha2 + (1 - alpha2) * dotNV * dotNV );
			spec /= V_ONE * V_TWO;
			#endif

		//	Fresnel: Schlick
			// fast fresnel approximation:
			fixed3 fresnel = s.SpecularColor.rgb + ( 1.0 - s.SpecularColor.rgb) * exp2(-OneOnLN2_x6 * dot(h, lightDir));
			// from here on we use fresnel instead of spec as it is fixed3 = color
			fresnel *= spec; 
			
			//Diffuse
			float diffuseOren = 1;

			// Oren Nayar
			#if defined (LUX_OREN_NAYAR_ON)

				alpha = (1.0 - spec) * _RoughnessFac; // alpha is roughness
				alpha *= alpha;
				alpha2 = alpha * alpha; 
				float2 oren_nayar_fraction = alpha2/(alpha2 + float2(0.33,0.09));
				float2 oren_nayar = float2(1, 0) + float2(-0.5, 0.45) * oren_nayar_fraction;
 
				//components
				//half cos_nl = saturate(dot(s.Normal, lightDir)); //Using main NL here?
				//half cos_nv = saturate(dot(s.Normal, viewDir)); //Using main NV here?
				//half oren_nayar_s = saturate(dot(lightDir, viewDir)) - cos_nl * cos_nv;
				//oren_nayar_s /= lerp(max(dotNL, cos_nv), 1, step(oren_nayar_s, 0));

				//Theta and phi
				float2 cos_theta = saturate(float2(dot(s.Normal,lightDir),dot(s.Normal,viewDir))); 
				float2 cos_theta2 = cos_theta * cos_theta;
				float sin_theta = sqrt((1-cos_theta2.x)*(1-cos_theta2.y));
				float3 light_plane = normalize(lightDir - cos_theta.x*s.Normal);
				float3 view_plane = normalize(viewDir - cos_theta.y*s.Normal);
				float cos_phi = saturate(dot(light_plane, view_plane));

				float diffuse_oren_nayar = cos_phi * sin_theta / max(cos_theta.x, cos_theta.y);
 
				diffuseOren = saturate(cos_theta.x * (oren_nayar.x + oren_nayar.y * diffuse_oren_nayar));
			#endif
			#if defined (LUX_OREN_NAYAR_OFF) 
				diffuseOren = 1;
			#endif

		// Final Composition
			fixed3 directLighting;
			// we only use fresnel here / and apply late dotNL
			directLighting = (s.Albedo  + fresnel) * _LightColor0.rgb * dotNL * (atten * 2 * diffuseOren);

		//	Add the two together
			fixed4 c;
			c.rgb = directLighting + transAlbedo;
			c.a = _LightColor0.a * _SpecColor.a * spec * atten;
			return c;
		}

		ENDCG
	

	}
	FallBack "Bumped Diffuse"
	CustomEditor "LuxMaterialInspector"
}