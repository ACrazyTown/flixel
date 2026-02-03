package flixel.system.render.gl;

import openfl.display.Shader;

class FlxGLShader extends openfl.display.Shader
{
	@:glVertexHeader("
		attribute vec4 aPosition;
		attribute vec4 aColor;

		uniform mat4 uProjection;
		uniform mat4 uModel;

		uniform vec4 uColor;
		uniform vec4 uColorOffset;

		varying vec4 vColor;
	")
	@:glVertexBody("
		vec4 col = aColor.bgra * uColor + uColorOffset;
		col = clamp(col, 0.0, 1.0);
		vColor = vec4(col.rgb * col.a, col.a);

		gl_Position = uProjection * uModel * aPosition;
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
