package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.system.render.gl.FlxBatcher;
import flixel.system.render.gl.FlxDrawData;
import flixel.util.FlxColor;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.utils.ArrayBuffer;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import lime.utils.UInt16Array;
import openfl.display.Shader;

/**
 * The default quad batcher used internally.
 */
class FlxQuadBatcher extends FlxBatcher<FlxQuadDrawData>
{
    /**
     * The quad batcher uses 7 vertex attributes:
     * - X position
     * - Y position
     * - U texture mapping
     * - V texture mapping
     * - Color multiplier
     * - Color offset
     * - Texture slot (used only if multitexture batching is enabled)
     */
    public final ATTRIBUTES_PER_VERTEX:Int = 6; // TODO ant: TEMP, should be 7

    /**
     * The maximum amount of quads the batcher can hold before flushing.
     */
    public var maxQuads(default, null):Int;

    /**
     * The number of quads currently occupying the batch.
     */
    public var numQuads(default, null):Int = 0;

    /**
     * List of batched draw calls for the current buffer.
     */
    var _drawCalls:Array<DrawCall> = [];

    /**
     * Current index in the vertices array.
     */
    var _vertexIndex:Int = 0;

    /**
     * The size of the vertex buffer, in bytes.
     */
    var _verticesNumBytes:Int; 

    /**
     * The vertex buffer.
     */
    var _vertices:ArrayBuffer;

    /**
     * View on the vertices as a `Float32Array`
     */
    var _positions:Float32Array;

    /**
     * View on the vertices as a `Int32Array`
     */
    var _colors:Int32Array;

    /**
     * A reference to the OpenGL vertex buffer
     */
    var _glVertexBuffer:GLBuffer;

    /**
     * The index buffer.
     */
    var _indices:UInt16Array;

    /**
     * The amount of indices queued up to be drawn in the next flush.
     */
    var _count:Int = 0;

    /**
     * The current offset in the index buffer.
     */
    var _offset:Int = 0;

    /**
     * A reference to the OpenGL index buffer
     */
    var _glIndexBuffer:GLBuffer;

    public function new(maxQuads:Int = FlxGLRenderer.QUADS_PER_BATCH)
    {
        if (maxQuads <= 0 || maxQuads >= FlxGLRenderer.MAX_QUADS_PER_BUFFER)
            maxQuads = FlxGLRenderer.MAX_QUADS_PER_BUFFER;

        super(maxQuads * FlxGLRenderer.VERTICES_PER_QUAD, ATTRIBUTES_PER_VERTEX);
        this.maxQuads = maxQuads;

        initBuffers();
    }

    override function destroy():Void
    {
        super.destroy();

        _vertices = null;
        _positions = null;
        _colors = null;
        _indices = null;
        
        for (dc in _drawCalls)
            dc.put();
        _drawCalls = null;

        if (_glVertexBuffer != null)
            GL.deleteBuffer(_glVertexBuffer);

        if (_glIndexBuffer != null)
            GL.deleteBuffer(_glIndexBuffer);
    }

    public function add(data:FlxQuadDrawData):Void
    {
        // Flush buffer if we can't fit anymore
        if ((numQuads + 1) > maxQuads)
            flush();

        // Check if the sprite we're about to add requires a new draw call
        drawIfNeeded(data);

        // Prepare the vertices
        final rect = data.frame.frame;
        final uv = data.frame.uv;
        final transform = data.colorTransform;

        final scaledWX = rect.width * data.ma;
        final scaledWY = rect.width * data.mb;
        final scaledHX = rect.height * data.mc;
        final scaledHY = rect.height * data.md;

        // TODO ant: do i also need to add the rect position here
        final x1 = data.mtx;
        final y1 = data.mty;

        final x2 = scaledWX + data.mtx;
        final y2 = scaledWY + data.mty;

        final x3 = scaledHX + data.mtx;
        final y3 = scaledHY + data.mty;

        final x4 = scaledWX + scaledHX + data.mtx;
        final y4 = scaledWY + scaledHY + data.mty;

        final colorMult = FlxColor.fromRGBFloat(transform.redMultiplier, transform.greenMultiplier, transform.redMultiplier, transform.alphaMultiplier);
        final colorOffset = FlxColor.fromRGB(Std.int(transform.redOffset), Std.int(transform.greenOffset), Std.int(transform.blueOffset), Std.int(transform.alphaOffset));

        // Set up the render state
        _currentTexture = data.texture;
        _currentTextureRepeat = data.textureRepeat;
        _currentTextureSmoothing = data.textureSmoothing;
        _currentBlendMode = data.blend;
        _currentShader = resolveShader(data.shader);

        numQuads++;
        _count += FlxGLRenderer.INDICES_PER_QUAD;

        // Feed it all to the buffer
        addVertex(x1, y1, uv.left, uv.top, colorMult, colorOffset);
        addVertex(x2, y2, uv.right, uv.top, colorMult, colorOffset);
        addVertex(x3, y3, uv.left, uv.bottom, colorMult, colorOffset);
        addVertex(x4, y4, uv.right, uv.bottom, colorMult, colorOffset);
    }

    // Inlined cause we're calling it once!
    public function initShader(shader:Shader):Void
    {
        // Set matrix uniform
        GLHelper.uniformMatrix4fv(shader.data.uMatrix.index, false, _renderer.projection);

        final stride = attributesPerVertex * Float32Array.BYTES_PER_ELEMENT;
        var offset = 0;

        // Setup and enable position attribute
        GL.vertexAttribPointer(shader.data.aPosition.index, 2, GL.FLOAT, false, stride, offset);
        GL.enableVertexAttribArray(shader.data.aPosition.index);

        offset += 2 * 4;

        // Setup and enable tex coord attribute
        GL.vertexAttribPointer(shader.data.aTexCoord.index, 2, GL.FLOAT, false, stride, offset);
        GL.enableVertexAttribArray(shader.data.aTexCoord.index);

        offset += 2 * 4;

        // Color attributes will be interpreted as unsigned bytes and normalized
        // Setup and enable color multiplier attribute
        GL.vertexAttribPointer(shader.data.aColorMultiplier.index, 4, GL.UNSIGNED_BYTE, true, stride, offset);
        GL.enableVertexAttribArray(shader.data.aColorMultiplier.index);

        offset += 4;

        // Setup and enable color offset attribute
        GL.vertexAttribPointer(shader.data.aColorOffset.index, 4, GL.UNSIGNED_BYTE, true, stride, offset);
        GL.enableVertexAttribArray(shader.data.aColorOffset.index);
    }

    public function flush():Void
    {
        // queue up whatever was left
        if (_count > 0)
        {
            final dc = DrawCall.get(_count, _offset, _currentShader, _currentBlendMode, _currentTexture, _currentTextureRepeat, _currentTextureSmoothing);
            _drawCalls.push(dc);
        }

        uploadBuffers();
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, _glIndexBuffer);

        for (dc in _drawCalls)
            draw(dc);

        _drawCalls.resize(0);
        _count = 0;
        _offset = 0;

        numQuads = 0;
        _vertexIndex = 0;
    }

    function drawIfNeeded(next:FlxQuadDrawData):Void
    {
        // Skip if this is the first quad being drawn because everything we're about to check is null
        if (numQuads == 0)
            return;

        // As it is right now, it's only safe to batch shaders if the
        // instance is the exact same, as uniforms are linked to the instance
        var sameShader = _currentShader == resolveShader(next.shader);
        var sameBlendMode = _currentBlendMode == next.blend;

        var sameTextureRepeat = _currentTextureRepeat == next.textureRepeat;
        var sameTextureSmoothing = _currentTextureSmoothing == next.textureSmoothing;
        var sameTexture = (_currentTexture == next.texture) && sameTextureRepeat && sameTextureSmoothing;

        if (!(sameShader && sameBlendMode && sameTexture))
        {
            final dc = DrawCall.get(_count, _offset, _currentShader, _currentBlendMode, _currentTexture, _currentTextureRepeat, _currentTextureSmoothing);
            _drawCalls.push(dc);

            _offset += _count * UInt16Array.BYTES_PER_ELEMENT;
            _count = 0;
        }
    }

    // Inlined cause we're calling it once!
    inline function initBuffers():Void
    {
        // Construct the vertex buffers
        _verticesNumBytes = size * Float32Array.BYTES_PER_ELEMENT * attributesPerVertex;
        _vertices = new ArrayBuffer(_verticesNumBytes);

        _positions = new Float32Array(_vertices);
        _colors = new Int32Array(_vertices);

        // Allocate the vertex buffer on the GPU
        _glVertexBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, _glVertexBuffer);
        GLHelper.bufferData(GL.ARRAY_BUFFER, _positions, GL.STREAM_DRAW);

        // Construct the index buffers
        final numIndices = maxQuads * FlxGLRenderer.INDICES_PER_QUAD;
        _indices = new UInt16Array(numIndices);

        // We don't need to ever modify the indices in a quad batch so we'll
        // just preallocate and upload them to the GPU immediately
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

			indexPos += FlxGLRenderer.INDICES_PER_QUAD;
			index += FlxGLRenderer.VERTICES_PER_QUAD;
		}

        // Allocate the index buffer on the GPU
        _glIndexBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, _glIndexBuffer);
        GLHelper.bufferData(GL.ELEMENT_ARRAY_BUFFER, _indices, GL.STATIC_DRAW);
    }

    // Inlined cause we're calling it once!
    inline function uploadBuffers():Void
    {
        // TODO: upload portion of vertex buffer?
        GL.bindBuffer(GL.ARRAY_BUFFER, _glVertexBuffer);
        GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, _positions);
    }

    inline function addVertex(x:Float, y:Float, u:Float, v:Float, colorMult:FlxColor, colorOffset:FlxColor, textureSlot:Int = -1):Void
    {
        _positions[_vertexIndex++] = x;
        _positions[_vertexIndex++] = y;
        _positions[_vertexIndex++] = u;
        _positions[_vertexIndex++] = v;
        _colors[_vertexIndex++] = colorMult;
        _colors[_vertexIndex++] = colorOffset;
        // _positions[_vertexIndex++] = textureSlot; // TODO ant : TEMP
    }

    inline function resolveShader(shader:Shader):Shader
    {
        return shader == null ? FlxGLRenderer.defaultShader : shader;
    }
}
#end
