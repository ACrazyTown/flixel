package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.system.render.FlxTopology;
import flixel.system.render.gl.FlxDrawCall;
import flixel.system.render.gl.FlxDrawData;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxPool;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import lime.utils.ArrayBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import lime.utils.Int32Array;
import openfl.display.BlendMode;
import openfl.display.Shader;
import flixel.util.FlxColor;

/**
 * Takes in `FlxDrawData` and figures out the most efficient way to draw it.
 */
class FlxBatcher implements IFlxDestroyable
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

    // public var attributes:Array<GLAttribute>;

    public var maxVertices:Int;
    public var maxIndices:Int;

    /**
     * The number of attributes per vertex.
     */
    public var attributesPerVertex:Int;

    var _numVertices:Int = 0;
    var _numIndices:Int = 0;

    // Draw state
	var _currentTopology:FlxTopology;
    var _currentShader:Shader;
    var _currentBlendMode:BlendMode;
    var _currentTexture:FlxGraphic; // TODO ant: replace these 3 with FlxTexture
    var _currentTextureRepeat:Bool;
    var _currentTextureSmoothing:Bool;

    // Draw call data
    var _count:Int = 0;
    var _offset:Int = 0;
    var _drawCalls:Array<BatchDrawCall> = [];

    // Vertex buffer data
    var _vertexIndex:Int = 0;
    var _verticesNumBytes:Int; 
    var _vertices:ArrayBuffer;
    var _positions:Float32Array;
    var _colors:Int32Array;
    var _glVertexBuffer:GLBuffer;

    // Index buffer data
    var _indicesIndex:Int = 0;
    var _indices:UInt16Array;
    var _glIndexBuffer:GLBuffer;

    var _renderer(get, never):FlxGLRenderer;
	inline function get__renderer() return cast (FlxG.renderer, FlxGLRenderer);

    public function new(maxVertices:Int, maxIndices:Int, attributesPerVertex:Int)
    {
        this.maxVertices = maxVertices;
        this.maxIndices = maxIndices;

        this.attributesPerVertex = attributesPerVertex;

        initBuffers();

        // final stride = attributesPerVertex * Float32Array.BYTES_PER_ELEMENT;
        // attributes = [
        //     {
        //         buffer: _glVertexBuffer,
        //         name: "aPosition",
        //         size: 2,
        //         type: GL.FLOAT,
        //         normalized: false,
        //         stride: stride,
        //         offset: 0
        //     },
        //     {
        //         buffer: _glVertexBuffer,
        //         name: "aTexCoord",
        //         size: 2,
        //         type: GL.FLOAT,
        //         normalized: false,
        //         stride: stride,
        //         offset: 8, // 2 * 4
        //     },
        //     {
        //         buffer: _glVertexBuffer,
        //         name: "aColorMultiplier",
        //         size: 4,
        //         type: GL.UNSIGNED_BYTE,
        //         normalized: true,
        //         stride: stride,
        //         offset: 16 // prev + 2 * 4
        //     },
        //     {
        //         buffer: _glVertexBuffer,
        //         name: "aColorOffset",
        //         size: 4,
        //         type: GL.UNSIGNED_BYTE,
        //         normalized: true,
        //         stride: stride,
        //         offset: 20 // prev + 4
        //     }
        // ];
    }

    public function destroy():Void
    {
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

    public inline function add(data:FlxDrawData):Void
    {
        if (data.type == QUAD)
        {
            final quad:FlxQuadDrawData = cast data;
            addQuad(quad);
            quad.put();
        }
        else if (data.type == TRIANGLES)
        {
            final triangles:FlxTrianglesDrawData = cast data;
            addTriangles(triangles);
            triangles.put();
        }
    }

    public function addQuad(data:FlxQuadDrawData):Void
    {
        // Flush buffer if we can't fit anymore
        if (_numVertices + FlxGLRenderer.VERTICES_PER_QUAD > maxVertices
            || _numIndices + FlxGLRenderer.INDICES_PER_QUAD > maxIndices)
            flush();

        // Check if the sprite we're about to add requires a new draw call
        drawIfNeeded(data);

        // Prepare the vertices
        final scaledWX = data.frame.frame.width * data.matrix.a;
        final scaledWY = data.frame.frame.width * data.matrix.b;
        final scaledHX = data.frame.frame.height * data.matrix.c;
        final scaledHY = data.frame.frame.height * data.matrix.d;

        // TODO ant: do i also need to add the rect position here
        final x1 = data.matrix.tx;
        final y1 = data.matrix.ty;

        final x2 = scaledWX + data.matrix.tx;
        final y2 = scaledWY + data.matrix.ty;

        final x3 = scaledHX + data.matrix.tx;
        final y3 = scaledHY + data.matrix.ty;

        final x4 = scaledWX + scaledHX + data.matrix.tx;
        final y4 = scaledWY + scaledHY + data.matrix.ty;

        // Feed it all to the buffer
        addVertex(x1, y1, data.frame.uv.left, data.frame.uv.top, data.colorMultiplier, data.colorOffset);
        addVertex(x2, y2, data.frame.uv.right, data.frame.uv.top, data.colorMultiplier, data.colorOffset);
        addVertex(x3, y3, data.frame.uv.left, data.frame.uv.bottom, data.colorMultiplier, data.colorOffset);
        addVertex(x4, y4, data.frame.uv.right, data.frame.uv.bottom, data.colorMultiplier, data.colorOffset);

        _indices[_indicesIndex++] = _numVertices + 0; 
        _indices[_indicesIndex++] = _numVertices + 1;
        _indices[_indicesIndex++] = _numVertices + 2;
        _indices[_indicesIndex++] = _numVertices + 1;
        _indices[_indicesIndex++] = _numVertices + 2;
        _indices[_indicesIndex++] = _numVertices + 3;

        // Set up the render state
		_currentTopology = TRIANGLE_LIST;
        _currentTexture = data.texture;
        _currentTextureRepeat = data.textureRepeat;
        _currentTextureSmoothing = data.textureSmoothing;
        _currentBlendMode = data.blend;
        _currentShader = resolveShader(data.shader);

        _numVertices += FlxGLRenderer.VERTICES_PER_QUAD;
        _numIndices += FlxGLRenderer.INDICES_PER_QUAD;

        _count += FlxGLRenderer.INDICES_PER_QUAD;

    }

    public function addTriangles(data:FlxTrianglesDrawData):Void
    {
        // Check if the sprite we're about to add requires a new draw call
        drawIfNeeded(data);

        // Flush buffer if we can't fit anymore
        if (_numVertices + data.vertices.length > maxVertices
            || _numIndices + data.indices.length > maxIndices)
            flush();

        // Update vertices
        for (i in 0...data.vertices.length)
        {
            final x = data.vertices.getX(i);
            final y = data.vertices.getY(i);
            final u = data.uvs.getX(i);
            final v = data.uvs.getY(i);

            // Multiply the color with the color transform multiplier,
            // because we can't pass in 3 colors
            var color:FlxColor = FlxColor.WHITE;
            if (data.colors != null && i < data.colors.length) // TODO: ensure colors are always present, even if not used (FlxTrianglesData)
                color = data.colors[i];
            color *= data.colorMultiplier;

            final transformedX = data.matrix.transformX(x, y);
            final transformedY = data.matrix.transformY(x, y);
            addVertex(transformedX, transformedY, u, v, color, data.colorOffset);
        }

        // Update indices
        for (i in 0...data.indices.length)
        {
            _indices[_indicesIndex++] = _numVertices + data.indices[i];
        }

        // Set up the render state
		_currentTopology = TRIANGLE_LIST;
        _currentTexture = data.texture;
        _currentTextureRepeat = data.textureRepeat;
        _currentTextureSmoothing = data.textureSmoothing;
        _currentBlendMode = data.blend;
        _currentShader = resolveShader(data.shader);

        _numVertices += data.vertices.length;
        _numIndices += data.indices.length;
        _count += data.indices.length;
    }

    /**
     * Flush the contents of the buffer and draw all the stored batches.
     */
    public function flush():Void
    {
        // queue up whatever was left
        if (_count > 0)
        {
			final dc = BatchDrawCall.get(this, _count, _offset, _currentTopology, _currentShader, _currentBlendMode, _currentTexture, _currentTextureRepeat,
				_currentTextureSmoothing);
            _drawCalls.push(dc);
        }

        uploadBuffers();

        for (dc in _drawCalls)
            _renderer.draw(dc);

        _drawCalls.resize(0);
        _count = 0;
        _offset = 0;

        _numVertices = 0;
        _numIndices = 0;
        _vertexIndex = 0;
        _indicesIndex = 0;
    }

    /**
     * Called during a draw call, when the active shader changes.
     */
    public function initShader(shader:Shader):Void
    {
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

    function drawIfNeeded(next:FlxDrawData):Void
    {
        // Skip if this is the first sprite being drawn because everything we're about to check is null
        if (_numVertices == 0)
            return;

        // As it is right now, it's only safe to batch shaders if the
        // instance is the exact same, as uniforms are linked to the instance
        var sameShader = _currentShader == resolveShader(next.shader);
        var sameBlendMode = _currentBlendMode == next.blend;

        var sameTextureRepeat = _currentTextureRepeat == next.textureRepeat;
        var sameTextureSmoothing = _currentTextureSmoothing == next.textureSmoothing;
        var sameTexture = (_currentTexture == next.texture) && sameTextureRepeat && sameTextureSmoothing;

		var sameTopology = _currentTopology == next.topology;
		
		if (!(sameShader && sameBlendMode && sameTexture && sameTopology) && true)
        {
			final dc = BatchDrawCall.get(this, _count, _offset, _currentTopology, _currentShader, _currentBlendMode, _currentTexture, _currentTextureRepeat,
				_currentTextureSmoothing);
            _drawCalls.push(dc);

            _offset += _count * UInt16Array.BYTES_PER_ELEMENT;
            _count = 0;
        }
    }

    // Inlined cause we're calling it once!
    inline function initBuffers():Void
    {
        // Construct the vertex buffers
        _verticesNumBytes = maxVertices * Float32Array.BYTES_PER_ELEMENT * attributesPerVertex;
        _vertices = new ArrayBuffer(_verticesNumBytes);

        _positions = new Float32Array(_vertices);
        _colors = new Int32Array(_vertices);

        // Allocate the vertex buffer on the GPU
        _glVertexBuffer = GL.createBuffer();
        _renderer.context.bindGLVertexBuffer(_glVertexBuffer);
        GLHelper.bufferData(GL.ARRAY_BUFFER, _positions, GL.STREAM_DRAW);

        // Construct the index buffer;
        _indices = new UInt16Array(maxIndices);

        // Allocate the index buffer on the GPU
        _glIndexBuffer = GL.createBuffer();
        _renderer.context.bindGLIndexBuffer(_glIndexBuffer);
        GLHelper.bufferData(GL.ELEMENT_ARRAY_BUFFER, _indices, GL.STREAM_DRAW);
    }

    // Inlined cause we're calling it once!
    inline function uploadBuffers():Void
    {
        // TODO: upload portion of buffer?
        _renderer.context.bindGLVertexBuffer(_glVertexBuffer);

        if (_numVertices == maxVertices)
        {
            // "orphan" (reallocate) the entire buffer to prevent stalls
            GLHelper.bufferData(GL.ARRAY_BUFFER, _positions, GL.STREAM_DRAW);
        }
        else
        {
            var portion = _positions.subarray(0, _numVertices * attributesPerVertex);
            GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, portion);
        }
        
        _renderer.context.bindGLIndexBuffer(_glIndexBuffer);

        if (_numIndices == maxIndices)
        {
            // "orphan" (reallocate) the entire buffer to prevent stalls
            GLHelper.bufferData(GL.ELEMENT_ARRAY_BUFFER, _indices, GL.STREAM_DRAW);
        }
        else
        {
            var portion = _indices.subarray(0, _numIndices);
            GLHelper.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, 0, portion);
        }
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

@:access(flixel.system.render.gl.FlxBatcher)
@:forward
abstract BatchDrawCall(FlxDrawCall) from FlxDrawCall to FlxDrawCall
{
	public static inline function get(batcher:FlxBatcher, count:Int, offset:Int, topology:FlxTopology, shader:Shader, blend:BlendMode,
			texture:FlxGraphic,
			textureRepeat:Bool, textureSmoothing:Bool):BatchDrawCall
	{
		return FlxDrawCall.get()
			.init(batcher._glIndexBuffer, count, offset)
			.setState(topology, shader, blend, texture, textureRepeat, textureSmoothing);
	}
}
#end
