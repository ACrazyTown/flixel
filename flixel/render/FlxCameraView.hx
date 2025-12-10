package flixel.render;

import openfl.filters.BitmapFilter;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import openfl.display.Sprite;
import openfl.display.DisplayObjectContainer;
import flixel.util.FlxColor;
import flixel.math.FlxMatrix;
import flixel.graphics.tile.FlxDrawTrianglesItem;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.FlxGraphic;
import openfl.display.BlendMode;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.ColorTransform;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxSpriteUtil;
import flixel.math.FlxRect;
import openfl.display.DisplayObject;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;

class FlxCameraView implements IFlxDestroyable
{
    public static function create(camera:FlxCamera):FlxCameraView
    {
        // TODO: type
        return new flixel.render.tiles.FlxTilesView(camera);
    }

    public static var totalDrawCalls:Int = 0;

	public var display(get, never):DisplayObjectContainer;

    public var texture:Dynamic; // TODO FlxTexture
	public var antialiasing:Bool = false;
	public var angle:Float = 0;
	public var alpha:Float = 0;
	public var color:FlxColor;
	public var visible:Bool = true;
	public var filters:Array<BitmapFilter> = [];

	var _flashOffset:FlxPoint = FlxPoint.get();

	/**
	 * The margin cut off on the left and right by the camera zooming in (or out), in world space.
	 * @since 5.2.0
	 */
	public var viewMarginX(default, null):Float;

	/**
	 * The margin cut off on the top and bottom by the camera zooming in (or out), in world space.
	 * @since 5.2.0
	 */
	public var viewMarginY(default, null):Float;

	/**
	 * The margin cut off on the left by the camera zooming in (or out), in world space.
	 * @since 5.2.0
	 */
	public var viewMarginLeft(get, never):Float;

	/**
	 * The margin cut off on the top by the camera zooming in (or out), in world space
	 * @since 5.2.0
	 */
	public var viewMarginTop(get, never):Float;

	/**
	 * The margin cut off on the right by the camera zooming in (or out), in world space
	 * @since 5.2.0
	 */
	public var viewMarginRight(get, never):Float;

	/**
	 * The margin cut off on the bottom by the camera zooming in (or out), in world space
	 * @since 5.2.0
	 */
	public var viewMarginBottom(get, never):Float;

	/**
	 * The size of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewWidth(get, never):Float;

	/**
	 * The size of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewHeight(get, never):Float;

	/**
	 * The left of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewX(get, never):Float;

	/**
	 * The top of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewY(get, never):Float;

	/**
	 * The left of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewLeft(get, never):Float;

	/**
	 * The top of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewTop(get, never):Float;

	/**
	 * The right side of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewRight(get, never):Float;

	/**
	 * The bottom side of the camera's view, in world space.
	 * @since 5.2.0
	 */
	public var viewBottom(get, never):Float;

    /**
     * The parent camera for this view.
     */
    public var camera(default, null):FlxCamera;

    function new(camera:FlxCamera)
    {
        this.camera = camera;

        // flashSprite = new Sprite();
    }

	public function destroy():Void
	{
		_flashOffset = FlxDestroyUtil.put(_flashOffset);
	}

	//public function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false, ?shader:FlxShader) {}

	//public function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool, ?shader:FlxShader):FlxDrawTrianglesItem
    //    return null;

	//public function getNewDrawTrianglesItem(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool, ?shader:FlxShader):FlxDrawTrianglesItem
    //    return null;

    // @:deprecated
	//public function clearDrawStack():Void {}

    public function lock():Void {}

	public function render():Void {}

    public function unlock():Void {}

	public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, smoothing:Bool = false,
			?shader:FlxShader):Void {}

	public function copyPixels(?frame:FlxFrame, ?pixels:BitmapData, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform, ?blend:BlendMode,
			smoothing:Bool = false, ?shader:FlxShader):Void {}

	public function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>,
			?position:FlxPoint, ?blend:BlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform, ?shader:FlxShader):Void {}

	public function drawDebugRect(x:Float, y:Float, width:Float, height:Float, color:FlxColor, thickness:Float = 1.0):Void {}

	public function drawDebugFilledRect(x:Float, y:Float, width:Float, height:Float, color:FlxColor):Void {}

	public function drawDebugCircle(x:Float, y:Float, radius:Float, color:FlxColor):Void {}

	public function drawDebugLine(x1:Float, y1:Float, x2:Float, y2:Float, color:FlxColor, thickness:Float = 1.0):Void {}

    public function fill(color:FlxColor, alpha:Float = 1.0):Void {}

	public function updateScale():Void 
	{
		calcMarginX();
		calcMarginY();
	}

	public function updatePosition():Void {}
	public function updateInternals():Void {}

	public function updateOffset():Void 
	{
		_flashOffset.x = camera.width * 0.5 * FlxG.scaleMode.scale.x * camera.initialZoom;
		_flashOffset.y = camera.height * 0.5 * FlxG.scaleMode.scale.y * camera.initialZoom;
	}

	public function offsetView(x:Float, y:Float):Void {}

	public function updateScrollRect():Void {}

	/**
	 * Helper method for applying transformations (scaling and offsets)
	 * to specified display objects which has been added to the camera display list.
	 * For example, debug sprite for nape debug rendering.
	 * @param	object	display object to apply transformations to.
	 * @return	transformed object.
	 */
	public function transformObject(object:DisplayObject):DisplayObject
	{
		object.scaleX *= camera.totalScaleX;
		object.scaleY *= camera.totalScaleY;

		object.x -= camera.scroll.x * camera.totalScaleX;
		object.y -= camera.scroll.y * camera.totalScaleY;

		object.x -= 0.5 * camera.width * (camera.scaleX - camera.initialZoom) * FlxG.scaleMode.scale.x;
		object.y -= 0.5 * camera.height * (camera.scaleY - camera.initialZoom) * FlxG.scaleMode.scale.y;

		return object;
	}

	public inline function calcMarginX():Void
	{
		viewMarginX = 0.5 * camera.width * (camera.scaleX - camera.initialZoom) / camera.scaleX;
	}

	public inline function calcMarginY():Void
	{
		viewMarginY = 0.5 * camera.height * (camera.scaleY - camera.initialZoom) / camera.scaleY;
	}

	inline function get_viewMarginLeft():Float
	{
		return viewMarginX;
	}
	
	inline function get_viewMarginTop():Float
	{
		return viewMarginY;
	}
	
	inline function get_viewMarginRight():Float
	{
		return camera.width - viewMarginX;
	}
	
	inline function get_viewMarginBottom():Float
	{
		return camera.height - viewMarginY;
	}
	
	inline function get_viewWidth():Float
	{
		return camera.width - viewMarginX * 2;
	}
	
	inline function get_viewHeight():Float
	{
		return camera.height - viewMarginY * 2;
	}
	
	inline function get_viewX():Float
	{
		return camera.scroll.x + viewMarginX;
	}
	
	inline function get_viewY():Float
	{
		return camera.scroll.y + viewMarginY;
	}
	
	inline function get_viewLeft():Float
	{
		return viewX;
	}
	
	inline function get_viewTop():Float
	{
		return viewY;
	}
	
	inline function get_viewRight():Float
	{
		return camera.scroll.x + viewMarginRight;
	}
	
	inline function get_viewBottom():Float
	{
		return camera.scroll.y + viewMarginBottom;
	}

	function get_display():DisplayObjectContainer
	{
		return null;
	}
}
