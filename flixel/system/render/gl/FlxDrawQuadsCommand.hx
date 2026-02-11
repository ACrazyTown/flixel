package flixel.system.render.gl;

import flixel.graphics.FlxGraphic;
import flixel.graphics.FlxMaterial;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.shaders.FlxBaseShader;
import flixel.graphics.shaders.FlxShader;
// import flixel.graphics.shaders.quads.FlxTexturedShader;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.math.Matrix4;
import lime.utils.ArrayBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import lime.utils.UInt32Array;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Shader;
import openfl.geom.ColorTransform;

// TODO ant: Beeble's branch has roundPixels, used by the debug layer

class FlxDrawQuadsCommand extends FlxGLDrawCommand
{
    public static var defaultTexturedShader:FlxBaseShader;

    public static var defaultColoredShader:FlxBaseShader = new FlxShader();

    static inline final VERTICES_PER_QUAD:Int = 4;
    static inline final INDICES_PER_QUAD:Int = 6;

    /**
     * 2 bytes per index, since we're using a 16 bit index buffer.
     */
    static inline final BYTES_PER_INDEX:Int = 2;

    /**
     * The max elements per vertex allowed.
     */
    static inline final MAX_ELEMENTS_PER_VERTEX:Int = 6;

    /**
     * The amount of elements stored in each vertex. 
     * By default, all vertices should store the following, totaling to 5 elements:
     * - Position
     * - Texture coordinates
     * - Color
     * 
     * If multitexture batching is available, a sixth element is also required:
     * - Texture slot
     */
    var elementsPerVertex(get, never):Int;
    @:noCompletion inline function get_elementsPerVertex():Int
    {
        return 5 + (_multiTextureEnabled ? 1 : 0);
    }

    /**
     * The total number of quads this draw command can hold before flushing.
     */
    public var size(default, null):Int;

    public var numQuads:Int = 0;

    /**
	 * Holds the vertices data (_positions, uvs, _colors)
	 */
	var _vertices:ArrayBuffer;

	/**
	 * The total number of bytes in vertices buffer.
	 */
	var _verticesNumBytes:Int;

    var _vertexIndex:Int = 0;

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

    /**
     * Checks whether multitexturing is enabled (the current shader supports it)
     */
    var _multiTextureEnabled:Bool;

    /**
     * An array the length of `_multiTextureSlots`, that holds all of the textures in use by the current batch.
     */
    var _multiTextureArray:Array<GLTexture>;

    /**
     * The currently used texture slot.
     */
    var _multiTextureActiveSlot:Int = -1;

    /**
     * The total amount of texture slots in use by the current batch.
     * 
     * It is basically what `_multiTextureArray.length` should be, but `_multiTextureArray`
     * is always a fixed size, so the length is not accurate.
     */
    var _multiTextureSlots:Int = 0;

    var _states:Array<RenderState> = [];

    public function new(renderer:FlxGLRenderer, size:Int = 0)
    {
        super(renderer);
        type = QUADS;

        if (size <= 0)
            size = 2000; // QUADS_PER_BATCH
        this.size = size;

        _verticesNumBytes = size * Float32Array.BYTES_PER_ELEMENT * VERTICES_PER_QUAD * MAX_ELEMENTS_PER_VERTEX;
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
        GLHelper.bufferData(GL.ARRAY_BUFFER, _positions, GL.STREAM_DRAW, null, _verticesNumBytes);

        // initialize shader
        #if multitexture
        defaultTexturedShader = new FlxMultiTexturedShader();
        _multiTextureEnabled = true;
        #else
        defaultTexturedShader = new FlxTexturedShader();
        _multiTextureEnabled = false;
        #end

        shader = defaultTexturedShader;

        if (_multiTextureEnabled)
        {
            _multiTextureArray = [];
            for (i in 0...FlxMultiTexturedShader.maxTextures)
                _multiTextureArray.push(null);
        }

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

        _dirty = true;

        _vertexIndex = 0;
        numQuads = 0;

        if (_multiTextureEnabled)
        {
            _multiTextureActiveSlot = -1;
            _multiTextureSlots = 0;
            for (i in 0..._multiTextureArray.length)
                _multiTextureArray[i] = null;
        }
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

		setShader(currentMaterial);

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
            // ignore texture swaps when we can batch multiple textures
			textureSwap = (currentTexture != nextTexture) && !_multiTextureEnabled;

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

    function setShader(material:FlxMaterial):FlxBaseShader
    {
        var shader:FlxBaseShader = material.shader;

        if (shader == null)
            shader = textured ? defaultTexturedShader : defaultColoredShader;

        _multiTextureEnabled = shader is FlxMultiTexturedShader;

        context.setShader(shader);
        this.shader = shader;

        return shader;
    }

    function renderBatch(texture:BitmapData, size:Int, startIndex:Int, material:FlxMaterial):Void
	{
		if (size == 0)
			return;

        // TODO ant: uTextureSize will explode and die with multi texture... do we need it?
        if (_multiTextureEnabled && _multiTextureSlots > 1)
        {
            for (i in 0..._multiTextureSlots)
            {
                context.setTextureSlot(i);
                context.setGLTexture(_multiTextureArray[i], material.smoothing, material.getWrap());
                var index = GL.getUniformLocation(shader.glProgram, 'uImage$i');
                GL.uniform1i(index, i);
            }
        }
        else
        {
            if (texture != null)
            {
                context.setTextureSlot(0);
                context.setTexture(texture, material.smoothing, material.getWrap());
                GL.uniform1i(shader.data.uImage0.index, 0);
                GL.uniform2f(shader.data.uTextureSize.index, texture.width, texture.height);
            }
        }

		// now draw those suckas!
		GL.drawElements(GL.TRIANGLES, size * INDICES_PER_QUAD, GL.UNSIGNED_SHORT, startIndex * INDICES_PER_QUAD * BYTES_PER_INDEX);
        FlxRenderer.totalDrawCalls++;
	}

    function applyMaterial(material:FlxMaterial)
    {
        
    }

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
		addVertex(x1, y1, 0.0, 0.0, color, _multiTextureActiveSlot);
		addVertex(x2, y2, 0.0, 0.0, color, _multiTextureActiveSlot);
		addVertex(x3, y3, 0.0, 0.0, color, _multiTextureActiveSlot);
		addVertex(x4, y4, 0.0, 0.0, color, _multiTextureActiveSlot);
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

        var color:FlxColor = 0xFFFFFFFF;

        // todo: optimize???
        color.redFloat *= transform.redMultiplier;
        color.greenFloat *= transform.greenMultiplier;
        color.blueFloat *= transform.blueMultiplier;
        color.alphaFloat *= transform.alphaMultiplier;
        color.red += Std.int(transform.redOffset);
        color.green += Std.int(transform.greenOffset);
        color.blue += Std.int(transform.blueOffset);
        color.alpha += Std.int(transform.alphaOffset);

        startQuad(graphic, material);
		addVertex(x1, y1, uvx, uvy, color, _multiTextureActiveSlot);
		addVertex(x2, y2, uvx2, uvy, color, _multiTextureActiveSlot);
		addVertex(x3, y3, uvx, uvy2, color, _multiTextureActiveSlot);
		addVertex(x4, y4, uvx2, uvy2, color, _multiTextureActiveSlot);
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

            var stride:Int = Float32Array.BYTES_PER_ELEMENT * elementsPerVertex;
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

            if (_multiTextureEnabled && textured)
            {
                offset += 4;
                GL.vertexAttribPointer(shader.data.aTexSlot.index, 1, GL.FLOAT, false, stride, offset);
                GL.enableVertexAttribArray(shader.data.aTexSlot.index);
            }
        }

        // upload the verts to the buffer
		if (numQuads > 0.5 * size)
		{
			GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, _positions, null, _verticesNumBytes);
		}
		else
		{
			var viewLen:Int = numQuads * VERTICES_PER_QUAD * elementsPerVertex;
			var view = _positions.subarray(0, viewLen);

			var numBytes:Int = viewLen * Float32Array.BYTES_PER_ELEMENT;
			GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, view, null, numBytes);
		}

		GLHelper.uniformMatrix4fv(shader.data.uMatrix.index, false, renderer.projection);
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
        //var texture = graphic != null ? graphic.bitmap : null;
        var texture = graphic != null ? graphic.bitmap : FlxG.bitmap.whitePixel.parent.bitmap;
        
        if (!canAddQuad())
		{
			flush();
		}
		else if (numQuads > 0)
		{
            // TODO: 
            // it checks if both shaders are null (so that it can fallback to the default)
            // but it doesnt accunt for if the last draw was with a custom shader

			var sameMaterial:Bool = (this.material == material); // TODO ant: use material.equals()
			var bothNullShaders:Bool = (material.shader == null && shader == null);

            if (_multiTextureEnabled)
            {
                if (!(sameMaterial || bothNullShaders))
                    flush();
            }
            else
            {
                var sameTextured:Bool = (this.textured == (texture != null));

                if (!(sameMaterial || bothNullShaders) || !sameTextured)
                    flush();
            }
		}

        if (_multiTextureEnabled)
        {
            var glTexture = getGLTextureFromBitmap(texture);

            // check if we're already keeping this texture and use that slot
            var index = _multiTextureArray.indexOf(glTexture);
            if (index != -1)
            {
                _multiTextureActiveSlot = index;
            }
            else // not in our current pool, add it
            {
                // we're at the texture limit and have to flush
                if (_multiTextureSlots == FlxMultiTexturedShader.maxTextures)
                    flush();

                _multiTextureSlots++;

                _multiTextureActiveSlot = _multiTextureSlots - 1;
                _multiTextureArray[_multiTextureActiveSlot] = glTexture;
            }
        }

        // TODO ant -- commands should probably not use FlxGraphic
        // the graphic could be a different instance, but the underlying bitmap could be the same!!
		set(graphic, material, true, (texture != null));
		var state:RenderState = _states[numQuads];
		state.set(texture, material);
		numQuads++;
    }

    function addVertex(x:Float = 0, y:Float = 0, u:Float = 0, v:Float = 0, color:FlxColor = FlxColor.WHITE, textureSlot:Float):Void
    {
		_positions[_vertexIndex++] = x;
		_positions[_vertexIndex++] = y;
		_positions[_vertexIndex++] = u;
		_positions[_vertexIndex++] = v;

		_colors[_vertexIndex++] = color;

        if (_multiTextureEnabled)
            _positions[_vertexIndex++] = textureSlot;
    }

    inline function canAddQuad():Bool
    {
        return (numQuads + 1) <= size;
    }

    inline function getGLTextureFromBitmap(bitmap:BitmapData):GLTexture
    {
        @:privateAccess
        return bitmap.getTexture(FlxG.stage.context3D).__getTexture();
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
