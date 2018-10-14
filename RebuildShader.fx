//************
// VARIABLES *
//************
cbuffer cbPerObject
{
	float4x4 m_MatrixWorldViewProj : WORLDVIEWPROJECTION;
	float4x4 m_MatrixWorld : WORLD;
	float3 m_LightDir={0.2f,-1.0f,0.2f};
}

RasterizerState FrontCulling 
{ 
	FillMode = SOLID;
	CullMode = None;
};

SamplerState samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

Texture2D m_TextureDiffuse; 
float m_Time : TIME;
bool m_CanSparkle;
bool m_IsSparklingDown;
bool m_IsSparklingUp;
static float m_Speed;
static float m_Velocity[16];

//**********
// STRUCTS *
//**********
struct VS_DATA
{
	float3 Position : POSITION;
	float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD;
};

struct GS_DATA
{
	float4 Position : SV_POSITION;
	float3 Normal : NORMAL;
	float2 TexCoord : TEXCOORD0;
	float3 Color : COLOR;
};

//****************
// VERTEX SHADER *
//****************
VS_DATA MainVS(VS_DATA vsData)
{
	//Step 1.
	//Delete this transformation code and just return the VS_DATA parameter (vsData)
	//Don't forget to change the return type!
	
	return vsData;
}

//******************
// GEOMETRY SHADER *
//******************

void CreateVertex(inout TriangleStream<GS_DATA> triStream, float3 pos, float3 normal, float2 texCoord, float3 color)
{
	//Step 1. Create a GS_DATA object
	GS_DATA temp = (GS_DATA)0;
	//Step 2. Transform the position using the WVP Matrix and assign it to (GS_DATA object).Position (Keep in mind: float3 -> float4)
	temp.Position = mul(float4(pos, 1), m_MatrixWorldViewProj);
	//Step 3. Transform the normal using the World Matrix and assign it to (GS_DATA object).Normal (Only Rotation, No translation!)
	temp.Normal = mul(normal, (float3x3)m_MatrixWorld);
	//Step 4. Assign texCoord to (GS_DATA object).TexCoord
	temp.TexCoord = texCoord;
	//Step 5. Append (GS_DATA object) to the TriangleStream parameter (TriangleStream::Append(...))
	temp.Color = color;
	triStream.Append(temp);
}

void CreateTriangle(inout TriangleStream<GS_DATA> triStream, VS_DATA p1, VS_DATA p2, VS_DATA p3, float3 color)
{
	triStream.RestartStrip();
	CreateVertex(triStream, p1.Position, p1.Normal, p1.TexCoord, color);
	CreateVertex(triStream, p2.Position, p2.Normal, p2.TexCoord, color);
	CreateVertex(triStream, p3.Position, p3.Normal, p3.TexCoord, color);
}

[maxvertexcount(48)]
void GS_SHADER(triangle VS_DATA vertices[3], inout TriangleStream<GS_DATA> triStream)
{
	// VARIABLES
	int levels = 2;
	// position
	float3 p2PosNorm = (vertices[1].Position - vertices[0].Position)/ pow(2,levels) ;
	float3 p3PosNorm = (vertices[2].Position - vertices[0].Position) / pow(2,levels);
	// uv
	float2 p2UvNorm = (vertices[1].TexCoord.xy - vertices[0].TexCoord.xy) / pow(2,levels);
	float2 p3UvNorm = (vertices[2].TexCoord.xy - vertices[0].TexCoord.xy) / pow(2,levels);
    
	// vs_data
	VS_DATA p1;
	p1.Position = vertices[0].Position; 
	p1.Normal = vertices[0].Normal; 
	p1.TexCoord = vertices[0].TexCoord;
	VS_DATA p2;
	p2.Position = vertices[0].Position + p2PosNorm;
	p2.TexCoord = vertices[0].TexCoord + p2UvNorm;
	VS_DATA p3;
	p3.Position = vertices[0].Position + p3PosNorm;
	p3.TexCoord = vertices[0].TexCoord + p3UvNorm;
    
    p2.Normal = normalize(cross(p1.Position - p2.Position,p3.Position - p2.Position));
    p3.Normal = normalize(cross(p2.Position - p3.Position,p1.Position - p3.Position));
    
	// TESSELLATION
	int cols = pow(2,levels)+3;
	int rows = pow(2,levels);
	bool pushlower = false;
	int pushlowercount = 0;
	int triangleIndex = 0;
	
	m_Speed = 0.5;
		
	for(int row = 0; row  < rows; ++row )
	{
		for(int col = 0; col < cols;++col)
		{
			// normals
			p1.Normal = -normalize(cross(p3.Position - p1.Position,p2.Position - p1.Position));
			p2.Normal = -normalize(cross(p1.Position - p2.Position,p3.Position - p2.Position));
			p3.Normal = -normalize(cross(p2.Position - p3.Position,p1.Position - p3.Position));
			
			if(triangleIndex == 0) p1.Normal = vertices[0].Normal;
			if(triangleIndex == 6) p3.Normal = vertices[2].Normal;
			if(triangleIndex == 15) p2.Normal = vertices[1].Normal;
			
            p1.Normal = normalize(mul(p1.Normal, (float3x3)m_MatrixWorld));
			p2.Normal = normalize(mul(p2.Normal, (float3x3)m_MatrixWorld));
			p3.Normal = normalize(mul(p3.Normal, (float3x3)m_MatrixWorld));
            
			// add physx
			VS_DATA p1Temp = p1;
			VS_DATA p2Temp = p2;
			VS_DATA p3Temp = p3;
			
			// sparkling down			
			if(m_CanSparkle)
			{		
				m_Velocity[triangleIndex] = m_Speed * m_Time/2;
				if(m_IsSparklingDown)
				{
					p1Temp.Position.y -= m_Velocity[triangleIndex];
					p2Temp.Position.y -= m_Velocity[triangleIndex];
					p3Temp.Position.y -= m_Velocity[triangleIndex];
				}
				
				if(m_IsSparklingUp)
				{
					p1Temp.Position.y = 0;
					p2Temp.Position.y = 0;
					p3Temp.Position.y = 0;
					p1Temp.Position.y += m_Velocity[triangleIndex];
					p2Temp.Position.y += m_Velocity[triangleIndex];
					p3Temp.Position.y += m_Velocity[triangleIndex];
				}
				
				// if on original pos
				if(p1Temp.Position.y > p1.Position.y)
				{
					p1Temp.Position.y = p1.Position.y;
					p2Temp.Position.y = p2.Position.y;
					p3Temp.Position.y = p3.Position.y;
					if(p1Temp.Position.y + 0.05f > m_Speed * m_Time/2   && m_IsSparklingUp)
					CreateTriangle(triStream,p1Temp,p2Temp,p3Temp,float3(0,2,0));
					else
					CreateTriangle(triStream,p1Temp,p2Temp,p3Temp, float3(1,1,1));
				}
				else
				// if on ground
				if(p1Temp.Position.y < 0 && p2Temp.Position.y < 0 && p3Temp.Position.y < 0)
				{		
					p1Temp.Position.y = 0;
					p2Temp.Position.y = 0;
					p3Temp.Position.y = 0;
					p1Temp.Normal = p2Temp.Normal = p3Temp.Normal = float3(0,0,0);
					CreateTriangle(triStream,p1Temp,p2Temp,p3Temp, float3(1,1,1));
				}	
				// what lies on ground
				else
				{
					if(p1Temp.Position.y>0 && p1Temp.Position.y<0.05 && m_IsSparklingDown)
						CreateTriangle(triStream,p1Temp,p2Temp,p3Temp,float3(2,0,0));
					else
						CreateTriangle(triStream,p1Temp,p2Temp,p3Temp,float3(1,1,1));
				}
			}
			else
			// if no sparkling
			{
				CreateTriangle(triStream,p1,p2,p3, float3(1,1,1));
			}
			
			// next triangle
			if(pushlower)
			{
				pushlower = false;
				p3.Position += p3PosNorm;
				p1.Position += p3PosNorm - p2PosNorm; 
				p3.TexCoord += p3UvNorm;
				p1.TexCoord += p3UvNorm - p2UvNorm;
				++pushlowercount;
			}
			else
			{
				pushlower = true;
				p1.Position += p2PosNorm;
				p2.Position += p3PosNorm;
				p1.TexCoord += p2UvNorm;
				p2.TexCoord += p3UvNorm;
			}
			++triangleIndex;
		}
		p1.Position = vertices[0].Position + (row+1)*p2PosNorm;
	 	p2.Position = vertices[0].Position + p2PosNorm + (row+1)*p2PosNorm;
	 	p3.Position = vertices[0].Position + p3PosNorm + (row+1)*p2PosNorm;
		p1.TexCoord = vertices[0].TexCoord + (row+1)*p2UvNorm;
	 	p2.TexCoord = vertices[0].TexCoord + p2UvNorm + (row+1)*p2UvNorm;
	 	p3.TexCoord = vertices[0].TexCoord + p3UvNorm + (row+1)*p2UvNorm;
		
		cols -=2;
		pushlowercount = 0;
		pushlower = false;
		
	}
}

//***************
// PIXEL SHADER *
//***************
float4 MainPS(GS_DATA input) : SV_TARGET 
{
		input.Normal=-normalize(input.Normal);
		float alpha = m_TextureDiffuse.Sample(samLinear,input.TexCoord).a;
		float3 color = m_TextureDiffuse.Sample( samLinear,input.TexCoord ).rgb * input.Color;
		float s = max(dot(m_LightDir,input.Normal), 0.4f);
		return float4(color*s,alpha);
	
}


//*************
// TECHNIQUES *
//*************
technique10 DefaultTechnique 
{
	pass p0 {
		SetRasterizerState(FrontCulling);	
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, GS_SHADER()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
}