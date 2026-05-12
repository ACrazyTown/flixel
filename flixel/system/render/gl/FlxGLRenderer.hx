package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.system.render.FlxTopology;
import lime.utils.Float32Array;
import openfl.display.Shader;
import flixel.system.render.gl.FlxDrawCall;
import openfl.display.BitmapData;
import lime.graphics.opengl.GLTexture;
import flixel.system.render.FlxRenderer.FlxTypedRenderer;
import lime.math.Matrix4;
import flixel.graphics.FlxBitmap;
import flixel.graphics.FlxTexture;
import flixel.graphics.FlxRenderTexture;
import flixel.util.FlxColor;
import flixel.math.FlxRect;
import lime.utils.UInt8Array;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.opengl.GL;

@:access(flixel.system.render.gl)
@:access(flixel.graphics)
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

        // Set matrix uniform
        // TODO: apply in resize
        GLHelper.uniformMatrix4fv(shader.data.uMatrix.index, false, projection);

        // Set up render state
        context.setBlendMode(dc.blend);

        // Set up textures
        context.bindTexture(dc.texture.texture);

        // TODO: texture.filter ?
        var filter = dc.textureSmoothing ? GL.LINEAR : GL.NEAREST;
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);

        GL.activeTexture(GL.TEXTURE0);
        GL.uniform1i(shader.data.uImage0.index, 0);
        GL.uniform2f(shader.data.uTextureSize.index, dc.texture.width, dc.texture.height);

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

    function createTextureHandle():FlxTextureHandle
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

	function destroyTextureHandle(handle:FlxTextureHandle):Void
    {
        GL.deleteTexture(handle);
    }

    function destroyTextureBitmap(bitmap:FlxBitmap):Void
    {
        bitmap.destroy();
    }

	function uploadTextureBitmap(texture:FlxTexture, bitmap:FlxBitmap):Void
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
            context.allocTextureData(texture, GL.RGBA, bitmap.data, dataFormat);
        else
            context.uploadTextureData(texture, bitmap.data, dataFormat);
    }

	function readTexturePixels(texture:FlxTexture, buffer:UInt8Array, ?rect:FlxRect):Void
    {
        context.bindTexture(texture);

        // Create dummy framebuffer we'll read from
        var fb = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, fb);

        // Attach texture to framebuffer and read the pixels from it into the buffer
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture.handle, 0);
        final x = rect != null ? Std.int(rect.x) : 0;
        final y = rect != null ? Std.int(rect.y) : 0;
        final w = rect != null ? Std.int(rect.width) : 0;
        final h = rect != null ? Std.int(rect.height) : 0;
        GLHelper.readPixels(x, y, w, h, GL.RGBA, GL.UNSIGNED_BYTE, buffer);

        // Delete the framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, null);
        GL.deleteFramebuffer(fb);
    }

    inline function setTextureWrapU(texture:FlxTexture, wrap:FlxTextureWrap):Void
    {
        context.bindTexture(texture);
        context.setTextureWrapU(wrap);
    }

	inline function setTextureWrapV(texture:FlxTexture, wrap:FlxTextureWrap):Void
    {
        context.bindTexture(texture);
        context.setTextureWrapV(wrap);
    }

	// inline function setTextureFilter(texture:FlxTexture, filter:FlxTextureFilter):Void
    // {
    //     context.bindTexture(texture);
    //     context.setTextureFilter(filter);
    // }

    function createRenderTargetHandle(texture:FlxRenderTexture, depthStencil:Bool):FlxRenderTargetHandle
    {
        var handle = new FlxGLRenderTarget();
        handle.texture = texture;

        handle.framebuffer = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, handle.framebuffer);
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture.handle, 0);

        // resizeRenderTarget(texture, texture.width, texture.height);
        return handle;
    }

	function destroyRenderTargetHandle(handle:FlxRenderTargetHandle):Void
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

    function resizeRenderTarget(texture:FlxRenderTexture, width:Int, height:Int):Void
    {
        final target = texture.renderTarget;
        context.bindTexture(texture);

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

	function clearRenderTarget(texture:FlxRenderTexture, color:FlxColor, depth:Bool, stencil:Bool):Void
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
#end
