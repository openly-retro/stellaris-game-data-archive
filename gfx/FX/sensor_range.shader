BlendState BlendState
{
	BlendEnable = yes
	AlphaTest = no
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	WriteMask = "RED|GREEN|BLUE"
}

RasterizerState RasterizerState 
{
	CullMode = "CULL_NONE"
}

DepthStencilState DepthStencilState
{
	DepthEnable = no
}

VertexStruct VS_INPUT
{
    float2 	vPosition  	: POSITION;
    float 	vMedium 	: TEXCOORD0;
};

VertexStruct VS_OUTPUT
{
    float4  vPosition 	: PDX_POSITION;
    float 	vMedium 	: TEXCOORD0;
};

ConstantBuffer( Common, 0, 0 )
{
	float4x4 ModelViewProjection;
};

ConstantBuffer( Colors, 1, 0 )
{
	float4 MediumColor;
	float4 LowColor;
}

VertexShader =
{
	MainCode VertexShader
		ConstantBuffers = { Common }
	[[
		VS_OUTPUT main(const VS_INPUT v )
		{
			VS_OUTPUT Out;
			Out.vPosition  	= mul( ModelViewProjection, float4( v.vPosition.x, -0.3, v.vPosition.y, 1.0 ) );
			Out.vMedium		= v.vMedium;
			return Out;
		}
	]]
}

PixelShader =
{
	MainCode PixelShader
	ConstantBuffers = { Colors }
	[[
		float4 main( VS_OUTPUT v ) : PDX_COLOR
		{
			return lerp( LowColor, MediumColor, saturate( ( v.vMedium - 1.9 ) * 1000.0 ) );
		}	
	]]
}

Effect SensorRange
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader"
}
