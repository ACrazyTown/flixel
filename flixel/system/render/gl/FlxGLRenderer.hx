package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import lime.graphics.opengl.GLTexture;
import flixel.system.render.FlxRenderer.FlxTypedRenderer;
import lime.math.Matrix4;
import flixel.graphics.FlxBitmap;
import flixel.graphics.FlxTexture;
import flixel.graphics.FlxRenderTexture;
import flixel.util.FlxColor;
import flixel.math.FlxRect;
#if FLX_OPENGL_AVAILABLE
import lime.utils.UInt8Array;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.opengl.GL;
#end

@:access(flixel.system.render.gl)
@:access(flixel.graphics)
class FlxGLRenderer extends FlxTypedRenderer<FlxGLView>
{
    /**
     * The amount of vertices needed for a single quad.
     */
    public static inline final VERTICES_PER_QUAD:Int = 4;

    /**
     * The amount of indices needed for a single quad.
     */
    public static inline final INDICES_PER_QUAD:Int = 6;

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
     * The default capacity of a quad batch.
     */
    public static inline final QUADS_PER_BATCH:Int = 8192;

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

    /**
     * A quad batcher that can only fit a single quad.
     * Used for optimization purposes when drawing unbatchable quads.
     */
    public var singleQuadBatcher:FlxQuadBatcher;
    public var quadBatcher:FlxQuadBatcher;

    var _projection:Matrix4 = new Matrix4();
    var _projectionFlipped:Matrix4 = new Matrix4();
    var _projectionWidth:Int;
    var _projectionHeight:Int;
    var _needsFlippedProjection:Bool = true;

    public function new():Void
    {
        super();
        method = OPENGL;
        textures = new FlxGLTextureSystem();
        renderTargets = new FlxGLRenderTargetSystem();

        context = new GLContext();

        defaultShader = new FlxGLShader();

        singleQuadBatcher = new FlxQuadBatcher(1);
        quadBatcher = new FlxQuadBatcher(QUADS_PER_BATCH);
    }

    public function createCameraView(camera:FlxCamera)
	{
		return new FlxGLView(camera);
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
}

class FlxGLTextureSystem implements IFlxTextureSystem
{
	public function new() {}
	
	public function createHandle():FlxTextureHandle 
    {
        // return GL.createTexture();
        final handle = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, handle);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
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
        var dataFormat:Int = GL.RGBA;
        #if sys
        if (bitmap.image.format == BGRA32)
        {
            // On sys targets OpenFL stores bitmaps as BGRA...
            var bgraExt = GL.getExtension("EXT_bgra");
            if (bgraExt != null)
                dataFormat = bgraExt.BGRA_EXT;
        }
        #end

        if (!texture._allocated)
            context.allocTextureData(texture, bitmap.data, dataFormat, GL.RGBA);
        else
            context.uploadTextureData(texture, bitmap.data, GL.RGBA);
    }

	public function readPixels(texture:FlxTexture, buffer:UInt8Array, ?rect:FlxRect):Void 
    {
        context.bindTexture(texture);

        // Create dummy framebuffer we'll read from
        var fb = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, fb);

        // Attach texture to framebuffer and read the pixels from it into the buffer
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture.handle, 0);
        GLHelper.readPixels(Std.int(rect.x), Std.int(rect.y), Std.int(rect.width), Std.int(rect.height), GL.RGBA, GL.UNSIGNED_BYTE, buffer);

        // Delete the framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, null);
        GL.deleteFramebuffer(fb);
    }

	public function setWrapU(texture:FlxTexture, wrap:FlxTextureWrap):Void 
    {
        context.bindTexture(texture);
        context.setTextureWrapU(wrap);
    }

	public function setWrapV(texture:FlxTexture, wrap:FlxTextureWrap):Void 
    {
        context.bindTexture(texture);
        context.setTextureWrapV(wrap);
    }
}

class FlxGLRenderTargetSystem implements IFlxRenderTargetSystem
{
	public function new() {}

	public function createHandle(texture:FlxRenderTexture, depthStencil:Bool):FlxRenderTargetHandle 
    {
        return new FlxGLRenderTarget(texture, depth, stencil);
    }

	public function destroyHandle(handle:FlxRenderTargetHandle):Void 
    {
        handle.destroy();
    }

	public function resize(texture:FlxRenderTexture, width:Int, height:Int):Void 
    {
        var glTexture = texture.handle;
        GL.bindTexture(GL.TEXTURE_2D, glTexture);

        // Reallocate texture with new size
        GLHelper.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);

        // It's not safe to reuse render buffers so we have to recreate them
        texture.renderTarget.initRenderBuffers();
    }

	public function clear(texture:FlxRenderTexture, color:FlxColor, depth:Bool, stencil:Bool):Void 
    {
        GL.bindFramebuffer(GL.FRAMEBUFFER, texture.renderTarget.frameBuffer);

        var mask:Int = GL.COLOR_BUFFER_BIT;
        if (depth)
            mask |= GL.DEPTH_BUFFER_BIT;
        if (stencil)
            mask |= GL.STENCIL_BUFFER_BIT;

        GL.clearColor(color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat);
        GL.clear(mask);
    }
}
#end
