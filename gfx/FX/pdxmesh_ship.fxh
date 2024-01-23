Includes = {
	"constants.fxh"
	"vertex_structs.fxh"
	"standardfuncsgfx.fxh"
	"shadow.fxh"
	"tiled_pointlights.fxh"
	"pdxmesh_samplers.fxh"
}

ConstantBuffer( ShipConstants, 1, 28 )
{
	float4x4 WorldMatrix;
	float4	Erosion;

	#SEntityCustomDataInstance
	float2 vUVAnimationDir;
	float  vUVAnimationTime;
	float  vBloomFactor;

	#SGameShipConstants
	float4 PrimaryColor;
	float4 ShipVars; //r = _EmissiveRecolorCrunch, g = _CloakProgress, b - _Multipurpose1 ( damage or Z extension min ), a - _Multipurpose2 ( Z extension max )
	
	#SShipLightData
	float4		CamLightDir[3];                                                                  //CVector4f _CamLightDir[ NUM_CAMERA_LIGHTS ];
	float2		CamLightIntensityNearFar;                                                        //CVector2f _CamLightIntensity;
	float2		CamLightFadeStartStop;                                                           //CVector2f _CamLightFadeStartStop;
	float2		RimLightStartNearFar;                                                            //CVector2f _RimStart;
	float2		RimLightStopNearFar;                                                             //CVector2f _RimStop;
	float2		AmbientIntensityNearFar;                                                         //CVector2f _AmbientIntensity;
	#MAXED OUT! any more and we will start overlapping with the bone matrices
	
	## TODO for ship coloring
	# Add secondary color - float3
	# make primarycolor to float3 ( frees 1 float )
	# bake time and uv-anim dir ( frees 1 float )
	# use same var for dissolve and damage ( frees 1 float )
	# Check if we can nuke all the near-far values for SShipLightData ( frees 10 floats! )
	
};

PixelShader =
{
	Code
		ConstantBuffers = { ShipConstants }
	[[
		void CalculateShipCameraLights( LightingProperties aProperties, float aShadowFactor, inout float3 aDiffuseLightOut, inout float3 aSpecularLightOut )
		{
			for( int i = 0; i < 3; ++i )
			{
				float3 vLightDir = CamLightDir[i].x * vCamRightDir + CamLightDir[i].y * vCamUpDir + CamLightDir[i].z * vCamLookAtDir;
				if( dot( vLightDir, vLightDir ) > 0.f )
				{
					normalize( vLightDir );

					float vCamDistance = length( aProperties._WorldSpacePos - vCamPos );
					float vFadeValue = saturate( ( vCamDistance - CamLightFadeStartStop.x ) / ( CamLightFadeStartStop.y - CamLightFadeStartStop.x ) );
					float vIntensity = lerp( CamLightIntensityNearFar.x, CamLightIntensityNearFar.y, vFadeValue );

					float3 diffLight = vec3(0.0);
					float3 specLight = vec3(0.0);
					#ifndef PDX_LEGACY_BLINN_PHONG
						ImprovedBlinnPhong( CamLightDiffuse[i], -vLightDir, aProperties, diffLight, specLight );
					#else
						diffLight = CalculateLight( aProperties._Normal, vLightDir, CamLightDiffuse[i] );
						specLight = CalculatePBRSpecularPower( aProperties._WorldSpacePos, aProperties._Normal, aProperties._SpecularColor, aProperties._Glossiness, CamLightDiffuse[i], vLightDir);
					#endif
					aDiffuseLightOut += diffLight * aShadowFactor * vIntensity;
					aSpecularLightOut += specLight * aShadowFactor * vIntensity;
				}
			}
		}
	]]

	Code
	[[
		float3 ApplyDissolve( float3 vPrimaryColorIn, float vDissolveIn, float3 vColor, float3 vDiffuse, float2 vUV )
		{
			float vDissolveTex = tex2D( CustomTexture2, vUV ).r;
			float vTime = -vDissolveIn;
			//float vTime = saturate( frac( HdrRange_Time_ClipHeight.y ) * 1.1f );
			const float vTimeOffset = 1.3f;
			float vD = vTimeOffset - vTime * vTimeOffset - vDissolveTex - 0.01f;
			clip( vD );

			const float EDGE_SHARPNESS = 3.0f;
			const float EDGE_POW = 5.0f;
			const float COLOR_INTENSITY = 10.0f;

			float NdotU = dot( UnpackRRxGNormal( tex2D( NormalMap, vUV ) ).rgb, float3( 0.f, 1.f, 0.f ) ) * 0.5f + 0.5f;

			float3 AddColor = vPrimaryColorIn * COLOR_INTENSITY;
			return vColor + AddColor * NdotU * pow( saturate( 1.f - vD*EDGE_SHARPNESS ), EDGE_POW );
		}
	]]

	MainCode PixelPdxMeshShip
	ConstantBuffers = { Common, ShipConstants, Shadow, TiledPointLight }
	[[
		float4 main( VS_OUTPUT_PDXMESHSTANDARD In ) : PDX_COLOR
		{
			const float  DMG_START		= 0.5f;
			const float  DMG_END		= 1.0f;
			const float  DMG_TILING		= 3.5f;
			const float  DMG_EDGE		= 0.0f;
			const float3 DMG_EDGE_COLOR	= float3( 10.0f, 6.6f, 0.1f );

			float3 vPos = In.vPos.xyz / In.vPos.w;

			LightingProperties lightingProperties;
			lightingProperties._WorldSpacePos = vPos;
			lightingProperties._ToCameraDir = normalize( vCamPos - vPos );

			float3 vInNormal = normalize( In.vNormal );
			float4 vNormalMap = tex2D( NormalMap, In.vUV0 );
			float3x3 TBN = Create3x3( normalize( In.vTangent ), normalize( In.vBitangent ), vInNormal );

			float3 vNormal;
			float4 vDiffuse;
			float vEmissive;
			float EmissiveRecolorCrunch = ShipVars.r;

			float4 vProperties = tex2D( SpecularMap, In.vUV0 );

			#ifdef ANIMATE_UV
				#ifdef USE_FLOWMAP
					//Note that this variable is being re-purposed due to the constant buffer being full, so this is a special case.
					float flowmapIntensity = vUVAnimationDir.x;
					//From 0 - 1 to -1 - 1 space
					vNormalMap.xy = ( ( vNormalMap.xy - 0.5f ) * 2.0f ) * flowmapIntensity;

					float2 flowUVs = In.vUV0 + ( vNormalMap.xy * frac( vUVAnimationTime ) );
					float2 offsetFlowUVs = In.vUV0 + ( vNormalMap.xy * frac( vUVAnimationTime + 0.5f ) );
					float blendValue = abs( ( frac( vUVAnimationTime ) * 2.0f ) - 1.0f );

					vNormal = vInNormal;
					vDiffuse = tex2D( DiffuseMap, flowUVs );
					float4 vDiffuseOffset = tex2D( DiffuseMap, offsetFlowUVs );
					vDiffuse = lerp( vDiffuse, vDiffuseOffset, blendValue );
					vEmissive = vDiffuse.a;
					EmissiveRecolorCrunch = 1.0f;
				#else
					vNormal = normalize( mul( UnpackRRxGNormal( vNormalMap ), TBN ) );
					vDiffuse = tex2D( DiffuseMap, In.vUV0 + vUVAnimationDir * vUVAnimationTime );
					vEmissive = vNormalMap.b;
				#endif
			#else
				vNormal = normalize( mul( UnpackRRxGNormal( vNormalMap ), TBN ) );
				vDiffuse = tex2D( DiffuseMap, In.vUV0 );
				vEmissive = vNormalMap.b;
			#endif

			//Fade in damage texture
			float4 vDamageTex = tex2D( CustomTexture2, In.vUV0 * DMG_TILING );
			//float vDmgTemp = 1.0f;
			float vDmgTemp = ShipVars.b;
			//float vDmgTemp = saturate( mod( HdrRange_Time_ClipHeight.y * 0.25f, 1.25f ) );
			vDmgTemp = 1.0f - saturate( ( vDmgTemp - DMG_START ) / ( DMG_END - DMG_START ) );
			float vDamageValue = ( vDamageTex.a - vDmgTemp ) * 5.0f;
			if( vDamageTex.a <= 0.001f )
			{
				vDamageValue = 0.f;
			}
			float vDamageEdge = DMG_EDGE * saturate( 1.0f - abs( ( vDamageValue - 0.5 ) * 2 ) );
			vDamageValue = saturate( vDamageValue );
			vDiffuse.rgb = lerp( vDiffuse.rgb, vDamageTex.rgb, vDamageValue );
			vProperties = lerp( vProperties, vec4( 0.f ), vDamageValue );

			vDiffuse.rgb *= lerp( vec3( 1.f ), DMG_EDGE_COLOR, saturate( vDamageEdge ) );
			
			

			#ifndef USE_EMPIRE_COLOR_MASK_FOR_EMISSIVE //If not defined, just color all of the emissive the empire color
				if( PrimaryColor.a > 0.0f )
				{
					vDiffuse.rgb = lerp( vDiffuse.rgb, vec3( max( vDiffuse.r, max( vDiffuse.g, vDiffuse.b ) ) ) * PrimaryColor.rgb, saturate( (vEmissive * EmissiveRecolorCrunch ) ) );
				}
			#else
				if( PrimaryColor.a > 0.0f ) //It is defined, therefore we take the empire color map into account and only color areas that have been defined there as well.
				{
					float Floored = floor( vProperties.r + 0.95f );
					float3 EmpireColorEmissive = float3(Floored, Floored, Floored);
					vDiffuse.rgb = lerp( vDiffuse.rgb, vec3( max( vDiffuse.r, max( vDiffuse.g, vDiffuse.b ) ) ) * PrimaryColor.rgb, saturate( (vEmissive * EmissiveRecolorCrunch * EmpireColorEmissive ) ) );
				}
			#endif
			
			vEmissive *= 1.f - vDamageValue;
			vEmissive += vDamageEdge;
						
			float3 vColor = vDiffuse.rgb;

			lightingProperties._Glossiness = vProperties.a;
			lightingProperties._NonLinearGlossiness = GetNonLinearGlossiness(lightingProperties._Glossiness);

			float vCubemapIntensity = CubemapIntensity;

			 // Gamma - Linear ping pong
			 // All content is already created for gamma space math, so we do this in gamma space
			vColor = ToGamma(vColor);
			vColor = ToLinear(lerp( vColor, vColor * ( vProperties.r * PrimaryColor.rgb ), vProperties.r ));

			lightingProperties._Normal = vNormal;
			float SpecRemapped = vProperties.g * vProperties.g * 0.4;
			float vMetalness = vProperties.b;
			
			float MetalnessRemapped = 1.0 - (1.0 - vMetalness) * (1.0 - vMetalness);

			lightingProperties._Diffuse = MetalnessToDiffuse(MetalnessRemapped, vColor);
			lightingProperties._SpecularColor = MetalnessToSpec(MetalnessRemapped, vColor, SpecRemapped);

			float3 diffuseLight = vec3(0.0);
			float3 specularLight = vec3(0.0);
			CalculateSystemPointLight(lightingProperties, 1.0f, diffuseLight, specularLight);
			CalculateShipCameraLights(lightingProperties, 1.0f, diffuseLight, specularLight);
			CalculatePointLights(lightingProperties, LightDataMap, LightIndexMap, diffuseLight, specularLight);

			float3 vEyeDir = normalize( vPos - vCamPos.xyz );
			float3 reflection = reflect( vEyeDir, vNormal );
			float MipmapIndex = GetEnvmapMipLevel(lightingProperties._Glossiness);
			float3 reflectiveColor = texCUBElod( EnvironmentMap, float4(reflection, MipmapIndex) ).rgb * vCubemapIntensity;
			specularLight += reflectiveColor * FresnelGlossy(lightingProperties._SpecularColor, -vEyeDir, lightingProperties._Normal, lightingProperties._Glossiness);

			float vCamDistance = length( vPos - vCamPos );
			float vCamDistFadeValue = saturate( ( vCamDistance - CamLightFadeStartStop.x ) / ( CamLightFadeStartStop.y - CamLightFadeStartStop.x ) );
			float vAmbientIntensity = lerp( AmbientIntensityNearFar.x, AmbientIntensityNearFar.y, vCamDistFadeValue );

			#ifdef GLOSSY_EMISSIVE
				vColor = ( ( (AmbientDiffuse * vAmbientIntensity) + diffuseLight) * lightingProperties._Diffuse) * HdrRange_Time_ClipHeight.x;
				vColor = lerp( vColor, vDiffuse.rgb, vEmissive );
				vColor += specularLight;
			#else
				vColor = ComposeLight( lightingProperties, vAmbientIntensity, diffuseLight, specularLight );
				vColor = lerp( vColor, vDiffuse.rgb, vEmissive );
			#endif
			
			float alpha = vDiffuse.a;
			#ifndef GUI_ICON
				#ifndef NO_ALPHA_MULTIPLIED_EMISSIVE
					alpha *= vEmissive;
					alpha *= vBloomFactor;
				#endif
			#endif

			#ifdef RIM_LIGHT
				float vRimStart = lerp( RimLightStartNearFar.x, RimLightStartNearFar.y, vCamDistFadeValue );
				float vRimStop = lerp( RimLightStopNearFar.x, RimLightStopNearFar.y, vCamDistFadeValue );

				float vRim = smoothstep( vRimStart, vRimStop, 1.0f - dot( vNormal, lightingProperties._ToCameraDir ) );

				vColor.rgb = lerp( vColor.rgb, RimLightDiffuse.rgb, saturate( vRim ) );
			#endif
			
			#ifdef CLOAKED
				float ZLength = ShipVars.a - ShipVars.b;
				float MiddlePoint = ZLength / 2;
				float Offset = ( In.vSphere.z / ( ZLength * 1.2f ) ) + 0.5f;

				STriplanarMapping CloakTexMapping = CalcTriplanarMapping( In.vObjectNormal, In.vSphere.xyz, 0.2f );

				float2 CloakTexDir = float2( normalize( -CloakTexMapping._UvY.x ), 0.0f );
				CloakTexMapping._UvX = abs( CloakTexMapping._UvX ) + ( HdrRange_Time_ClipHeight.y * CloakTexDir ) * 0.2f ;
				CloakTexMapping._UvY = abs( CloakTexMapping._UvY ) + ( HdrRange_Time_ClipHeight.y * CloakTexDir ) * 0.2f;

				float4 CloakingTexture = SampleColorTriplanar( CustomTexture, CloakTexMapping );

				const float vMaterializeSpan = 0.2f; //Transition smoothness
				float vProgress = ShipVars.g * ( 1.0f + ( 2.0f * vMaterializeSpan ) );
				float vLower = vProgress - vMaterializeSpan;
				float fadeResult = saturate( ( ( 1.0f - ( ( Offset - vLower ) / vMaterializeSpan ) ) - length( CloakingTexture.rgb ) ) );

				float fresnel = saturate( smoothstep( -0.8f, 0.0f, dot( vNormal, vCamLookAtDir ) ) );

				//Emissive hack since we cannot just add the alpha value
				float3 emissive = vColor * ( alpha * vEmissive * vBloomFactor );
				vColor += emissive * 0.6f; //Hard-coded emissive bloom strength

				float BloomMultiplier = 12.0f;
				float3 cloakColor = lerp( PrimaryColor.rgb, CloakingTexture.rgb, 0.1f ) * BloomMultiplier;
				vColor = lerp( vColor, vec3( max( vDiffuse.r, max( vDiffuse.g, vDiffuse.b ) ) ) * cloakColor * fadeResult, fadeResult );

				float visibility = 0.3f;

				alpha = lerp( 1.0f, visibility * fresnel, fadeResult );

				// We need to return here because when ship is cloaked ShipVars.b contains not the dissolve progress but Z extension min
				return float4( vColor, alpha );
			#endif

			vColor = ApplyDissolve( PrimaryColor.rgb, ShipVars.b, vColor.rgb, vDiffuse.rgb, In.vUV0 );

			return float4(vColor, alpha );
		}

	]]

	MainCode PixelPdxMeshExtraDimensionalShip
	ConstantBuffers = { Common, ShipConstants, Shadow }
	[[
		float4 main( VS_OUTPUT_PDXMESHSTANDARD In ) : PDX_COLOR
		{
			float3 RimColor = HSVtoRGB( float3( 0.4f, 0.7f, 1.0f ) );
			const float RimAlpha = 0.09f;
			const float vRimStart = 0.5f;
			const float vRimStop = 0.25f;

			// Normal
			float3 vInNormal = normalize( In.vNormal );
			float4 vNormalMap = tex2D( NormalMap, In.vUV0 );
			float3 vNormalSample = UnpackRRxGNormal(vNormalMap);

			float3x3 TBN = Create3x3( normalize( In.vTangent ), normalize( In.vBitangent ), vInNormal );
			float3 vNormal = normalize(mul( vNormalSample, TBN ));

			float vDot = dot( vNormal, -vCamLookAtDir );

			float vRim = smoothstep( vRimStart, vRimStop, abs( vDot ) );
			float4 vColor = vRim * float4( RimColor.rgb, RimAlpha );
			if( vDot > 0.f )
			{
				float vTime = ( vUVAnimationTime + HdrRange_Time_ClipHeight.y ) * 0.15f;
				vColor += tex2D( DiffuseMap, In.vUV0 + vUVAnimationDir * vTime );
				vColor += tex2D( DiffuseMap, ( In.vUV0 + float2( 0.20f, -0.13f ) * vTime * 0.27f ) );
			}

			float3 vEyeDir = normalize( In.vPos.xyz - vCamPos.xyz );
			float3 reflection = reflect( vEyeDir, In.vNormal );
			float pulse = ( 0.9f + 0.1f * sin( 3.141f * length( texCUBElod( EnvironmentMap, float4(reflection, 0) ).rgb ) + HdrRange_Time_ClipHeight.y * 1.f - In.vSphere.z * In.vSphere.y * 0.125f ) );
			vColor += pow( pulse, 40.0f ) * 0.1f;

			vColor.rgb = ApplyDissolve( PrimaryColor.rgb, ShipVars.b, vColor.rgb, RimColor, In.vUV0 );

			vColor.rgb *= vBloomFactor;
			return vColor;
		}
	]]
}