package flixel.system.render.gl;

import flixel.system.render.gl.impl.GLShader;
import flixel.system.render.gl.impl.GLProgram;
import flixel.graphics.shaders.quads.FlxTexturedShader;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.graphics.FlxMaterial;
import lime.math.Matrix4;
import flixel.util.FlxColor;
import flixel.graphics.shaders.FlxShader;
import flixel.system.render.gl.impl.GLInternal;
import flixel.system.render.gl.impl.GL;
import flixel.system.render.gl.impl.GLBuffer;
import flixel.system.render.gl.impl.GLUniformLocation;
import lime.utils.UInt16Array;
import lime.utils.Float32Array;

// switch back to a single vertex buffer

// TODO ant: Beeble's branch has roundPixels, used by the debug layer
class FlxDrawQuadsCommand extends FlxDrawCommand<FlxDrawQuadsCommand>
{
    public static var defaultTexturedShader:FlxShader = new FlxTexturedShader();

    public static var defaultColoredShader:FlxShader = null;

    /**
     * x, y, u, v, color, color offset
     */
    static inline final ELEMENTS_PER_VERTEX:Int = 6;

    /**
     * The number of quads this command can batch.
     */
    public var size(default, null):Int;

    /**
     * Shortcut for `material.shader`.
     * If `material.shader` is null, the default shader will be used instead.
     */
    public var shader:FlxShader;

    public var numQuads:Int = 0;

    var positions:Float32Array;
    var positionBuffer:GLBuffer;
    var positionIndex:Int = 0;

    var uvs:Float32Array;
    var uvBuffer:GLBuffer;
    var uvIndex:Int = 0;

    var colors:Float32Array;
    var colorBuffer:GLBuffer;
    var colorIndex:Int = 0;

    var indices:UInt16Array;
    var indexBuffer:GLBuffer;

    /**
     * Internal flag to check whether data needs to be reuploaded to the GPU.
     */
    var dirty:Bool = false;

    @:deprecated("temp")
    var __temp__shader:ShaderImpl;
    var __temp__cache:Map<String, ShaderImpl> = [];

    public function new(size:Int = 0)
    {
        super();
        type = QUADS;

        if (size <= 0)
            size = FlxCameraView.QUADS_PER_BATCH;

        final numPositions:Int = size * FlxCameraView.VERTICES_PER_QUAD * 2;
        trace(numPositions);
        positions = new Float32Array(numPositions); 

        // reuse numPositions because both of these buffers also store 2 values per vertex
        uvs = new Float32Array(numPositions);
        colors = new Float32Array(numPositions);

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

        // create GL buffers and upload them to the GPU
        final verticesNumBytes:Int = numPositions * Float32Array.BYTES_PER_ELEMENT;
        positionBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
        GLInternal.bufferData(GL.ARRAY_BUFFER, positions, GL.DYNAMIC_DRAW, null, verticesNumBytes);

        uvBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, uvBuffer);
        GLInternal.bufferData(GL.ARRAY_BUFFER, uvs, GL.DYNAMIC_DRAW, null, verticesNumBytes);

        colorBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, colorBuffer);
        GLInternal.bufferData(GL.ARRAY_BUFFER, colors, GL.DYNAMIC_DRAW, null, verticesNumBytes);

        final indicesNumBytes:Int = numIndices * UInt16Array.BYTES_PER_ELEMENT;
        indexBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, indexBuffer);
        GLInternal.bufferData(GL.ELEMENT_ARRAY_BUFFER, indices, GL.STATIC_DRAW, null, indicesNumBytes);
    }

    override function destroy():Void
    {
        positions = null;
        uvs = null;
        colors = null;
        indices = null;

        GL.deleteBuffer(positionBuffer);
        GL.deleteBuffer(uvBuffer);
        GL.deleteBuffer(colorBuffer);
        GL.deleteBuffer(indexBuffer);
    }

    override function reset():Void
    {
        super.reset();

        dirty = true;

        positionIndex = 0;
        uvIndex = 0;
        colorIndex = 0;

        numQuads = 0;
    }

    override function flush(?view:FlxCameraView):Void
    {
        if (numQuads == 0)
            return;

        uploadData();

        // TODO ant : blend mode

        GL.activeTexture(GL.TEXTURE0);
        // GLInternal.bindTexture(texture);
        @:privateAccess
        GL.bindTexture(GL.TEXTURE_2D, graphic.bitmap.getTexture(flixel.FlxG.stage.context3D).__getTexture());

        GL.uniform1i(shader.data.uImage0.index, 0);

        GLHelper.setTextureSmoothing(material.antialiasing);
        GLHelper.setTextureRepeat(material.repeat);

        GL.uniform2f(shader.data.uTextureSize.index, graphic.width, graphic.height);

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, indexBuffer);
        GL.drawElements(GL.TRIANGLES, numQuads * FlxCameraView.INDICES_PER_QUAD, GL.UNSIGNED_SHORT, 0);
        // GL.drawArrays(GL.TRIANGLES, 0, size * FlxCameraView.INDICES_PER_QUAD);

        FlxCameraView.totalDrawCalls++;
    }

    override function set(graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool) 
    {
        super.set(graphic, material, colored, hasColorOffsets);

        if (material.shader != null)
            shader = material.shader;
        else
            shader = textured ? defaultTexturedShader : defaultColoredShader;

        GLHelper.initShader(shader);
    }

    public inline function canAddQuad():Bool
    {
        return (numQuads + 1) <= size;
    }

    override function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform, material:FlxMaterial):Void
    {
        addUVQuad(frame.frame, frame.uv, matrix, transform, material);
    }

    override function addUVQuad(rect:FlxRect, uv:FlxUVRect, matrix:FlxMatrix, ?transform:ColorTransform, material:FlxMaterial):Void
    {
        var uvx:Float = uv.left;
		var uvy:Float = uv.top;
		var uvx2:Float = uv.right;
		var uvy2:Float = uv.bottom;

		var w:Float = rect.width;
		var h:Float = rect.height;

        var a:Float = matrix.a;
		var b:Float = matrix.b;
		var c:Float = matrix.c;
		var d:Float = matrix.d;
		var tx:Float = matrix.tx;
		var ty:Float = matrix.ty;

        var x1:Float;
        var y1:Float;
        var x2:Float;
        var y2:Float;
        var x3:Float;
        var y3:Float;
        var x4:Float;
        var y4:Float;

        // xy
        x1 = tx;
        y1 = ty;

        // xy
        x2 = w * a + tx;
        y2 = w * b + ty;

        // xy
        x3 = h * c + tx;
        y3 = h * d + ty;

        // xy
        x4 = w * a + h * c + tx;
        y4 = w * b + h * d + ty;

        var tint = 0xFFFFFF;
        var color = 0xFFFFFFFF;

		if (transform != null)
		{
            transform.color;
			tint = Std.int(transform.redMultiplier * 255) << 16 | Std.int(transform.greenMultiplier * 255) << 8 | Std.int(transform.blueMultiplier * 255);
			color = (Std.int(transform.alphaMultiplier * 255) & 0xFF) << 24 | tint;
		}

		tint = 0x000000;
		var colorOffset = 0x00000000;

		// update color offsets
		if (transform != null)
		{
			tint = Std.int(transform.redOffset) << 16 | Std.int(transform.greenOffset) << 8 | Std.int(transform.blueOffset);
			colorOffset = (Std.int(transform.alphaOffset) & 0xFF) << 24 | tint;
		}

		addVertex(x1, y1, uvx, uvy, color, colorOffset);
		addVertex(x2, y2, uvx2, uvy, color, colorOffset);
		addVertex(x3, y3, uvx, uvy2, color, colorOffset);
		addVertex(x4, y4, uvx2, uvy2, color, colorOffset);

        numQuads++;
    }

    function uploadData():Void
    {
        GL.useProgram(shader.glProgram);

        // update shader data
        if (dirty)
        {
            dirty = false;

            // enable position
            GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
            GL.vertexAttribPointer(shader.data.aPosition.index, 2, GL.FLOAT, false, 0, 0);
            GL.enableVertexAttribArray(shader.data.aPosition.index);

            if (textured)
            {
                GL.bindBuffer(GL.ARRAY_BUFFER, uvBuffer);
                GL.vertexAttribPointer(shader.data.aTexCoord.index, 2, GL.FLOAT, false, 0, 0);
                GL.enableVertexAttribArray(shader.data.aTexCoord.index);
            }

            // color attributes will be interpreted as unsigned bytes and normalized
            GL.bindBuffer(GL.ARRAY_BUFFER, colorBuffer);
            GL.vertexAttribPointer(shader.data.aColor.index, 4, GL.UNSIGNED_BYTE, true, 0, 0);
            GL.enableVertexAttribArray(shader.data.aColor.index);

            if (textured)
            {
                GL.vertexAttribPointer(shader.data.aColorOffset.index, 4, GL.UNSIGNED_BYTE, true, 0, 4); // offset by 4 bytes!
                GL.enableVertexAttribArray(shader.data.aColorOffset.index);
            }
        }

        // Upload the entire buffer
        if (numQuads > (size / 2))
		{
            // TODO ant: cache this? old branch had verticesNumBytes
            final verticesNumBytes = size * FlxCameraView.VERTICES_PER_QUAD * 2 * Float32Array.BYTES_PER_ELEMENT;
            GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
			GLInternal.bufferSubData(GL.ARRAY_BUFFER, 0, positions, null, verticesNumBytes);

            GL.bindBuffer(GL.ARRAY_BUFFER, uvBuffer);
			GLInternal.bufferSubData(GL.ARRAY_BUFFER, 0, uvs, null, verticesNumBytes);

            GL.bindBuffer(GL.ARRAY_BUFFER, colorBuffer);
			GLInternal.bufferSubData(GL.ARRAY_BUFFER, 0, colors, null, verticesNumBytes);
		}
		else
		{
            // If we're using less than half the buffer, upload only the used portion

			var viewLen:Int = numQuads * FlxCameraView.VERTICES_PER_QUAD * 2;
			var numBytes:Int = viewLen * Float32Array.BYTES_PER_ELEMENT;

            GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
			GLInternal.bufferSubData(GL.ARRAY_BUFFER, 0, positions.subarray(0, viewLen), null, numBytes);

            // uv and color are both 2 elements per quad!
            viewLen = numQuads * 2 * 2;
            numBytes = viewLen * Float32Array.BYTES_PER_ELEMENT;

            GL.bindBuffer(GL.ARRAY_BUFFER, uvBuffer);
            GLInternal.bufferSubData(GL.ARRAY_BUFFER, 0, uvs.subarray(0, viewLen), null, numBytes);

            GL.bindBuffer(GL.ARRAY_BUFFER, colorBuffer);
            GLInternal.bufferSubData(GL.ARRAY_BUFFER, 0, colors.subarray(0, viewLen), null, numBytes);
		}

		GLInternal.uniformMatrix4fv(shader.data.uMatrix.index, false, __temp__uMat);
    }

    function addVertex(x:Float = 0, y:Float = 0, u:Float = 0, v:Float = 0, color:FlxColor = FlxColor.WHITE, offset:FlxColor = FlxColor.TRANSPARENT)
    {
        positions[positionIndex++] = x;
        positions[positionIndex++] = y;
        uvs[uvIndex++] = u;
        uvs[uvIndex++] = v;
        colors[colorIndex++] = color;
        colors[colorIndex++] = offset;
    }
}
