package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import haxe.ds.Vector;
import flixel.system.render.FlxTopology;
import flixel.system.render.gl.FlxDrawCall;
import flixel.system.render.gl.FlxDrawData;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.utils.ArrayBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import lime.utils.Int32Array;
import openfl.display.BlendMode;
import flixel.graphics.shaders.FlxShader;
import flixel.graphics.shaders.FlxBatcherShader;
import flixel.graphics.textures.FlxTexture;
import flixel.util.FlxColor;

/**
 * Takes in `FlxDrawData` and figures out the most efficient way to draw it.
 */
class FlxBatcher implements IFlxDestroyable
{
    public var maxVertices:Int;
    public var maxIndices:Int;

    /**
     * The number of attributes per vertex.
     */
    public var attributesPerVertex:Int;

    var _numVertices:Int = 0;
    var _numIndices:Int = 0;

    // Render state
	var _currentTopology:FlxTopology;
    var _currentShader:FlxShader;
    var _currentBlendMode:BlendMode;

    // Texture state
    var _canBatchTextures:Bool = #if FLX_OPENGL_BATCH_TEXTURES true #else false #end;    
    var _textures:Vector<FlxTexture>;
    var _texturesSmoothing:Vector<Bool>;
    var _currentTextureSlot:Int = -1;
    var _numTextureSlots:Int = 0;

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

        final maxTextures = #if FLX_OPENGL_BATCH_TEXTURES FlxBatcherShader.maxTextures #else 1 #end;
        _textures = new Vector<FlxTexture>(maxTextures);
        _texturesSmoothing = new Vector<Bool>(maxTextures);

        initBuffers();
    }

    public function destroy():Void
    {
        _vertices = null;
        _positions = null;
        _colors = null;
        _indices = null;

        _textures = null;
        _texturesSmoothing = null;
        
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
        updateRenderState(data);

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
        addVertex(x1, y1, data.frame.uv.left, data.frame.uv.top, data.colorMultiplier, data.colorOffset, _currentTextureSlot);
        addVertex(x2, y2, data.frame.uv.right, data.frame.uv.top, data.colorMultiplier, data.colorOffset, _currentTextureSlot);
        addVertex(x3, y3, data.frame.uv.left, data.frame.uv.bottom, data.colorMultiplier, data.colorOffset, _currentTextureSlot);
        addVertex(x4, y4, data.frame.uv.right, data.frame.uv.bottom, data.colorMultiplier, data.colorOffset, _currentTextureSlot);

        _indices[_indicesIndex++] = _numVertices + 0; 
        _indices[_indicesIndex++] = _numVertices + 1;
        _indices[_indicesIndex++] = _numVertices + 2;
        _indices[_indicesIndex++] = _numVertices + 1;
        _indices[_indicesIndex++] = _numVertices + 2;
        _indices[_indicesIndex++] = _numVertices + 3;

        _numVertices += FlxGLRenderer.VERTICES_PER_QUAD;
        _numIndices += FlxGLRenderer.INDICES_PER_QUAD;

        _count += FlxGLRenderer.INDICES_PER_QUAD;

    }

    public function addTriangles(data:FlxTrianglesDrawData):Void
    {
        // Flush buffer if we can't fit anymore
        if (_numVertices + data.vertices.length > maxVertices
            || _numIndices + data.indices.length > maxIndices)
            flush();

        // Check if the sprite we're about to add requires a new draw call
        updateRenderState(data);

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
            addVertex(transformedX, transformedY, u, v, color, data.colorOffset, _currentTextureSlot);
        }

        // Update indices
        for (i in 0...data.indices.length)
            _indices[_indicesIndex++] = _numVertices + data.indices[i];

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
            final dc = BatchDrawCall.get(this, _count, _offset, _currentTopology, _currentShader, _currentBlendMode, _textures, _texturesSmoothing);
            _drawCalls.push(dc);
        }

        uploadBuffers();

        for (dc in _drawCalls)
        {
            _renderer.draw(dc);
            dc.put();
        }

        _currentTopology = TRIANGLE_LIST;
        _currentBlendMode = null;
        _currentShader = null;
        _textures.fill(null);
        _numTextureSlots = 0;
        _currentTextureSlot = -1;

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
    public function initShader(shader:FlxShader):Void
    {
        final stride = attributesPerVertex * Float32Array.BYTES_PER_ELEMENT;
        var offset = 0;

        // TODO: think about VAOs and the location

        // Setup and enable position attribute
		GL.vertexAttribPointer(shader.getAttributeLocation("flixel_aPosition"), 2, GL.FLOAT, false, stride, offset);
		GL.enableVertexAttribArray(shader.getAttributeLocation("flixel_aPosition"));

        offset += 2 * 4;

        // Setup and enable tex coord attribute
		GL.vertexAttribPointer(shader.getAttributeLocation("flixel_aTextureCoord"), 2, GL.FLOAT, false, stride, offset);
		GL.enableVertexAttribArray(shader.getAttributeLocation("flixel_aTextureCoord"));

        offset += 2 * 4;

        // Color attributes will be interpreted as unsigned bytes and normalized
        // Setup and enable color multiplier attribute
		GL.vertexAttribPointer(shader.getAttributeLocation("flixel_aColorMultiplier"), 4, GL.UNSIGNED_BYTE, true, stride, offset);
		GL.enableVertexAttribArray(shader.getAttributeLocation("flixel_aColorMultiplier"));

        offset += 4;

        // Setup and enable color offset attribute
		GL.vertexAttribPointer(shader.getAttributeLocation("flixel_aColorOffset"), 4, GL.UNSIGNED_BYTE, true, stride, offset);
		GL.enableVertexAttribArray(shader.getAttributeLocation("flixel_aColorOffset"));

        #if FLX_OPENGL_BATCH_TEXTURES
        if (shader is FlxBatcherShader)
        {
            offset += 4;
            
            // Setup and enable texture slot attribute
            GL.vertexAttribPointer(shader.getAttributeLocation("flixel_aTextureSlot"), 1, GL.FLOAT, false, stride, offset);
            GL.enableVertexAttribArray(shader.getAttributeLocation("flixel_aTextureSlot"));
        }
        #end
    }

    /**
     * Checks if `next` can be batched according to the current render state, and if
     * not, starts a new batch and updates the render state accordingly.
     * 
     * @param   next   Draw data to compare against.
     */
    function updateRenderState(next:FlxDrawData):Void
    { 
        inline function resolveShader(shader:FlxShader):FlxShader
        {
            return shader == null ? FlxGLRenderer.defaultShader : shader;
        }

        #if FLX_OPENGL_BATCH_TEXTURES
        var foundTextureSlot = -1;
        #end

        // No bother checking if we can batch if there's nothing in the buffer
        if (_numVertices > 0)
        {
            // First, compare the render states
            // We can only batch if the topology, blend mode and shader are the same.
            // Textures are a bit more complicated... more on that in a second
            var batchable:Bool = _currentTopology == next.topology && _currentShader == resolveShader(next.shader) && _currentBlendMode == next.blend;

            #if FLX_OPENGL_BATCH_TEXTURES
            // Check if we can batch the texture only if we've passed the previous batching rules,
            // and if the current shader supports texture batching.
            if (batchable && _canBatchTextures)
            {
                // haxe.ds.Vector has no indexOf() ...
                for (i in 0..._numTextureSlots)
                {
                    if (_textures[i] == next.texture)
                    {
                        foundTextureSlot = i;
                        break;
                    }
                }

                // The texture is not in our current pool, or its filter has changed
                if (foundTextureSlot == -1 || (foundTextureSlot != -1 && _texturesSmoothing[foundTextureSlot] != next.textureSmoothing))
                {
                    // Can't add it because we're out of space, break the batch
                    if (_numTextureSlots == _textures.length)
                    {
                        batchable = false;
                        foundTextureSlot = -1;
                    }
                }
            }

            #else
            // Texture batching is disabled, so in addition to the previous batching rules
            // we also check if the texture and its filter are the same as the current.
            batchable = batchable && _textures[0] == next.texture && _texturesSmoothing[0] == next.textureSmoothing;
            #end

            if (!batchable)
            {
                // Push a draw call with the previous render state
                final dc = BatchDrawCall.get(this, _count, _offset, _currentTopology, _currentShader, _currentBlendMode, _textures, _texturesSmoothing);
                _drawCalls.push(dc);
                _offset += _count * UInt16Array.BYTES_PER_ELEMENT;
                _count = 0;

                #if FLX_OPENGL_BATCH_TEXTURES
                // Also reset our texture pool
                if (_canBatchTextures)
                {
                    _textures.fill(null);
                    _numTextureSlots = 0;
                    _currentTextureSlot = -1;
                }
                #end
            }
        }

        // Finally, update the render state
        _currentTopology = next.topology;
        _currentBlendMode = next.blend;
        _currentShader = resolveShader(next.shader);

        #if FLX_OPENGL_BATCH_TEXTURES
        // We can only batch textures with a compatible shader, which is currently ONLY FlxBatcherShader...
        // TODO: look into texture batching in custom sahders
        _canBatchTextures = _currentShader is FlxBatcherShader;

        if (_canBatchTextures)
        {
            // Only add a new texture in the pool if we didn't find it during the batching check
            if (foundTextureSlot == -1)
            {
                _numTextureSlots++;
                _currentTextureSlot = _numTextureSlots - 1;
            }
            else
                _currentTextureSlot = foundTextureSlot;
        }
        else
            _currentTextureSlot = 0;

        _textures[_currentTextureSlot] = next.texture;
        _texturesSmoothing[_currentTextureSlot] = next.textureSmoothing;
        #else
        _textures[0] = next.texture;
        _texturesSmoothing[0] = next.textureSmoothing;
        #end
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
        _renderer.context.bindGLVertexBuffer(_glVertexBuffer);

        // TODO: I can't seem to figure out buffer orphaning... this all runs roughly the same?
        if (_numVertices == maxVertices)
        {
            // "orphan" (reallocate) the entire buffer to prevent stalls
            // GLHelper.bufferData(GL.ARRAY_BUFFER, null, GL.STREAM_DRAW);
            GLHelper.bufferSubData(GL.ARRAY_BUFFER, 0, _positions);
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
            // GLHelper.bufferData(GL.ELEMENT_ARRAY_BUFFER, null, GL.STREAM_DRAW);
            GLHelper.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, 0, _indices);
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
        _positions[_vertexIndex++] = textureSlot;
    }
}

@:access(flixel.system.render.gl.FlxBatcher)
@:forward
abstract BatchDrawCall(FlxDrawCall) from FlxDrawCall to FlxDrawCall
{
    public inline static function get(batcher:FlxBatcher, count:Int, offset:Int, topology:FlxTopology, shader:FlxShader, blend:BlendMode,
			texture:Vector<FlxTexture>, textureSmoothing:Vector<Bool>):BatchDrawCall
	{
		var dc = FlxDrawCall.get()
			.init(batcher._glIndexBuffer, count, offset)
			.setState(topology, shader, blend, texture, textureSmoothing);

        // This doesn't work because it eventually gets overwritten by the next draw call, as we don't draw immediately after setting these uniforms...
        // #if FLX_OPENGL_BATCH_TEXTURES
        // // 1 here because we set the main texture (0) in the setState() call above
        // for (i in 1...texture.length)
        // {
        //     var tex = texture.get(i);
        //     if (tex == null)
        //         break; // should be bound in order, so a null in the middle means everything else is null

        //     var smoothing = textureSmoothing.get(i);
        //     shader.setTexture('flixel_uTexture$i', tex, smoothing);
        // }
        // #end

        return dc;
	}
}
#end
