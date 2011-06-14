varying vec4  rawpos;
varying vec4  ecPosition;
varying vec3  VNormal;
varying vec3  VTangent;
varying vec3  VBinormal;
varying vec3  Normal;
varying vec4  constantColor;
varying float bump;
varying float fogCoord;

attribute vec3 tangent;
attribute vec3 binormal;

void main(void)
{
	rawpos = gl_Vertex;
	ecPosition = gl_ModelViewMatrix * rawpos;
	Normal = normalize(gl_Normal);
	VNormal = gl_NormalMatrix * gl_Normal;
	VTangent = gl_NormalMatrix * tangent;
	VBinormal = gl_NormalMatrix * binormal;
	bump = 1.0;

	gl_FrontColor = gl_Color;
	constantColor = gl_FrontMaterial.emission
		+ gl_FrontColor * (gl_LightModel.ambient + gl_LightSource[0].ambient);  
	gl_Position = ftransform();
	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	
    fogCoord = abs(ecPosition.z / ecPosition.w);
	
}