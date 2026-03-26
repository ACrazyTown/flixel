package flixel.system.render.gl;

#if FLX_RENDER_OPENGL

import openfl.display.Shader;

// TODO ant: add temporary compatibility for pre-GL shaders, and then remove it in 7.0.0
/**
 * A basic shader used by the OpenGL renderer
 */
class FlxGLShader extends Shader
{
	@:glVertexHeader("
		attribute vec4 aPosition;
		attribute vec4 aColorMultiplier;
		attribute vec4 aColorOffset;
        attribute vec2 aTexCoord;

		uniform mat4 uMatrix;
        uniform vec2 uTextureSize;

		varying vec4 vColorMultiplier;
		varying vec4 vColorOffset;
        varying vec2 vTexCoord;
	", true)
	@:glVertexBody("
		vColorMultiplier = aColorMultiplier;
		vColorOffset = aColorOffset;

		vTexCoord = aTexCoord;

		gl_Position = uMatrix * aPosition;
	", true)
	@:glVertexSource("
		#pragma header

		void main(void) 
        {
			#pragma body
		}
	", true)
	@:glFragmentHeader("
		varying vec4 vColorMultiplier;
		varying vec4 vColorOffset;
        varying vec2 vTexCoord;

        uniform sampler2D uImage0;

        vec4 flixel_texture2D(sampler2D sampler, vec2 coord)
        {
            vec4 color = texture2D(sampler, coord);

			color = vec4(color.rgb / color.a, color.a);
			color = (color * vColorMultiplier) + vColorOffset;

            return vec4(color.rgb * color.a, color.a);
        }
	", true)
	@:glFragmentBody("
		gl_FragColor = flixel_texture2D(uImage0, vTexCoord);
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
	public function new()
	{
		super();
	}
}
#end
