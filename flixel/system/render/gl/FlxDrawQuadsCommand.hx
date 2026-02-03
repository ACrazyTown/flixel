package flixel.system.render.gl;

import lime.utils.UInt32Array;
import lime.utils.ArrayBuffer;
import openfl.display.BlendMode;
import flixel.util.FlxDestroyUtil;
import openfl.display.BitmapData;
import lime.graphics.opengl.GLShader;
import lime.graphics.opengl.GLProgram;
// import flixel.graphics.shaders.quads.FlxTexturedShader;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.graphics.FlxMaterial;
import lime.math.Matrix4;
import flixel.util.FlxColor;
import flixel.graphics.shaders.FlxShader;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLUniformLocation;
import lime.utils.UInt16Array;
import lime.utils.Float32Array;

// TODO ant: Beeble's branch has roundPixels, used by the debug layer
// TODO ant: fix _colors & color offset
// TODO ant: use uModel

class FlxDrawQuadsCommand extends FlxGLDrawCommand
{
    public static var defaultTexturedShader:FlxShader = new FlxTexturedShader();

    public static var defaultColoredShader:FlxShader = new FlxColoredShader();

    static inline final VERTICES_PER_QUAD:Int = 4;
    static inline final INDICES_PER_QUAD:Int = 6;

    /**
     * 2 bytes per index, since we're using a 16 bit index buffer.
     */
    static inline final BYTES_PER_INDEX:Int = 2;

    /**
     * Each vertex stores the (x, y) position, (u, v) texture coordinates, the color and color offset,
     * totaling to 6 elements per vertex.
     */
    static inline final ELEMENTS_PER_VERTEX:Int = 6;

    /**
     * The number of quads this command can hold.
     */
    public var size(default, null):Int;

    /**
     * Shortcut for `material.shader`.
     * If `material.shader` is null, the default shader will be used instead.
     */
    // public var shader:FlxShader;

    public var numQuads:Int = 0;

    var _vertexIndex:Int = 0;

    /**
	 * Holds the vertices data (_positions, uvs, _colors)
	 */
	var _vertices:ArrayBuffer;

	/**
	 * The total number of bytes in vertices buffer.
	 */
	var _verticesNumBytes:Int;

	/**
	 * View on the vertices as a Float32Array
	 */
	var _positions:Float32Array;

	/**
	 * View on the vertices as a UInt32Array
	 */
	var _colors:UInt32Array;

	var _vertexBuffer:GLBuffer;

    /**
	 * Holds the indices
	 */
	var _indices:UInt16Array;

	var _indexBuffer:GLBuffer;

    /**
     * Internal flag to check whether data needs to be reuploaded to the GPU.
     */
    var _dirty:Bool = false;

    var _states:Array<RenderState> = [];

    public function new(renderer:FlxGLRenderer, size:Int = 0)
    {
        super(renderer);
        type = QUADS;

        if (size <= 0)
            size = 2000; // QUADS_PER_BATCH
        this.size = size;

        _verticesNumBytes = size * Float32Array.BYTES_PER_ELEMENT * VERTICES_PER_QUAD * ELEMENTS_PER_VERTEX;
        _vertices = new ArrayBuffer(_verticesNumBytes);
		_positions = new Float32Array(_vertices);
		_colors = new UInt32Array(_vertices);

        final numIndices:Int = size * INDICES_PER_QUAD;
        _indices = new UInt16Array(numIndices); // TODO ant -- use 32bit indices instead?

        var indexPos:Int = 0;
		var index:Int = 0;

		while (indexPos < numIndices)
		{
			_indices[indexPos + 0] = index + 0;
			_indices[indexPos + 1] = index + 1;
			_indices[indexPos + 2] = index + 2;
			_indices[indexPos + 3] = index + 1;
			_indices[indexPos + 4] = index + 3;
			_indices[indexPos + 5] = index + 2;

			indexPos += INDICES_PER_QUAD;
			index += VERTICES_PER_QUAD;
		}

        // create GL buffers and upload them to the GPU
        _indexBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, _indexBuffer);

        var indicesNumBytes:Int = size * INDICES_PER_QUAD * UInt16Array.BYTES_PER_ELEMENT;
        GLHelper.bufferData(GL.ELEMENT_ARRAY_BUFFER, _indices, GL.STATIC_DRAW, null, indicesNumBytes);

        _vertexBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, _vertexBuffer);
        GLHelper.bufferData(GL.ARRAY_BUFFER, _positions, GL.DYNAMIC_DRAW, null, _verticesNumBytes);

        for (i in 0...size)
            _states[i] = new RenderState();
    }

    override function destroy():Void
    {
        super.destroy();

        // shader = null;

        GL.deleteBuffer(_vertexBuffer);
        GL.deleteBuffer(_indexBuffer);

        _positions = null;
        _colors = null;
        _indices = null;

        for (state in _states)
            state.destroy();

        _states = null;
    }

    override function reset():Void
    {
        super.reset();

        // shader = null;

        _dirty = true;

        _vertexIndex = 0;
        numQuads = 0;
    }

    // TODO ant: apply camera.antialiasing
    override function flush():Void
    {
        if (numQuads == 0)
			return;

		// context.checkRenderTarget(buffer);

        var batchSize:Int = 0;
		var startIndex:Int = 0;

		var state:RenderState = _states[0];
		var currentMaterial:FlxMaterial = state.material;
		var nextMaterial:FlxMaterial;

		setShader(material);
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, _indexBuffer);
		uploadData();

		//currentMaterial.apply(cast gl);
        applyMaterial(currentMaterial);

		var currentTexture = state.texture;
		var nextTexture = currentTexture;

		var currentBlendMode:BlendMode = currentMaterial.blendMode;
		var nextBlendMode:BlendMode = currentBlendMode;
		context.setBlendMode(currentBlendMode);

		var currentSmoothing:Bool = currentMaterial.smoothing;
		var nextSmoothing:Bool = currentSmoothing;

		if (numQuads == 1)
		{
			renderBatch(currentTexture, 1, 0, currentMaterial);
			reset();
			return;
		}

		var blendSwap:Bool = false;
		var textureSwap:Bool = false;
		var smoothingSwap:Bool = false;

		for (i in 0...numQuads)
		{
			state = _states[i];
			nextMaterial = state.material;

			nextTexture = state.texture;
			nextBlendMode = nextMaterial.blendMode;
			nextSmoothing = nextMaterial.smoothing;

			blendSwap = (currentBlendMode != nextBlendMode);
			textureSwap = (currentTexture != nextTexture);
			smoothingSwap = (currentSmoothing != nextSmoothing);

			if (textureSwap || blendSwap || smoothingSwap)
			{
				renderBatch(currentTexture, batchSize, startIndex, currentMaterial);

				startIndex = i;
				batchSize = 0;
				currentTexture = nextTexture;
				currentSmoothing = nextSmoothing;

				if (blendSwap)
				{
					currentBlendMode = nextBlendMode;
					context.setBlendMode(currentBlendMode);
				}
			}

			currentMaterial = nextMaterial;
			batchSize++;
		}

		renderBatch(currentTexture, batchSize, startIndex, currentMaterial);

		// then reset the batch!
		reset();
    }

    function setShader(material:FlxMaterial):FlxShader
    {
        var shader = material.shader;

        if (shader == null)
            shader = textured ? defaultTexturedShader : defaultColoredShader;

        // GLHelper.useShader(shader);
        context.setShader(shader);
        this.shader = shader;

        return shader;
    }

    function renderBatch(texture:BitmapData, size:Int, startIndex:Int, material:FlxMaterial):Void
	{
		if (size == 0)
			return;

        if (texture != null)
        {
            context.setTexture(texture, material.smoothing, material.getWrap());
            GL.uniform1i(shader.data.uImage0.index, 0);
            GL.uniform2f(shader.data.uTextureSize.index, texture.width, texture.height);
        }

		// now draw those suckas!
		GL.drawElements(GL.TRIANGLES, size * INDICES_PER_QUAD, GL.UNSIGNED_SHORT, startIndex * INDICES_PER_QUAD * BYTES_PER_INDEX);

        FlxRenderer.totalDrawCalls++;
	}

    function applyMaterial(material:FlxMaterial)
    {
        
    }

    // override function set(graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool) 
    // {
    //     super.set(graphic, material, colored, hasColorOffsets);

    //     if (material.shader != null)
    //         shader = material.shader;
    //     else
    //         shader = textured ? defaultTexturedShader : defaultColoredShader;

    //     GLHelper.initShader(shader);
    // }

    override inline function addQuad(frame:FlxFrame, material:FlxMaterial, matrix:FlxMatrix, ?transform:ColorTransform):Void
    {
        addUVQuad(frame.parent, material, frame.frame, frame.uv, matrix, transform);
    }

    public function addColorQuad(rect:FlxRect, material:FlxMaterial, matrix:FlxMatrix, color:FlxColor):Void
    {
        var x1 = matrix.tx;
        var y1 = matrix.ty;

        var x2 = rect.width * matrix.a + matrix.tx;
        var y2 = rect.width * matrix.b + matrix.ty;

        var x3 = rect.height * matrix.c + matrix.tx;
        var y3 = rect.height * matrix.d + matrix.ty;

        var x4 = rect.width * matrix.a + rect.height * matrix.c + matrix.tx;
        var y4 = rect.width * matrix.b + rect.height * matrix.d + matrix.ty;

		startQuad(null, material);
		addVertex(x1, y1, 0.0, 0.0, color);
		addVertex(x2, y2, 0.0, 0.0, color);
		addVertex(x3, y3, 0.0, 0.0, color);
		addVertex(x4, y4, 0.0, 0.0, color);
    }

    override function addUVQuad(graphic:FlxGraphic, material:FlxMaterial, rect:FlxRect, uv:FlxUVRect, matrix:FlxMatrix, ?transform:ColorTransform):Void
    {
        var uvx:Float = uv.left;
		var uvy:Float = uv.top;
		var uvx2:Float = uv.right;
		var uvy2:Float = uv.bottom;

        var scaledWX = rect.width * matrix.a;
        var scaledWY = rect.width * matrix.b;
        var scaledHX = rect.height * matrix.c;
        var scaledHY = rect.height * matrix.d;

        var x1 = matrix.tx;
        var y1 = matrix.ty;

        var x2 = scaledWX + matrix.tx;
        var y2 = scaledWY + matrix.ty;

        var x3 = scaledHX + matrix.tx;
        var y3 = scaledHY + matrix.ty;

        var x4 = scaledWX + scaledHX + matrix.tx;
        var y4 = scaledWY + scaledHY + matrix.ty;

        var tint = 0xFFFFFF;
        var color = 0xFFFFFFFF;

		if (transform != null)
		{
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

        startQuad(graphic, material);
		addVertex(x1, y1, uvx, uvy, color, colorOffset);
		addVertex(x2, y2, uvx2, uvy, color, colorOffset);
		addVertex(x3, y3, uvx, uvy2, color, colorOffset);
		addVertex(x4, y4, uvx2, uvy2, color, colorOffset);
    }

    /**
     * Uploads the buffers to the GPU.
     */
    function uploadData():Void
    {
        // update shader data
        if (_dirty)
        {
            _dirty = false;

            GL.bindBuffer(GL.ARRAY_BUFFER, _vertexBuffer);

            var stride:Int = Float32Array.BYTES_PER_ELEMENT * ELEMENTS_PER_VERTEX;
			var offset:Int = 0;

            // enable position
            GL.vertexAttribPointer(shader.data.aPosition.index, 2, GL.FLOAT, false, stride, offset);
            GL.enableVertexAttribArray(shader.data.aPosition.index);
            offset += 2 * 4;

            if (textured)
            {
                GL.vertexAttribPointer(shader.data.aTexCoord.index, 2, GL.FLOAT, false, stride, offset);
                GL.enableVertexAttribArray(shader.data.aTexCoord.index);
            }

            offset += 2 * 4;

            // color attributes will be interpreted as unsigned bytes and normalized
            GL.vertexAttribPointer(shader.data.aColor.index, 4, GL.UNSIGNED_BYTE, true, stride, offset);
            GL.enableVertexAttribArray(shader.data.aColor.index);
            offset += 4;

            if (textured)
            {
                GL.vertexAttribPointer(shader.data.aColorOffset.index, 4, GL.UNSIGNED_BYTE, true, stride, offset); // offset by 4 bytes!
                GL.enableVertexAttribArray(shader.data.aColorOffset.index);
            }
        }

        // upload the verts to the buffer
		if (numQuads > 0.5 * size)
		{
			GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, _positions, null, _verticesNumBytes);
		}
		else
		{
			var viewLen:Int = numQuads * VERTICES_PER_QUAD * ELEMENTS_PER_VERTEX;
			var view = _positions.subarray(0, viewLen);

			var numBytes:Int = viewLen * Float32Array.BYTES_PER_ELEMENT;
			GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, view, null, numBytes);
		}

		GLHelper.uniformMatrix4fv(shader.data.uProjection.index, false, __temp__uMat);
        GLHelper.uniformMatrix4fv(shader.data.uModel.index, false, _matrix4);
    }

    /**
     * Starts a quad batch.
     * 
     * If the previous render state is the same, the previous batch is reused.
     * If the command cannot fit a new quad, the previous data is flushed.
     * 
     * @param texture 
     * @param material 
     */
    function startQuad(graphic:FlxGraphic, material:FlxMaterial):Void
    {
        var texture = graphic != null ? graphic.bitmap : null;

        if (!canAddQuad())
		{
			flush();
		}
		else if (numQuads > 0)
		{
			var sameMaterial:Bool = (this.material == material); // TODO ant: use material.equals()
			var bothNullShaders:Bool = (material.shader == null && shader == null);
			var sameTextured:Bool = (this.textured == (texture != null));

            // trace(this.material, material);
            // trace(material.shader, shader);
            // trace(this.textured, texture != null);

            // trace("---");

            // trace(sameMaterial, bothNullShaders, sameTextured);
            // trace(!(sameMaterial || bothNullShaders), !sameTextured);

			if (!(sameMaterial || bothNullShaders) || !sameTextured)
			{
				flush();
			}
		}

        // TODO ant -- commands should probably not use FlxGraphic
        // the graphic could be a different instance, but the underlying bitmap could be the same!!
		set(graphic, material, true, (texture != null));
		var state:RenderState = _states[numQuads];
		state.set(texture, material);
		numQuads++;
    }

    function addVertex(x:Float = 0, y:Float = 0, u:Float = 0, v:Float = 0, color:FlxColor = FlxColor.WHITE, offset:FlxColor = FlxColor.TRANSPARENT)
    {
		_positions[_vertexIndex++] = x;
		_positions[_vertexIndex++] = y;
		_positions[_vertexIndex++] = u;
		_positions[_vertexIndex++] = v;
		_colors[_vertexIndex++] = color;
		_colors[_vertexIndex++] = offset;
    }

    public inline function canAddQuad():Bool
    {
        return (numQuads + 1) <= size;
    }
}

private class RenderState implements IFlxDestroyable
{
	public var texture(default, null):BitmapData;
	public var material(default, null):FlxMaterial;

	public function new() {}

	public inline function set(texture:BitmapData, material:FlxMaterial):Void
	{
		this.texture = texture;
		this.material = material;
	}

	public function destroy():Void
	{
		this.texture = null;
		this.material = null;
	}
}
