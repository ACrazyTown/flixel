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

    /**
     * Internal flag to check whether data needs to be reuploaded to the GPU.
     */
    var dirty:Bool = false;

    public function new(size:Int = 0)
    {
        super();
        type = QUADS;

        if (size <= 0)
            size = FlxCameraView.QUADS_PER_BATCH;

        final numVertices:Int = size * FlxCameraView.VERTICES_PER_QUAD * 2;
        vertices = new Float32Array(numVertices); 

        // reuse numVertices because both of these buffers also store 2 values per vertex
        uvs = new Float32Array(numVertices);
        colors = new Float32Array(numVertices);

        final numIndices:Int = size * FlxCameraView.INDICES_PER_QUAD;
        indices = new UInt16Array(numIndices); // TODO ant -- use 32bit indices instead?

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

        vertexBuffer = GL.createBuffer();
        uvBuffer = GL.createBuffer();
        colorBuffer = GL.createBuffer();
        indexBuffer = GL.createBuffer();
    }

    override function destroy():Void
    {
        vertices = null;
        uvs = null;
        colors = null;
        indices = null;

        GL.deleteBuffer(vertexBuffer);
        GL.deleteBuffer(uvBuffer);
        GL.deleteBuffer(colorBuffer);
        GL.deleteBuffer(indexBuffer);
    }

    override function reset():Void
    {
        dirty = true;
    }

    override function flush(?view:FlxCameraView):Void
    {
        uploadData();
    }

    function uploadData():Void
    {
        if (dirty)
        {
            dirty = false;
        }
    }
}
