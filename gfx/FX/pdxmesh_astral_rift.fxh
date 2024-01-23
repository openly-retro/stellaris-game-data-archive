Includes = {
	"constants.fxh"
	"vertex_structs.fxh"
	"standardfuncsgfx.fxh"
	"shadow.fxh"
	"tiled_pointlights.fxh"
	"pdxmesh_samplers.fxh"
}

ConstantBuffer( AstralRiftConstants, 1, 28 )
{
	float4x4 WorldMatrix;
	float4	Erosion;

	#SEntityCustomDataInstance
	float2 UVAnimationDir;
	float  UVAnimationTime;
	float  BloomFactor;

	#SAstralRiftMeshUserData
	float SparkleIntensity;
	float SparkleUVAnimationSpeed;
};

PixelShader =
{
	MainCode PixelPdxMeshAstralRift
	ConstantBuffers = { Common, AstralRiftConstants, Shadow, TiledPointLight }
	[[
		float4 main( VS_OUTPUT_PDXMESHSTANDARD In ) : PDX_COLOR
		{
			float3 Position = In.vPos.xyz / In.vPos.w;

			LightingProperties lightingProperties;
			lightingProperties._WorldSpacePos = Position;
			lightingProperties._ToCameraDir = normalize( vCamPos - Position );

			float3 InNormal = normalize( In.vNormal );
			float4 NormalMapSampled = tex2D( NormalMap, In.vUV0 );
			float3x3 TBN = Create3x3( normalize( In.vTangent ), normalize( In.vBitangent ), InNormal );

			float3 Normal;
			float4 Diffuse;
			float Emissive;

			float4 Properties = tex2D( SpecularMap, In.vUV0 );

			Normal = normalize( mul( UnpackRRxGNormal( NormalMapSampled ), TBN ) );
			Diffuse = tex2D( DiffuseMap, In.vUV0 );
			Emissive = NormalMapSampled.b;

			float4 SparkleEffect = tex2D( CustomTexture, In.vUV1 + UVAnimationTime * SparkleUVAnimationSpeed );
			Diffuse.rgb = Diffuse.rgb + SparkleEffect.rgb * SparkleEffect.a * SparkleIntensity;

			float3 Color = Diffuse.rgb;

			lightingProperties._Glossiness = Properties.a;
			lightingProperties._NonLinearGlossiness = GetNonLinearGlossiness(lightingProperties._Glossiness);

			// Gamma - Linear ping pong
			// All content is already created for gamma space math, so we do this in gamma space
			Color = ToGamma(Color);
			Color = ToLinear(lerp( Color, Color * Properties.r, Properties.r ));

			lightingProperties._Normal = Normal;
			float SpecRemapped = Properties.g * Properties.g * 0.4;
			float Metalness = Properties.b;
			
			float MetalnessRemapped = 1.0 - (1.0 - Metalness) * (1.0 - Metalness);

			lightingProperties._Diffuse = MetalnessToDiffuse(MetalnessRemapped, Color);
			lightingProperties._SpecularColor = MetalnessToSpec(MetalnessRemapped, Color, SpecRemapped);

			float3 diffuseLight = vec3(0.0);
			float3 specularLight = vec3(0.0);
			CalculateSystemPointLight(lightingProperties, 1.0f, diffuseLight, specularLight);
			CalculatePointLights(lightingProperties, LightDataMap, LightIndexMap, diffuseLight, specularLight);

			float3 EyeDir = normalize( Position - vCamPos.xyz );
			float3 reflection = reflect( EyeDir, Normal );
			float MipmapIndex = GetEnvmapMipLevel(lightingProperties._Glossiness);
			float3 reflectiveColor = texCUBElod( EnvironmentMap, float4(reflection, MipmapIndex) ).rgb * CubemapIntensity;
			specularLight += reflectiveColor * FresnelGlossy(lightingProperties._SpecularColor, -EyeDir, lightingProperties._Normal, lightingProperties._Glossiness);

			Color = ComposeLight( lightingProperties, 1.0f, diffuseLight, specularLight );
			Color = lerp( Color, Diffuse.rgb, Emissive );

			return float4(Color, Diffuse.a );
		}

	]]
}
