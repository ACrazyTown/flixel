package flixel.system.render;

import flixel.graphics.FlxMaterial;
import flixel.math.FlxRect;
import openfl.display.DisplayObjectContainer;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.FlxGraphic;
import flixel.graphics.shaders.FlxShader;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxPoint;
import flixel.math.FlxMatrix;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import flixel.util.FlxColor;
import flixel.graphics.FlxBlendMode;
import openfl.filters.BitmapFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.display.DisplayObject;
import openfl.display.BitmapData;

/**
 * A `FlxCameraView` is the base class for all rendering functionality.
 * It does not contain any rendering logic by itself, rather it is extended by the various renderer implementations.
 */
@:allow(flixel.FlxCamera)
class FlxCameraView implements IFlxDestroyable
{
	// Batching related static variables and constants:
	public static inline final MAX_INDICES_PER_BUFFER:Int = 98298;
	public static inline final MAX_VERTEX_PER_BUFFER:Int = 65532; // (MAX_INDICES_PER_BUFFER * 4 / 6)
	public static inline final MAX_QUADS_PER_BUFFER:Int = 16383; // (MAX_VERTEX_PER_BUFFER / 4)
	public static inline final MAX_TRIANGLES_PER_BUFFER:Int = 21844; // (MAX_VERTEX_PER_BUFFER / 3)

	public static inline final VERTICES_PER_QUAD:Int = 4;
	public static inline final TRIANGLES_PER_QUAD:Int = 2;
	public static inline final INDICES_PER_TRIANGLE:Int = 3;
	public static inline final INDICES_PER_QUAD:Int = 6;

	/**
	 * Max size of the batch. Used for quad render items. If you'll try to add one more tile to the full batch, then new batch will be started.
	 */
	public static var QUADS_PER_BATCH(default, set):Int = 2000;

	static function set_QUADS_PER_BATCH(value:Int):Int
	{
		QUADS_PER_BATCH = (value > MAX_QUADS_PER_BUFFER) ? MAX_QUADS_PER_BUFFER : value;
		return QUADS_PER_BATCH;
	}

	public static var TRIANGLES_PER_BATCH(default, set):Int = 2600;

	static function set_TRIANGLES_PER_BATCH(value:Int):Int
	{
		TRIANGLES_PER_BATCH = (value > MAX_TRIANGLES_PER_BUFFER) ? MAX_TRIANGLES_PER_BUFFER : value;
		return TRIANGLES_PER_BATCH;
	}

	
	/**
	 * The number of total draw calls in a frame.
	 */
	public static var totalDrawCalls:Int = 0;

	/**
	 * Creates a `FlxCameraView` object tied to a camera, based on the target and project configuration.
	 * @param camera The camera to create the view for
	 */
	public static inline function create(camera:FlxCamera):FlxCameraView
	{
		if (FlxG.renderBlit)
		{
			return cast new flixel.system.render.blit.FlxBlitView(camera);
		}
		else
		{
			#if FLX_RENDER_GL
			return cast new flixel.system.render.gl.FlxGLView(camera);
			#else
			return cast new flixel.system.render.quad.FlxQuadView(camera);
			#end
		}
	}
	
	/**
	 * Display object which is used as a container for all of the camera's graphics.
	 * This object is added to the display tree.
	 */
	public var display(get, never):DisplayObjectContainer;
	
	/**
	 * The parent camera for this view.
	 */
	public var camera(default, null):FlxCamera;
	
	/**
	 * A shortcut for `camera.antialiasing`. Used so implementations can listen to changes.
	 */
	public var antialiasing(get, set):Bool;

	/**
	 * A shortcut for `camera.angle`. Used so implementations can listen to changes.
	 */
	public var angle(get, set):Float;

	/**
	 * A shortcut for `camera.alpha`. Used so implementations can listen to changes.
	 */
	public var alpha(get, set):Float;

	/**
	 * A shortcut for `camera.color`. Used so implementations can listen to changes.
	 */
	public var color(get, set):FlxColor;

	/**
	 * A shortcut for `camera.visible`. Used so implementations can listen to changes.
	 */
	public var visible(get, set):Bool;
	
	var _flashOffset:FlxPoint = FlxPoint.get();
	
	function new(camera:FlxCamera)
	{
		this.camera = camera;
	}
	
	public function destroy():Void
	{
		_flashOffset = FlxDestroyUtil.put(_flashOffset);
	}

	/**
	 * Called prior to the rendering call, clears the screen and prepares everything needed.
	 */
	public function clear():Void {}

	/**
	 * The actual rendering call where everything gets drawn.
	 */
	public function render():Void {}
	
	// TODO ant unify FlxFrame and BitmapData somehow
	public function draw(?frame:FlxFrame, ?pixels:BitmapData, material:FlxMaterial, matrix:FlxMatrix, ?transform:ColorTransform):Void {}

	@:deprecated("drawPixels() is deprecated, use draw() instead")
	public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:FlxBlendMode, smoothing:Bool = false,
		?shader:FlxShader):Void {}

	// TODO ant unify FlxFrame and BitmapData somehow
	public function copy(?frame:FlxFrame, ?pixels:BitmapData, material:FlxMaterial, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform):Void {}

	@:deprecated("copyPixels() is deprecated, use copy() instead")
	public function copyPixels(?frame:FlxFrame, ?pixels:BitmapData, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform, ?blend:FlxBlendMode,
		smoothing:Bool = false, ?shader:FlxShader):Void {}
	
	// TODO ant rework triangles
	public function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>,
		?position:FlxPoint, ?blend:FlxBlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform, ?shader:FlxShader):Void {}
		
	public function beginDrawDebug():Void {}
	
	public function endDrawDebug(?matrix:FlxMatrix):Void {}
	
	public function drawDebugRect(x:Float, y:Float, width:Float, height:Float, color:FlxColor, thickness:Float = 1.0):Void {}
	
	public function drawDebugFilledRect(x:Float, y:Float, width:Float, height:Float, color:FlxColor):Void {}
	
	public function drawDebugFilledCircle(x:Float, y:Float, radius:Float, color:FlxColor):Void {}
	
	public function drawDebugLine(x1:Float, y1:Float, x2:Float, y2:Float, color:FlxColor, thickness:Float = 1.0):Void {}
	
	public function fill(color:FlxColor, blendAlpha:Bool = true):Void {}
	
	function drawFX():Void {}
	
	function updateScale():Void
	{
		camera.calcMarginX();
		camera.calcMarginY();
	}
	
	function updatePosition():Void {}
	
	function updateInternals():Void {}
	
	function updateOffset():Void
	{
		_flashOffset.x = camera.width * 0.5 * FlxG.scaleMode.scale.x * camera.initialZoom;
		_flashOffset.y = camera.height * 0.5 * FlxG.scaleMode.scale.y * camera.initialZoom;
	}
	
	public function offsetView(x:Float, y:Float):Void {}
	
	function updateScrollRect():Void {}
	
	/**
	 * Helper method preparing debug rectangle for rendering in blit render mode
	 * @param	rect	rectangle to prepare for rendering
	 * @return	transformed rectangle with respect to camera's zoom factor
	 */
	function transformRect(rect:FlxRect):FlxRect
	{
		return rect;
	}
	
	/**
	 * Helper method preparing debug point for rendering in blit render mode (for debug path rendering, for example)
	 * @param	point		point to prepare for rendering
	 * @return	transformed point with respect to camera's zoom factor
	 */
	function transformPoint(point:FlxPoint):FlxPoint
	{
		return point;
	}
	
	/**
	 * Helper method preparing debug vectors (relative positions) for rendering in blit render mode
	 * @param	vector	relative position to prepare for rendering
	 * @return	transformed vector with respect to camera's zoom factor
	 */
	function transformVector(vector:FlxPoint):FlxPoint
	{
		return vector;
	}
	
	/**
	 * Helper method for applying transformations (scaling and offsets)
	 * to specified display objects which has been added to the camera display list.
	 * For example, debug sprite for nape debug rendering.
	 * @param	object	display object to apply transformations to.
	 * @return	transformed object.
	 */
	function transformObject(object:DisplayObject):DisplayObject
	{
		object.scaleX *= camera.totalScaleX;
		object.scaleY *= camera.totalScaleY;
		
		object.x -= camera.scroll.x * camera.totalScaleX;
		object.y -= camera.scroll.y * camera.totalScaleY;
		
		object.x -= 0.5 * camera.width * (camera.scaleX - camera.initialZoom) * FlxG.scaleMode.scale.x;
		object.y -= 0.5 * camera.height * (camera.scaleY - camera.initialZoom) * FlxG.scaleMode.scale.y;
		
		return object;
	}
	
	function get_display():DisplayObjectContainer
	{
		return null;
	}
	
	function get_color():FlxColor
	{
		return camera.color;
	}
	
	function set_color(color:FlxColor):FlxColor
	{
		return color;
	}
	
	function get_antialiasing():Bool
	{
		return camera.antialiasing;
	}
	
	function set_antialiasing(antialiasing:Bool):Bool
	{
		return antialiasing;
	}
	
	function get_angle():Float
	{
		return camera.angle;
	}
	
	function set_angle(angle:Float):Float
	{
		return angle;
	}
	
	function get_visible():Bool
	{
		return camera.visible;
	}
	
	function set_visible(visible:Bool):Bool
	{
		return visible;
	}
	
	function get_alpha():Float
	{
		return camera.alpha;
	}
	
	function set_alpha(alpha:Float):Float
	{
		return alpha;
	}
}
