package flixel.system.render.gl;

import flixel.system.render.gl.impl.GL;
import flixel.system.render.gl.impl.GLBuffer;
import lime.utils.UInt16Array;
import lime.utils.Float32Array;

class FlxDrawQuadsCommand extends FlxDrawCommand<FlxDrawQuadsCommand>
{
    /**
     * x, y, u, v, color, color offset
     */
    static inline final ELEMENTS_PER_VERTEX:Int = 6;

    /**
     * The number of quads this command can batch.
     */
    public var size(default, null):Int;

    var vertices:Float32Array;
    var vertexBuffer:GLBuffer;

    var uvs:Float32Array;
    var uvBuffer:GLBuffer;

    var colors:Float32Array;
    var colorBuffer:GLBuffer;

    var indices:UInt16Array;
    var indexBuffer:GLBuffer;

    public function new(size:Int = 0)
    {
        super();
        type = QUADS;

        if (size <= 0)
            size = FlxCameraView.QUADS_PER_BATCH;

        vertices = new Float32Array(size * FlxCameraView.VERTICES_PER_QUAD * ELEMENTS_PER_VERTEX);
        vertexBuffer = GL.createBuffer();

        final numIndices:Int = size * FlxCameraView.INDICES_PER_QUAD;
        indices = new UInt16Array(numIndices)
        indexBuffer = GL.createBuffer();

        var indexPos:Int = 0;
		var index:Int = 0;

		while (indexPos < numIndices)
		{
			indices[indexPos + 0] = index + 0;
			indices[indexPos + 1] = index + 1;
			indices[indexPos + 2] = index + 2;
			indices[indexPos + 3] = index + 1;
			indices[indexPos + 4] = index + 3;
			indices[indexPos + 5] = index + 2;

			indexPos += FlxCameraView.INDICES_PER_QUAD;
			index += FlxCameraView.VERTICES_PER_QUAD;
		}
    }
}
