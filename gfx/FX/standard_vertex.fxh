Includes = {
	"vertex_structs.fxh"
	"standardfuncsgfx.fxh"
	"pdxmesh_ship.fxh"
}

VertexShader =
{
	MainCode VertexPdxMeshStandard
		ConstantBuffers = { Common, ShipConstants, Shadow }
	[[
		VS_OUTPUT_PDXMESHSTANDARD main( const VS_INPUT_PDXMESHSTANDARD v )
		{
		  	VS_OUTPUT_PDXMESHSTANDARD Out;

			float4 LocalPosition = float4( v.vPosition.xyz, 1.0f );
			Out.vSphere = LocalPosition;
			Out.vObjectNormal = normalize( v.vNormal );
			Out.vNormal = normalize( mul( CastTo3x3( WorldMatrix ), v.vNormal ) );

			#ifdef IS_STAR
				Out.vTangent = normalize( v.vPosition.xyz ); //Use tangent for position
			#else
				Out.vTangent = normalize( mul( CastTo3x3( WorldMatrix ), v.vTangent.xyz ) );
			#endif
			Out.vBitangent = normalize( cross( Out.vNormal, Out.vTangent ) * v.vTangent.w );

			Out.vPosition = mul( WorldMatrix, LocalPosition );

			Out.vPos = Out.vPosition;
			Out.vPosition = mul( ViewProjectionMatrix, Out.vPosition );

			Out.vUV0 = v.vUV0;
#ifdef PDX_MESH_UV1
			Out.vUV1 = v.vUV1;
#else
			Out.vUV1 = v.vUV0;
#endif

			return Out;
		}

	]]

	MainCode VertexPdxMeshStandardSkinned
		ConstantBuffers = { Common, ShipConstants, Animation, Shadow }
	[[
		VS_OUTPUT_PDXMESHSTANDARD main( const VS_INPUT_PDXMESHSTANDARD_SKINNED v )
		{
		  	VS_OUTPUT_PDXMESHSTANDARD Out;

			float4 vPosition = float4( v.vPosition.xyz, 1.0 );
			float4 vSkinnedPosition = float4( 0, 0, 0, 0 );
			float3 vSkinnedNormal = float3( 0, 0, 0 );
			float3 vSkinnedTangent = float3( 0, 0, 0 );
			float3 vSkinnedBitangent = float3( 0, 0, 0 );

			float4 vWeight = float4( v.vBoneWeight.xyz, 1.0f - v.vBoneWeight.x - v.vBoneWeight.y - v.vBoneWeight.z );

			for( int i = 0; i < PDXMESH_MAX_INFLUENCE; ++i )
		    {
				int nIndex = int( v.vBoneIndex[i] );
				float4x4 mat = matBones[nIndex];
				vSkinnedPosition += mul( mat, vPosition ) * vWeight[i];

				float3 vNormal = mul( CastTo3x3(mat), v.vNormal );
				float3 vTangent = mul( CastTo3x3(mat), v.vTangent.xyz );
				float3 vBitangent = cross( vNormal, vTangent ) * v.vTangent.w;

				vSkinnedNormal += vNormal * vWeight[i];
				vSkinnedTangent += vTangent * vWeight[i];
				vSkinnedBitangent += vBitangent * vWeight[i];
			}

			Out.vSphere = float4( v.vPosition, 1.0f );

			Out.vPosition = mul( WorldMatrix, vSkinnedPosition );
			Out.vPos = Out.vPosition;
			Out.vPos /= WorldMatrix[3][3];

			Out.vPosition = mul( ViewProjectionMatrix, Out.vPosition );
			Out.vObjectNormal = normalize( vSkinnedNormal );
			Out.vNormal = normalize( mul( CastTo3x3(WorldMatrix), normalize( vSkinnedNormal ) ) );
			#ifdef IS_STAR
				Out.vTangent = normalize( v.vPosition.xyz ); //Use tangent for position
			#else
				Out.vTangent = normalize( mul( CastTo3x3(WorldMatrix), normalize( vSkinnedTangent ) ) );
			#endif
			Out.vBitangent = normalize( mul( CastTo3x3(WorldMatrix), normalize( vSkinnedBitangent ) ) );

			Out.vUV0 = v.vUV0;
#ifdef PDX_MESH_UV1
			Out.vUV1 = v.vUV1;
#else
			Out.vUV1 = v.vUV0;
#endif

			return Out;
		}

	]]

	MainCode VertexPdxMeshStandardShadow
		ConstantBuffers = { Common, ShipConstants, Shadow }
	[[
		VS_OUTPUT_PDXMESHSHADOW main( const VS_INPUT_PDXMESHSTANDARD v )
		{
		  	VS_OUTPUT_PDXMESHSHADOW Out;
			float4 vPosition = float4( v.vPosition.xyz, 1.0 );
			Out.vPosition = mul( WorldMatrix, vPosition );
			Out.vPosition = mul( ViewProjectionMatrix, Out.vPosition );
			Out.vDepthUV0 = float4( Out.vPosition.zw, v.vUV0 );
			return Out;
		}

	]]

	MainCode VertexPdxMeshStandardSkinnedShadow
		ConstantBuffers = { Common, ShipConstants, Animation, Shadow }
	[[
		VS_OUTPUT_PDXMESHSHADOW main( const VS_INPUT_PDXMESHSTANDARD_SKINNED v )
		{
		  	VS_OUTPUT_PDXMESHSHADOW Out;

			float4 vPosition = float4( v.vPosition.xyz, 1.0 );
			float4 vSkinnedPosition = float4( 0, 0, 0, 0 );

			float4 vWeight = float4( v.vBoneWeight.xyz, 1.0f - v.vBoneWeight.x - v.vBoneWeight.y - v.vBoneWeight.z );

			for( int i = 0; i < PDXMESH_MAX_INFLUENCE; ++i )
		    {
				int nIndex = int( v.vBoneIndex[i] );
				float4x4 mat = matBones[nIndex];
				vSkinnedPosition += mul( mat, vPosition ) * vWeight[i];
			}

			Out.vPosition = mul( WorldMatrix, vSkinnedPosition );
			Out.vPosition = mul( ViewProjectionMatrix, Out.vPosition );
			Out.vDepthUV0 = float4( Out.vPosition.zw, v.vUV0 );
			return Out;
		}

	]]
}