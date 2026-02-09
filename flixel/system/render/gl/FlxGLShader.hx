package flixel.system.render.gl;

import openfl.display.Shader;

/**
 * Basic shader for colored quads/triangles.
 */
class FlxGLShader extends Shader
{
	@:glVertexHeader("
		attribute vec4 aPosition;    // Vertex position
		attribute vec4 aColor; 	     // Color (vertex color * multiplier + offset)

		uniform mat4 uMatrix;     	 // Projection matrix (+ model matrix when rendering triangles)

		varying vec4 vColor;         // aColor passed down to fragment shader
	", true)
	@:glVertexBody("
		vColor = vec4(aColor.bgr * aColor.a, aColor.a);
		gl_Position = uMatrix * aPosition;
	", true)
	@:glVertexSource("
		#pragma header

		void main(void) {

			#pragma body

		}
	", true)
	@:glFragmentHeader("
		varying vec4 vColor;
	", true)
	@:glFragmentBody("
		gl_FragColor = vColor;
	", true)
	#if emscripten
	@:glFragmentSource("
		#pragma header

		void main(void)
		{
			#pragma body

			gl_FragColor = gl_FragColor.bgra;
		}
	", true)
	#else
	@:glFragmentSource("
		#pragma header

		void main(void) 
		{
			#pragma body
		}
	", true)
	#end
	public function new(?code)
	{
		super(code);
	}
}
