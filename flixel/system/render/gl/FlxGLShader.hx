package flixel.system.render.gl;

import openfl.display.Shader;

// changing uniforms breaks the current batch
//
// QUADS:
// - pass in color transform as vertices, therefore are batchable
//
// TRIANGLES:
// - pass in color transform as a uniform, therefore aren't batchable (and weren't regardless)

class FlxGLShader extends Shader
{
	@:glVertexHeader("
		attribute vec4 aPosition;    // Vertex position
		attribute vec4 aColor; 	     // Vertex color (or color transform multiplier, for quads)

		uniform mat4 uMatrix;     	 // Projection matrix (+ model matrix when rendering triangles)

		uniform vec4 uColor;         // Color transform multiplier (Triangles only)
		uniform vec4 uColorOffset;   // Color transform offset (Triangles only)

		varying vec4 vColor;         // Final color (vertex color * multiplier + offset), passed down to fragment shader
	")
	@:glVertexBody("
		vec4 col = clamp(aColor.bgra * uColor + uColorOffset, 0.0, 1.0);
		vColor = vec4(col.rgb * col.a, col.a);

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

		void main(void)
		{
			#pragma body

			gl_FragColor = gl_FragColor.bgra;
		}
	")
	#else
	@:glFragmentSource("
		#pragma header

		void main(void) 
		{
			#pragma body
		}
	")
	#end
	public function new(?code)
	{
		super(code);
	}
}
