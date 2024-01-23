Includes = {
	"posteffect_base.fxh"
	"constants.fxh"
	"standardfuncsgfx.fxh"
}

PixelShader =
{
	Samplers =
	{
		MainScene =
		{
			Index = 0
			MagFilter = "Linear"
			MinFilter = "Linear"
			MipFilter = "None"
			AddressU = "Clamp"
			AddressV = "Clamp"
		}
		LensColor =
		{
			Index = 1
			MagFilter = "Linear"
			MinFilter = "Linear"
			MipFilter = "None"
			AddressU = "Wrap"
			AddressV = "Wrap"
		}
	}
}


VertexStruct VS_INPUT
{
    int2 position	: POSITION;
};

VertexStruct VS_OUTPUT_DOWNSAMPLE
{
    float4 position			: PDX_POSITION;
	float2 uv				: TEXCOORD0;
};

ConstantBuffer( Downsample, 2, 39 )
{
	float Scale;
	float Bias;	
	float GhostDispersal;
	float HaloWidth;
	float HaloPow;
	float DistortionFactor;
	float DistortionFactorHalo;
};

VertexShader =
{
	MainCode VertexShader
		ConstantBuffers = { Common, PostEffect, Downsample }
	[[
		VS_OUTPUT_DOWNSAMPLE main( const VS_INPUT VertexIn )
		{
			VS_OUTPUT_DOWNSAMPLE VertexOut;
			VertexOut.position = float4( VertexIn.position, 0.0f, 1.0f );
			
			VertexOut.uv = float2(VertexIn.position.x, FIX_FLIPPED_UV(VertexIn.position.y)) * 0.5 + 0.5;
			VertexOut.uv.y = 1.0f - VertexOut.uv.y;
			
		#ifdef PDX_DIRECTX_9 // Half pixel offset
			VertexOut.position.xy += float2( -InvDownSampleSize.x, InvDownSampleSize.y );
		#endif
		
			return VertexOut;
		}
	]]
}

PixelShader =
{
	MainCode PixelShader
		ConstantBuffers = { Common, PostEffect, Downsample }
	[[
	
		float4 main( VS_OUTPUT_DOWNSAMPLE Input ) : PDX_COLOR
		{
			float4 vColor = tex2Dlod0( MainScene, Input.uv );
			//float vMax = saturate( max( max( vColor.r, vColor.g ), vColor.b ) - BrightThreshold );
			float vMax = max(0, max( max( vColor.r, vColor.g ), vColor.b ) - BrightThreshold );
			vMax /= (0.5 + vMax);
			vMax += vColor.a * EmissiveBloomStrength;
		
			float logLuminance = log(max(0.0, dot(vColor.rgb, LUMINANCE_VECTOR)) + 0.0001f);
			
			return float4( vColor.rgb * vMax, logLuminance );
		}
	]]
	
	MainCode PixelShaderDownsample
		ConstantBuffers = { Common, PostEffect, Downsample }
	[[
		float4 main( VS_OUTPUT_DOWNSAMPLE Input ) : PDX_COLOR
		{
			float4 vColor = tex2Dlod0( MainScene, Input.uv * BloomToScreenScale );
			return vColor;
		}
	]]
	
	MainCode PixelShaderLensFlare
		ConstantBuffers = { Common, PostEffect, Downsample }
	[[
	
		float3 ChromaticSample( in sampler2D Texture, float2 UV, float2 Direction, float3 Distortion )
		{
			float3 Ret = float3( tex2Dlod0( Texture, UV + Direction * Distortion.r).r,
								 tex2Dlod0( Texture, UV + Direction * Distortion.g).g,
								 tex2Dlod0( Texture, UV + Direction * Distortion.b).b );
			Ret = max( vec3(0.0), (Ret + Bias) * Scale );
			return Ret;
		}
		
		static const int NumGhosts = 8;

		float4 main( VS_OUTPUT_DOWNSAMPLE Input ) : PDX_COLOR
		{
			
			float2 UV = vec2(1.0) - Input.uv;
			// In order to avoid normalizing a (0,0) later we add a small epsilon to avoid any rendering artefacts caused by undefined behaviour
			float2 GhostVec = (vec2(0.500001) - UV) * GhostDispersal;
			
			float3 ChromaticDistortion = float3( -InvDownSampleSize.x, 0.0, InvDownSampleSize.x ) * DistortionFactor;
			float2 ChromaticDirection = normalize(GhostVec);
   
			float4 vColor = vec4(0.0);

			for ( int i = 0; i < NumGhosts; ++i )
			{ 
				float2 Offset = frac(UV + GhostVec * float(i));
				vColor.rgb += ChromaticSample( MainScene, Offset * BloomToScreenScale, ChromaticDirection, ChromaticDistortion );
			}
			
			// Apply lens color
			float2 LensColorUV = float2( length(vec2(0.5) - UV) / length( vec2(0.5) ), 0.5 );
			vColor.rgb *= tex2Dlod0( LensColor, LensColorUV ).rgb;
			
			// Apply lens halo
			float2 HaloVec = normalize( GhostVec ) * HaloWidth;
			
			// HaloWeight is in range [0, 1]
			float HaloWeight = length(vec2(0.5) - frac( UV + HaloVec ) ) / length(vec2(0.5));
			HaloWeight = pow(abs(1.0 - HaloWeight), HaloPow);

			vColor.rgb += ChromaticSample( MainScene, ( UV + HaloVec ) * BloomToScreenScale, ChromaticDirection, ChromaticDistortion * DistortionFactorHalo) * HaloWeight;
		  
			return vColor;
		}
	]]
}


BlendState BlendState
{
	BlendEnable = no
}

BlendState BlendStateAdditive
{
	BlendEnable = yes
	SourceBlend = "ONE"
	DestBlend = "ONE"
	WriteMask = "RED|GREEN|BLUE|ALPHA"
}


Effect downsample
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader"
}

Effect downsample2
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderDownsample"
}

Effect downsample3
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderDownsample"
	BlendState = "BlendStateAdditive"
}

Effect lens_flare
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderLensFlare"
}
