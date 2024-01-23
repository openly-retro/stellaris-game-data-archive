VertexStruct VS_INPUT_PDXMESHSTANDARD
{
    float3 vPosition		: POSITION;
	float3 vNormal      	: TEXCOORD0;
	float4 vTangent			: TEXCOORD1;
	float2 vUV0				: TEXCOORD2;
@ifdef PDX_MESH_UV1
	float2 vUV1				: TEXCOORD3;
@endif
};

VertexStruct VS_INPUT_PDXMESHSTANDARD_SKINNED
{
    float3 vPosition		: POSITION;
	float3 vNormal      	: TEXCOORD0;
	float4 vTangent			: TEXCOORD1;
	float2 vUV0				: TEXCOORD2;
@ifdef PDX_MESH_UV1
	float2 vUV1				: TEXCOORD3;
@endif
	uint4 vBoneIndex 		: TEXCOORD4;
	float3 vBoneWeight		: TEXCOORD5;
};

VertexStruct VS_OUTPUT_PDXMESHSTANDARD
{
    float4 vPosition		: PDX_POSITION; #Position * World * ViewProj
	float3 vNormal			: TEXCOORD0;
	float3 vTangent			: TEXCOORD1;
	float3 vBitangent		: TEXCOORD2;
	float2 vUV0				: TEXCOORD3;
	float2 vUV1				: TEXCOORD4;
	float4 vPos				: TEXCOORD5; #Position * World 
	float4 vSphere			: TEXCOORD6; #Local position
	float3 vObjectNormal	: TEXCOORD7;
};

VertexStruct VS_OUTPUT_PDXMESHSHADOW
{
    float4 vPosition	: PDX_POSITION;
	float4 vDepthUV0	: TEXCOORD0;
};

VertexStruct VS_INPUT_DEBUGNORMAL
{
    float3 vPosition		: POSITION;
	float3 vNormal      	: TEXCOORD0;
	float4 vTangent			: TEXCOORD1;
	float2 vUV0				: TEXCOORD2;
	float2 vUV1				: TEXCOORD3;
	float  vOffset      	: TEXCOORD6;
};

VertexStruct VS_INPUT_DEBUGNORMAL_SKINNED
{
    float3 vPosition		: POSITION;
	float3 vNormal      	: TEXCOORD0;
	float4 vTangent			: TEXCOORD1;
	float2 vUV0				: TEXCOORD2;
	float2 vUV1				: TEXCOORD3;
	uint4 vBoneIndex		: TEXCOORD4;
	float3 vBoneWeight		: TEXCOORD5;
	float  vOffset      	: TEXCOORD6;
};

VertexStruct VS_OUTPUT_DEBUGNORMAL
{
    float4 vPosition : PDX_POSITION;
	float2 vUV0		 : TEXCOORD0;
	float  vOffset	 : TEXCOORD1;
};


VertexStruct VS_OUTPUT_PDXMESHNAVIGATIONBUTTON
{
    float4 vPosition	: PDX_POSITION;
	float2 vUV0			: TEXCOORD0;
	float4 vPos			: TEXCOORD1;
};

VertexStruct VS_OUTPUT_PDXMESHSHIELD
{
	float4 vPosition	: PDX_POSITION;
	float2 vUV0			: TEXCOORD0;
	float4 vPos			: TEXCOORD1;
};