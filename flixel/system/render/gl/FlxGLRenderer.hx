package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.graphics.FlxBitmap;
import flixel.graphics.shaders.FlxShader;
import flixel.graphics.textures.FlxRenderTexture;
import flixel.graphics.textures.FlxTexture;
import flixel.math.FlxRect;
import flixel.system.render.FlxRenderer;
import flixel.system.render.FlxRendererTypes;
import flixel.system.render.FlxTopology;
import flixel.system.render.gl.FlxDrawCall;
import flixel.util.FlxColor;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;
import lime.graphics.opengl.GLTexture;
import lime.math.Matrix4;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import lime.utils.UInt8Array;
import openfl.display.BitmapData;
import openfl.display.Shader;

@:access(flixel.system.render.gl)
@:access(flixel.FlxCamera)
class FlxGLRenderer extends FlxTypedRenderer<FlxGLView>
{
    /**
     * The amount of vertices needed for a single quad.
     */
    public static inline final VERTICES_PER_QUAD:Int = 4;

    /**
     * The amount of vertices needed for a single triangle.
     */
    public static inline final VERTICES_PER_TRIANGLE:Int = 3;

    /**
     * The amount of indices needed for a single quad.
     */
    public static inline final INDICES_PER_QUAD:Int = 6;

    /**
     * The amount of vertices needed for a signel triangle.
     */
    public static inline final INDICES_PER_TRIANGLE:Int = 3;

    /**
     * The maximum amount of vertices that can fit in a index buffer.
     */
    public static inline final MAX_VERTICES_PER_BUFFER:Int = 65535;

    /**
     * The maximum amount of quads that can fit in an index buffer.
     * 
     * 65335 (max indices in a buffer) / 4 (unique indices per quad) = ~16383
     */
    public static inline final MAX_QUADS_PER_BUFFER:Int = 16383;

    /**
     * Whether vertex array objects (VAOs) are supported
     * 
     * This is dependent on the current OpenGL version. If the current version does not natively support VAOs,
     * an extension will be tried to be used instead. 
     * If VAOs are not supported in any form, they will be emulated.
     */
    public static var supportsVAO:Null<Bool>;

    /**
     * The default shader used by the renderer.
     */
    public static var defaultShader:FlxGLShader;

    /**
     * A tiny wrapper over the GL context.
     * 
     * @see `GLContext`
     */
    public var context(default, null):GLContext;

    public var projection(get, never):Matrix4;
    inline function get_projection():Matrix4
    {
        return _needsFlippedProjection ? _projectionFlipped : _projection;
    }

    public var batcher:FlxBatcher;

    var _projection:Matrix4 = new Matrix4();
    var _projectionFlipped:Matrix4 = new Matrix4();
    var _projectionWidth:Int;
    var _projectionHeight:Int;
    var _needsFlippedProjection:Bool = true;

    public function new():Void
    {
        super();
        method = OPENGL;
        textures = new FlxGLTextureSystem(this);
        renderTargets = new FlxGLRenderTargetSystem(this);
        shaders = new FlxGLShaderSystem(this);
        maxTextureSize = cast GL.getParameter(GL.MAX_TEXTURE_SIZE);
    }

    override function initGlobals():Void
    {
        if (supportsVAO == null)
        {
            // Natively supported on WebGL 2.0 and OpenGL (ES) 3.0+
            var supportsNatively = (GL.type == WEBGL && GL.version >= 2) && ((GL.type == OPENGLES || GL.type == OPENGL) && GL.version >= 3);

            // On older versions we may still be able to use it if the required extension is available
            var extensions = GL.getSupportedExtensions();
            // TODO: APPLE_vertex_array_object ?
            var supportsExtension = extensions.contains("ARB_vertex_array_object") || extensions.contains("OES_vertex_array_object");

            #if (desktop && lime <= version("8.3.1"))
            // VAO functions are broken on current Lime when targeting desktop ...
            supportsVAO = false;
            #else
            supportsVAO = supportsNatively || supportsExtension;
            #end
        }

        context = new GLContext();

        defaultShader = new FlxGLShader();

        batcher = new FlxBatcher(MAX_QUADS_PER_BUFFER * VERTICES_PER_QUAD, MAX_QUADS_PER_BUFFER * INDICES_PER_QUAD, 6);
    }

    // =============================================================================
	//{region                          PUBLIC API
	// =============================================================================

    /**
     * Immediately executes the passed `FlxDrawCall`.
     * @param   dc   The `FlxDrawCall` to execute.
     */
    public function draw(dc:FlxDrawCall):Void
    {
        final shader = dc.shader;

        // Prep the GL state for the upcoming draw
        // if (_renderer.context.setShader(shader))
        //     initShader(shader);
        // TODO: nicer way to handle attributes?
        if (context.setShader(shader))
            batcher.initShader(shader);

        // Set up render state
        context.setBlendMode(dc.blend);

		shader.setMatrixTypedArray("flixel_uMatrix", projection);

        if (shader.data.flash != null)
        {
            // We cannot use our fancy API for OpenFL shaders so we have to set these manually :(
            var flashShader = shader.data.flash.shader;

            GL.activeTexture(0);
            GL.bindTexture(GL.TEXTURE_2D, dc.texture.texture._handle);

            final filter = flashShader.data.bitmap.filter == openfl.display3D.Context3DTextureFilter.LINEAR ? GL.LINEAR : GL.NEAREST;
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);

            GL.uniform1i(flashShader.data.bitmap.index, 0);
        }
        else
            shader.setTexture("flixel_uTexture", dc.texture.texture, dc.textureSmoothing);

		if (shader.hasUniform("flixel_uTextureSize"))
			shader.setInt2("flixel_uTextureSize", dc.texture.width, dc.texture.height);

        // Upload the uniforms to the GPU
        shader.updateUniforms();

        // Finally, actually draw them
        context.bindGLIndexBuffer(dc.indexBuffer);
		GL.drawElements(dc.topology, dc.count, GL.UNSIGNED_SHORT, dc.offset);
        FlxG.renderer.totalDrawCalls++;
    }

    public function resize(width:Int, height:Int):Void
    {
        if (_projectionWidth == width && _projectionHeight == height)
            return;
    
        _projection.createOrtho(0, width, 0, height, -1000, 1000);
        _projectionFlipped.createOrtho(0, width, height, 0, -1000, 1000);

        _projectionWidth = width;
        _projectionHeight = height;
    }

    public function setRenderTexture(texture:Null<FlxRenderTexture>):Void
    {
        context.setRenderTexture(texture);
        
        if (texture != null)
        {
            _needsFlippedProjection = false;
            GL.viewport(0, 0, texture.width, texture.height);
            resize(texture.width, texture.height);
        }
        else
        {
            _needsFlippedProjection = true;
            GL.viewport(0, 0, FlxG.stage.window.width, FlxG.stage.window.height);
            resize(FlxG.stage.window.width, FlxG.stage.window.height);
        }
    }

    // =============================================================================
	//}endregion                       PUBLIC API
	// =============================================================================

    // =============================================================================
	//{region                          INHERITED
	// =============================================================================

    public inline function startFrame():Void
	{
		FlxG.renderer.totalDrawCalls = 0;
		FlxG.cameras.clear();
	}

	public inline function endFrame():Void
	{
        // First draw sprites onto their cameras
		FlxG.cameras.render();

        // Switch to drawing on the screen
        setRenderTexture(null);

        for (camera in FlxG.cameras.list)
        {
            if ((camera != null) && camera.exists && camera.visible && camera.viewGL.needsRender)
            {
                // Then queue the actual camera texture
                batcher.addQuad(camera.viewGL.getDrawData());
            }
        }

        // Finally flush to upload them to the GPU and draw
        batcher.flush();
	}

    public function createCameraView(camera:FlxCamera)
	{
		return new FlxGLView(camera);
	}

    // GL doesn't need to register cameras into the display tree
    public function addCameraView(view:FlxGLView) {}
    public function addCameraViewAt(view:FlxGLView, index:Int) {}
    public function removeCameraView(view:FlxGLView) {}
}

@:access(flixel.graphics.textures)
class FlxGLTextureSystem implements IFlxTextureSystem
{
    public var renderer:FlxGLRenderer;

	public function new(renderer:FlxGLRenderer) 
    {
        this.renderer = renderer;
    }
	
	public function createHandle():FlxTextureHandle 
    {
        // return GL.createTexture();
        final handle = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, handle);

        // TODO ant: remove this in v7.0.0 when texture filtering is real
        // GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        // GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);

        return handle;
    }

	public function destroyHandle(handle:FlxTextureHandle):Void 
    {
        GL.deleteTexture(handle);
    }

	public function destroyBitmap(bitmap:FlxBitmap):Void 
    {
        bitmap.destroy();
    }

	public function uploadBitmap(texture:FlxTexture, bitmap:FlxBitmap):Void 
    {
        var dataFormat = GL.RGBA;
        
        #if sys
        // On sys targets, OpenFL stores bitmaps in BGRA format
        // During uploads we can simply tell OpenGL to interpret the data as BGRA
        if (bitmap.image.format == BGRA32)
        {
            var ext = GL.getExtension("EXT_bgra");
            if (ext != null)
                dataFormat = ext.BGRA_EXT;
        }
        #end

        if (!texture._allocated)
            renderer.context.allocTextureData(texture, GL.RGBA, bitmap.data, dataFormat);
        else
            renderer.context.uploadTextureData(texture, bitmap.data, dataFormat);
    }

	public function readPixels(texture:FlxTexture, buffer:UInt8Array, ?rect:FlxRect):Void 
    {
        renderer.context.bindTexture(texture);

        // Create dummy framebuffer we'll read from
        var fb = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, fb);

        // Attach texture to framebuffer and read the pixels from it into the buffer
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture._handle, 0);
        GLHelper.readPixels(Std.int(rect.x), Std.int(rect.y), Std.int(rect.width), Std.int(rect.height), GL.RGBA, GL.UNSIGNED_BYTE, buffer);

        // Delete the framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, null);
        GL.deleteFramebuffer(fb);
    }

	public function setWrapU(texture:FlxTexture, wrap:FlxTextureWrap):Void 
    {
        renderer.context.bindTexture(texture);
        renderer.context.setTextureWrapU(wrap);
    }

	public function setWrapV(texture:FlxTexture, wrap:FlxTextureWrap):Void 
    {
        renderer.context.bindTexture(texture);
        renderer.context.setTextureWrapV(wrap);
    }
}

class FlxGLRenderTargetSystem implements IFlxRenderTargetSystem
{
    public var renderer:FlxGLRenderer;

	public function new(renderer:FlxGLRenderer) 
    {
        this.renderer = renderer;
    }

	public function createHandle(texture:FlxRenderTexture, depthStencil:Bool):FlxRenderTargetHandle 
    {
        var handle = new FlxGLRenderTarget();
        handle.texture = texture;

        handle.framebuffer = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, handle.framebuffer);
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture._handle, 0);

        // resizeRenderTarget(texture, texture.width, texture.height);
        return handle;
    }

	public function destroyHandle(handle:FlxRenderTargetHandle):Void 
    {
        if (handle.framebuffer != null)
        {
            GL.deleteFramebuffer(handle.framebuffer);
            handle.framebuffer = null;
        }

        if (handle.renderbuffer != null)
        {
            GL.deleteRenderbuffer(handle.renderbuffer);
            handle.renderbuffer = null;
        }
    }

	public function resize(texture:FlxRenderTexture, width:Int, height:Int):Void 
    {
        final target = texture.renderTarget;
        renderer.context.bindTexture(texture);

        // Reallocate texture with new size
        GLHelper.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);

        // Delete previous render buffer because it's not safe to reuse
        if (target.renderbuffer != null)
        {
            GL.deleteRenderbuffer(target.renderbuffer);
            target.renderbuffer = null;
        }

        // Initialize the new render buffers
        setupRenderTargetBuffers(texture, width, height);
    }

	public function clear(texture:FlxRenderTexture, color:FlxColor, depth:Bool, stencil:Bool):Void 
    {
        GL.bindFramebuffer(GL.FRAMEBUFFER, texture.renderTarget.framebuffer);

        var mask:Int = GL.COLOR_BUFFER_BIT;
        if (depth)
            mask |= GL.DEPTH_BUFFER_BIT;
        if (stencil)
            mask |= GL.STENCIL_BUFFER_BIT;

        GL.clearColor(color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat);
        GL.clear(mask);
    }

    function setupRenderTargetBuffers(texture:FlxRenderTexture, width:Int, height:Int):Void
    {
        final target = texture.renderTarget;

        if (texture.hasDepthStencil)
        {
            // Create depth/stencil buffer
            target.renderbuffer = GL.createRenderbuffer();
            GL.bindRenderbuffer(GL.RENDERBUFFER, target.renderbuffer);
            GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH24_STENCIL8, texture.width, texture.height);

            // Attach it to the framebuffer
            GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_STENCIL_ATTACHMENT, GL.RENDERBUFFER, target.renderbuffer);
        }
    }
    // =============================================================================
	//}endregion                        INHERITED
	// =============================================================================
}

class FlxGLShaderSystem implements IFlxShaderSystem
{
    public var renderer:FlxGLRenderer;

    public function new(renderer:FlxGLRenderer)
    {
        this.renderer = renderer;
    }

    public function createHandle(data:FlxShaderData):FlxShaderHandle
    {
        // TODO: use default shader data when certain params are null

        #if !flash
        if (data.flash != null)
        {
            var fshader = data.flash.shader;

            // https://github.com/openfl/openfl/blob/de55e8c592826d6f56b424badeaf2eebd1a7b0c2/src/openfl/display/OpenGLRenderer.hx#L537-L554
            @:privateAccess
            {
                if (fshader.__context == null)
                {
                    fshader.__context = FlxG.stage.context3D;
                    fshader.__init();
                }
            }

            return fshader.glProgram;
        }
        #end

        var program = GL.createProgram();

        if (data.glsl.vertex != null)
        {
            var vs = createShader(GL.VERTEX_SHADER, data.glsl.vertex);
            GL.attachShader(program, vs);

            // Before linking the shader program we want to ensure our attributes
            // will be assigned to the locations we want them to be in
            // This is so that we can take advantage of VAOs properly
            if (data.glsl.vertex.attributes != null)
            {
                for (i in 0...data.glsl.vertex.attributes.length)
                    GL.bindAttribLocation(program, i, data.glsl.vertex.attributes[i]);
            }
        }

        if (data.glsl.fragment != null)
        {
            var fs = createShader(GL.FRAGMENT_SHADER, data.glsl.fragment);
            GL.attachShader(program, fs);
        }

        GL.linkProgram(program);

        if (GL.getProgramParameter(program, GL.LINK_STATUS) == 0)
        {
            var error = GL.getProgramInfoLog(program);
            trace('Error linking program:\n$error');
        }

        return program;
    }

    public function destroyHandle(handle:FlxShaderHandle):Void
    {
        GL.deleteProgram(handle);
    }

    public function getUniformLocation(handle:FlxShaderHandle, name:String):FlxShaderUniformLocation 
    {
        return GL.getUniformLocation(handle, name);
    }

    public function fetchUniforms(handle:FlxShaderHandle):Array<FlxShaderUniform<Any>>
    {
        var uniforms:Array<FlxShaderUniform<Any>> = [];

        // start from 1 because we're manually going to assign 0 to the main texture
        var lastTextureSlot:Int = 1;

        var numUniforms = GL.getProgramParameter(handle, GL.ACTIVE_UNIFORMS);
        for (i in 0...numUniforms)
        {
            var info = GL.getActiveUniform(handle, i);
            var location = GL.getUniformLocation(handle, info.name);

            var u:FlxShaderUniform<Any> = null;

            // Non-array uniforms
            if (info.size == 1)
            {
                u = switch info.type
                {
                    case GL.FLOAT: new FlxShaderUniform<Float>(FLOAT1, info.name, location, 0);
                    case GL.FLOAT_VEC2: new FlxShaderUniform<ShaderVec2<Float>>(FLOAT2, info.name, location, {x: 0, y: 0});
                    case GL.FLOAT_VEC3: new FlxShaderUniform<ShaderVec3<Float>>(FLOAT3, info.name, location, {x: 0, y: 0, z: 0});
                    case GL.FLOAT_VEC4: new FlxShaderUniform<ShaderVec4<Float>>(FLOAT4, info.name, location, {x: 0, y: 0, z: 0, w: 0});

                    // Booleans don't really exist, so we'll represent them as integers
                    case GL.INT, GL.BOOL: new FlxShaderUniform<Int>(INT1, info.name, location, 0);
                    case GL.INT_VEC2: new FlxShaderUniform<ShaderVec2<Int>>(INT2, info.name, location, {x: 0, y: 0});
                    case GL.INT_VEC3: new FlxShaderUniform<ShaderVec3<Int>>(INT3, info.name, location, {x: 0, y: 0, z: 0});
                    case GL.INT_VEC4: new FlxShaderUniform<ShaderVec4<Int>>(INT4, info.name, location, {x: 0, y: 0, z: 0, w: 0});

                    case GL.FLOAT_MAT4: new FlxShaderUniform<ShaderMatrix>(MAT4X4, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT4x3: new FlxShaderUniform<ShaderMatrix>(MAT4X3, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT4x2: new FlxShaderUniform<ShaderMatrix>(MAT4X2, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT3x4: new FlxShaderUniform<ShaderMatrix>(MAT3X4, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT3: new FlxShaderUniform<ShaderMatrix>(MAT3X3, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT3x2: new FlxShaderUniform<ShaderMatrix>(MAT3X2, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT2x4: new FlxShaderUniform<ShaderMatrix>(MAT2X4, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT2x3: new FlxShaderUniform<ShaderMatrix>(MAT2X3, info.name, location, {data: null, transpose: false});
                    case GL.FLOAT_MAT2: new FlxShaderUniform<ShaderMatrix>(MAT2X2, info.name, location, {data: null, transpose: false});

                    // GL_SAMPLER_2D_MULTISAMPLE = 0x9108
                    case GL.SAMPLER_2D, 0x9108:
                        // Special case, where if the uniform is "flixel_Texture" (the main texture) we'll manually assign it the 0 slot,
                        // and otherwise we'll just assign the slots in random order
                        new FlxShaderUniform<ShaderTexture>(TEXTURE, info.name, location, {texture: null, smoothing: false, slot: info.name == "flixel_uTexture" ? 0 : lastTextureSlot++});

                    default: null;
                }
            }
            else // Array uniforms
            {
                u = switch info.type
                {
                    case GL.FLOAT: new FlxShaderUniform<ShaderArray<Float32Array>>(FLOAT_ARRAY, info.name, location, {data: null, dimension: SCALAR});
                    case GL.FLOAT_VEC2: new FlxShaderUniform<ShaderArray<Float32Array>>(FLOAT_ARRAY, info.name, location, {data: null, dimension: VEC2});
                    case GL.FLOAT_VEC3: new FlxShaderUniform<ShaderArray<Float32Array>>(FLOAT_ARRAY, info.name, location, {data: null, dimension: VEC3});
                    case GL.FLOAT_VEC4: new FlxShaderUniform<ShaderArray<Float32Array>>(FLOAT_ARRAY, info.name, location, {data: null, dimension: VEC4});

                    // Booleans don't really exist, so we'll represent them as integers
                    case GL.INT, GL.BOOL: new FlxShaderUniform<ShaderArray<Int32Array>>(INT_ARRAY, info.name, location, {data: new Int32Array(info.size), dimension: SCALAR});
                    case GL.INT_VEC2: new FlxShaderUniform<ShaderArray<Int32Array>>(INT_ARRAY, info.name, location, {data: null, dimension: VEC2});
                    case GL.INT_VEC3: new FlxShaderUniform<ShaderArray<Int32Array>>(INT_ARRAY, info.name, location, {data: null, dimension: VEC3});
                    case GL.INT_VEC4: new FlxShaderUniform<ShaderArray<Int32Array>>(INT_ARRAY, info.name, location, {data: null, dimension: VEC4});

                    // TODO: matrix array

                    default: null;
                }
            }

            if (u == null)
            {
                FlxG.log.warn('Unhandled shader uniform type (name: ${info.name}, type: ${info.type}, size: ${info.size}). You should report this!');
                continue;
            }

            // uniforms.set(info.name, u);
            // _uniformList.push(u);
            uniforms.push(u);
        }

        return uniforms;
    }

    public function getAttributeLocation(handle:FlxShaderHandle, name:String):FlxShaderAttributeLocation 
    {
        return GL.getAttribLocation(handle, name);
    }

    public function setUniformInt(location:FlxShaderUniformLocation, v:Int):Void
    {
        GL.uniform1i(location, v);
    }

	public function setUniformInt2(location:FlxShaderUniformLocation, v1:Int, v2:Int):Void
    {
        GL.uniform2i(location, v1, v2);
    }

	public function setUniformInt3(location:FlxShaderUniformLocation, v1:Int, v2:Int, v3:Int):Void
    {
        GL.uniform3i(location, v1, v2, v3);    
    }

	public function setUniformInt4(location:FlxShaderUniformLocation, v1:Int, v2:Int, v3:Int, v4:Int):Void
    {
        GL.uniform4i(location, v1, v2, v3, v4);
    }

	public function setUniformIntArray(location:FlxShaderUniformLocation, v:Int32Array, dimension:FlxShaderArrayDimension):Void
    {
        switch dimension
        {
            case SCALAR: GLHelper.uniform1iv(location, v);
            case VEC2: GLHelper.uniform2iv(location, v);
            case VEC3: GLHelper.uniform3iv(location, v);
            case VEC4: GLHelper.uniform4iv(location, v);
        }
    }

	public function setUniformFloat(location:FlxShaderUniformLocation, v:Float):Void
    {
        GL.uniform1f(location, v);
    }

	public function setUniformFloat2(location:FlxShaderUniformLocation, v1:Float, v2:Float):Void
    {
        GL.uniform2f(location, v1, v2);
    }

	public function setUniformFloat3(location:FlxShaderUniformLocation, v1:Float, v2:Float, v3:Float):Void
    {
        GL.uniform3f(location, v1, v2, v3);
    }

	public function setUniformFloat4(location:FlxShaderUniformLocation, v1:Float, v2:Float, v3:Float, v4:Float):Void
    {
        GL.uniform4f(location, v1, v2, v3, v4);
    }

	public function setUniformFloatArray(location:FlxShaderUniformLocation, v:Float32Array, dimension:FlxShaderArrayDimension):Void
    {
        switch dimension
        {
            case SCALAR: GLHelper.uniform1fv(location, v);
            case VEC2: GLHelper.uniform2fv(location, v);
            case VEC3: GLHelper.uniform3fv(location, v);
            case VEC4: GLHelper.uniform4fv(location, v);
        }
    }

    // TODO: IMPLEMENT NON-SQUARE MATRIX METHODS

	public function setUniformMatrix4x4(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {
        GLHelper.uniformMatrix4fv(location, transpose, v);
    }

	public function setUniformMatrix4x3(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {

    }

	public function setUniformMatrix4x2(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {

    }

	public function setUniformMatrix3x4(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {

    }

	public function setUniformMatrix3x3(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {
        GLHelper.uniformMatrix3fv(location, transpose, v);
    }

	public function setUniformMatrix3x2(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {

    }

	public function setUniformMatrix2x4(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {

    }

	public function setUniformMatrix2x3(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {

    }

    public function setUniformTexture(location:FlxShaderUniformLocation, v:FlxTexture, smoothing:Bool, slot:Int):Void
    {
        // Activate the slot and bind our texture to it
        GL.activeTexture(GL.TEXTURE0 + slot);
        renderer.context.bindTexture(v);
        
        // Apply smoothing
        var filter = smoothing ? GL.LINEAR : GL.NEAREST;
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);

        // Write the texture's slot to our texture uniform
        GL.uniform1i(location, slot);
    }

	public function setUniformMatrix2x2(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void
    {
        GLHelper.uniformMatrix2fv(location, transpose, v);
    }

    function createShader(type:Int, data:GLSLShader):GLShader 
    {
        var shader = GL.createShader(type);
        var src = processShaderSource(data);
        GL.shaderSource(shader, src);
        GL.compileShader(shader);

        if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0)
        {
            var error = GL.getShaderInfoLog(shader);
            trace('Error compiling ${type == GL.FRAGMENT_SHADER ? 'fragment' : 'vertex'} shader:\n$error');
            trace(src);
        }

        return shader;
    }

    function processShaderSource(shader:GLSLShader):String
    {
        var prefix:StringBuf = new StringBuf();

        var versionRegex = ~/^#version/m;

        if (shader.version != null)
        {
            if (!versionRegex.match(shader.source))
                prefix.add('#version ${shader.version}\n');
            else
                FlxG.log.warn("Can't inject shader version because the shader code already specifies it!");

            // if (shader.allowConvert)
            // {
            //     // Based off of the implementation by EliteMasterEric (https://github.com/openfl/openfl/pull/2722)
            //     var attributeRegex = ~/attribute ([A-Za-z0-9]+) ([A-Za-z0-9_]+)/g;
            //     var varyingRegex = ~/varying ([A-Za-z0-9]+) ([A-Za-z0-9_]+)/g;

            //     var texture2DRegex = ~/texture2D/g;
            //     var glFragColorRegex = ~/gl_FragColor/g;

            //     switch (shader.version)
            // }
        }

        var precisionRegex = ~/^precision/m;

        // Precision qualifiers are only supported on OpenGL ES and WebGL
        if (GL.type != OPENGL && shader.precision != null)
        {
            if (!precisionRegex.match(shader.source))
            {
                prefix.add("#ifdef GL_ES\n");

                // Not all GPUs support high precision so we have to see if its available
                // and fallback to medium if it's not
                if (shader.precision == HIGH)
                {
                    prefix.add("#ifdef GL_FRAGMENT_PRECISION_HIGH\n");
                    prefix.add("precision highp float;\n");
                    prefix.add("#else\n");
                    prefix.add("precision mediump float;\n");
                    prefix.add("#endif\n");
                }
                else
                {
                    prefix.add('precision ${shader.precision} float;\n');
                }

                prefix.add("#endif\n");
            }
            else
                FlxG.log.warn("Can't inject shader precision qualifier because the shader code already specifies it!");
        }

        prefix.add("\n");

        return prefix.toString() + shader.source;
    }
}
#end
