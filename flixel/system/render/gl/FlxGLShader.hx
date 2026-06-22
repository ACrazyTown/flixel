package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.graphics.shaders.FlxShader;

/**
 * A basic shader used by the OpenGL renderer
 */
class FlxGLShader extends FlxShader
{
	public function new()
	{
		super({
			glsl: {
				vertex: {
					source: "
						attribute vec4 flixel_aPosition;
						attribute vec4 flixel_aColorMultiplier;
						attribute vec4 flixel_aColorOffset;
						attribute vec2 flixel_aTextureCoord;

						uniform mat4 flixel_uMatrix;

						varying vec4 flixel_vColorMultiplier;
						varying vec4 flixel_vColorOffset;
						varying vec2 flixel_vTextureCoord;

						void main()
						{
							// The colors are ARGB but because of little endian they are stored as BGRA
							flixel_vColorMultiplier = flixel_aColorMultiplier.bgra;
							flixel_vColorOffset = flixel_aColorOffset.bgra;

							flixel_vTextureCoord = flixel_aTextureCoord;

							gl_Position = flixel_uMatrix * flixel_aPosition;
							gl_PointSize = 1.0;
						}",
					attributes: [
						"flixel_aPosition",
						"flixel_aColorMultiplier",
						"flixel_aColorOffset",
						"flixel_aTextureCoord"
					],
					precision: HIGH
				},
				fragment: {
					source: "
						varying vec4 flixel_vColorMultiplier;
						varying vec4 flixel_vColorOffset;
						varying vec2 flixel_vTextureCoord;

						uniform sampler2D flixel_uTexture;
						uniform vec2 flixel_uTextureSize;

						vec4 flixel_texture(sampler2D sampler, vec2 coord)
						{
							vec4 color = texture2D(sampler, coord);

							color = vec4(color.rgb / color.a, color.a);
							color = (color * flixel_vColorMultiplier) + flixel_vColorOffset;

							return vec4(color.rgb * color.a, color.a);
						}

						// For backwards compatibility, remove in v7
						vec4 flixel_texture2D(sampler2D sampler, vec2 coord)
						{
							return flixel_texture(sampler, coord);
						}

						void main()
						{
							gl_FragColor = flixel_texture(flixel_uTexture, flixel_vTextureCoord);
						}",
					precision: HIGH
				}
			}
		});
	}
}
#end
