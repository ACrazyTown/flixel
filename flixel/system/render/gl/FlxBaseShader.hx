package flixel.system.render.gl;

import openfl.display.Shader;

class FlxBaseShader extends openfl.display.Shader
{
	@:glVertexHeader("
		attribute vec4 aPosition;
		attribute vec4 aColor;

		uniform mat4 uMatrix;

		varying vec4 vColor;
	")
	@:glVertexBody("
		vColor = vec4(aColor.bgr * aColor.a, aColor.a);
		gl_Position = uMatrix * aPosition;
	")
	@:glVertexSource("
		#pragma header

		void main(void) {

			#pragma body

		}
	")
	@:glFragmentHeader("
		varying vec4 vColor;
	")
	@:glFragmentBody("	
		gl_FragColor = vColor;
	")
	#if emscripten
	@:glFragmentSource("
		#pragma header

		void main(void) {

			#pragma body

			gl_FragColor = gl_FragColor.bgra;

		}
	")
	#else
	@:glFragmentSource("
		#pragma header

		void main(void) {

			#pragma body

		}
	")
	#end
	public function new(?code)
	{
		super(code);
	}
}
