package flixel.system.render.quad;

import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxGraphic;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.system.render.FlxRenderer;
import flixel.math.FlxMatrix;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

// TODO: Make these extend FlxDrawCommand
/**
 * @author Zaphod
 */
class FlxDrawBaseItem<T>
{
	/**
	 * Tracks the total number of draw calls made each frame.
	 */
	@:deprecated("drawCalls is deprecated, use FlxRenderer.totalDrawCalls instead")
	public static var drawCalls(get, set):Int;

	static function set_drawCalls(value:Int):Int
	{
		return FlxRenderer.totalDrawCalls = value;
	}

	static function get_drawCalls():Int
	{
		return FlxRenderer.totalDrawCalls;
	}

	@:noCompletion
	@:deprecated("blendToInt() is deprecated, remove all references to it")
	public static function blendToInt(blend:BlendMode):Int
	{
		return 0; // no blend mode support in drawQuads()
	}

	public var nextTyped:T;

	public var next:FlxDrawBaseItem<T>;

	public var graphics:FlxGraphic;
	public var material:FlxMaterial;

	@:deprecated("antialiasing is deprecated, use material.smoothing instead.")
	public var antialiasing(get, set):Bool;
	@:noCompletion inline function get_antialiasing():Bool
	{
		return material.smoothing;
	}
	@:noCompletion inline function set_antialiasing(value:Bool):Bool
	{
		return material.smoothing = value;
	}

	@:deprecated("blend is deprecated, use material.blendMode instead.")
	public var blend(get, set):BlendMode;
	@:noCompletion inline function get_blend():BlendMode 
	{
		return material.blendMode;
	}
	@:noCompletion inline function set_blend(value:BlendMode):BlendMode
	{
		return material.blendMode = value;
	}

	public var colored:Bool = false;
	public var hasColorOffsets:Bool = false;

	@:noCompletion
	@:deprecated("blending is deprecated, remove all references to it")
	public var blending:Int = 0;

	public var type:FlxDrawItemType;

	public var numVertices(get, never):Int;

	public var numTriangles(get, never):Int;

	public function new() {}

	public function reset():Void
	{
		material = null;
		graphics = null;
		nextTyped = null;
		next = null;
	}

	public function dispose():Void
	{
		material = null;
		graphics = null;
		next = null;
		type = null;
		nextTyped = null;
	}

	public function render(camera:FlxCamera):Void
	{
		FlxRenderer.totalDrawCalls++;
	}

	public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform):Void {}

	function get_numVertices():Int
	{
		return 0;
	}

	function get_numTriangles():Int
	{
		return 0;
	}
}

enum FlxDrawItemType
{
	TILES;
	TRIANGLES;
}
