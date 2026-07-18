package flixel.system.render;

import flixel.graphics.FlxBitmap;
import flixel.graphics.textures.FlxTexture;
import flixel.math.FlxRect;
import flixel.system.render.FlxRendererTypes;
import flixel.util.FlxDestroyUtil;
import lime.utils.UInt8Array;

/**
 * `FlxRenderer` is a global, base class that handles rendering.
 * It does not contain any rendering logic by itself, rather it is extended by the various renderer implementations.
 * 
 * You can access a global renderer instance via `FlxG.renderer`.
 */
typedef FlxRenderer = FlxTypedRenderer<FlxCameraView>;

/**
 * Typed Renderer, override this to handle specific backends that require specific cavera views
 */
@:allow(flixel.graphics)
abstract class FlxTypedRenderer<TView:FlxCameraView> implements IFlxDestroyable
{
	/**
	 * Creates a renderer instance, based on the used rendering backend.
	 * This function is dynamic, which means that you can change the return value yourself.
	 * 
	 * @return A `FlxRenderer` instance.
	 */
	public static dynamic function create():FlxRenderer 
	{
		if (!FlxG.renderer.isHardware)
		{
			return cast new flixel.system.render.blit.FlxBlitRenderer();
		}
		else
		{
			return cast new flixel.system.render.quad.FlxQuadRenderer();
		}
	}
	
	/**
	 * The number of total draw calls in the current frame.
	 */
	public var totalDrawCalls:Int = 0;
	
	/**
	 * Returns the current render method as an enum.
	 */
	public var method(default, null):FlxRenderMethod;
	
	/**
	 * Convenience shortcut for `FlxG.renderer.method == BLITTING`
	 */
	public var blit(get, never):Bool;
	inline function get_blit() return method.match(BLITTING);
	
	/**
	 * Convenience shortcut for `FlxG.renderer.method == DRAW_TILES`
	 */
	public var tile(get, never):Bool;
	inline function get_tile() return method.match(DRAW_TILES);
	
	/**
	 * Returns whether the current renderer is hardware accelerated.
	 */
	public var isHardware(get, never):Bool;
	@:noCompletion inline function get_isHardware():Bool
	{
		return FlxG.stage.window.context.attributes.hardware;
	}
	
	/**
	 * Returns whether OpenGL access is available for the current renderer.
	 */
	public var hasGL(get, never):Bool;
	@:noCompletion inline function get_hasGL():Bool
	{
		#if FLX_OPENGL_AVAILABLE
		return FlxG.stage.window.context.type == OPENGL
			|| FlxG.stage.window.context.type == OPENGLES
			|| FlxG.stage.window.context.type == WEBGL;
		#else
		return false;
		#end
	}
	
	/**
	 * Returns the maximum allowed width and height (in pixels) for a texture.
	 * This value is only available on hardware-accelerated targets that use OpenGL.
	 * On unsupported targets, the returned value will always be -1.
	 * 
	 * @see https://opengl.gpuinfo.org/displaycapability.php?name=GL_MAX_TEXTURE_SIZE
	 */
	public var maxTextureSize(default, null):Int = -1;
	
	/**
	 * Backend texture management.
	 * 
	 * Must be set by extending implementations.
	 */
	public var textures(default, null):IFlxTextureSystem;

	function new() {}

	/**
	 * Initializes any global fields that are dependant on the global rendering method.
	 * Called automatically by `FlxG.init()`
	 */
	public function initGlobals() {}
	
	public function destroy():Void {}

	/**
	 * Called at the start of a rendering frame. Does whatever needs to be done 
	 * by the renderer backend (e.g. clears stats, clears the screen ...)
	 */
	abstract public function startFrame():Void;

	/**
	 * Called at the end of a rendering frame. Does whatever needs to be done
	 * by the renderer backend (e.g. finally draws everything to the screen)
	 */
	abstract public function endFrame():Void;

	abstract public function addCameraView(view:TView):Void;
	abstract public function addCameraViewAt(view:TView, index:Int):Void;
	abstract public function removeCameraView(view:TView):Void;
	
	abstract function createCameraView(camera:FlxCamera):TView;
}

/**
 * Abstracted texture management used internally by the renderer.
 * You probably shouldn't use this!
 */
// TODO: how many of these can just take handles?
interface IFlxTextureSystem
{
	// life cycle
	function createHandle():FlxTextureHandle;
	function destroyHandle(handle:FlxTextureHandle):Void;
	function destroyBitmap(bitmap:FlxBitmap):Void;

	// upload
	function uploadBitmap(texture:FlxTexture, bitmap:FlxBitmap):Void;

	// download
	function readPixels(texture:FlxTexture, buffer:UInt8Array, ?rect:FlxRect):Void;

	// properties
	function setWrapU(texture:FlxTexture, wrap:FlxTextureWrap):Void;
	function setWrapV(texture:FlxTexture, wrap:FlxTextureWrap):Void;
}

/**
 * An enum representing the available rendering methods.
 */
enum FlxRenderMethod
{
	/**
	 * Uses the `drawQuads()` method from OpenFL's Graphics API to achieve hardware accelerated rendering.
	 * 
	 * This method is the default and is used on all targets (when hardware acceleration is available), except for Flash.
	 */
	DRAW_TILES;
	
	/**
	 * Draws sprites directly onto bitmaps using a software renderer.
	 * 
	 * This method is mainly used by the Flash target, though other targets will use it too if
	 * hardware acceleration is unavailable.
	 */
	BLITTING;
	
	/**
	 * A custom backend
	 */
	CUSTOM;
}
