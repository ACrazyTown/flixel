package flixel;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.graphics.FlxTrianglesData;
import flixel.system.render.quad.FlxDrawTrianglesItem.DrawData;
import flixel.util.FlxDestroyUtil;

/**
 * A very basic rendering component which uses `drawTriangles()`.
 * You have access to `vertices`, `indices` and `uvtData` vectors which are used as data storages for rendering.
 * The whole `FlxGraphic` object is used as a texture for this sprite.
 * Use these links for more info about `drawTriangles()`:
 * @see http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/display/Graphics.html#drawTriangles%28%29
 * @see http://help.adobe.com/en_US/as3/dev/WS84753F1C-5ABE-40b1-A2E4-07D7349976C4.html
 * @see https://web.archive.org/web/20170620062159/http://www.flashandmath.com/advanced/p10triangles/index.html
 *
 * WARNING: This class is EXTREMELY slow on Flash!
 */
class FlxStrip extends FlxSprite
{
	public var data:FlxTrianglesData;

	/**
	 * A `Vector` of floats where each pair of numbers is treated as a coordinate location (an x, y pair).
	 */
	public var vertices(get, set):DrawData<Float>;
	inline function get_vertices():DrawData<Float> return data.vertices;
	inline function set_vertices(value:DrawData<Float>):DrawData<Float> return data.vertices = value;

	/**
	 * A `Vector` of integers or indexes, where every three indexes define a triangle.
	 */
	public var indices(get, set):DrawData<Int>;
	inline function get_indices():DrawData<Int> return data.indices;
	inline function set_indices(value:DrawData<Int>):DrawData<Int> return data.indices = value;

	/**
	 * A `Vector` of normalized coordinates used to apply texture mapping.
	 */
	public var uvtData(get, set):DrawData<Float>;
	inline function get_uvtData():DrawData<Float> return data.uvs;
	inline function set_uvtData(value:DrawData<Float>):DrawData<Float> return data.uvs = value;

	public var colors(get, set):DrawData<Int>;
	inline function get_colors():DrawData<Int> return data.colors;
	inline function set_colors(value:DrawData<Int>):DrawData<Int> return data.colors = value;

	@:deprecated("repeat is deprecated, use material.wrap instead.")
	public var repeat(get, set):Bool;
	inline function get_repeat():Bool return material.wrap.isRepeat();
	inline function set_repeat(value:Bool):Bool
	{
		material.wrap = value ? REPEAT(true, true) : null;
		return value;
	}

	public function new(x:Float = 0, y:Float = 0, ?graphic:FlxGraphicAsset)
	{
		super(x, y, graphic);
		data = new FlxTrianglesData();
	}

	override public function destroy():Void
	{
		super.destroy();

		data = FlxDestroyUtil.destroy(data);
	}

	// TODO: check this for cases when zoom is less than initial zoom...
	override public function draw():Void
	{
		if (alpha == 0 || vertices == null)
			return;

		final cameras = getCamerasLegacy();
		for (camera in cameras)
		{
			if (!camera.visible || !camera.exists)
				continue;

			_matrix.identity();
			_matrix.translate(-origin.x, -origin.y);
			_matrix.scale(scale.x, scale.y);

			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);

			_matrix.translate(origin.x, origin.y);

			getScreenPosition(_point, camera).subtract(offset);
			_matrix.translate(_point.x, _point.y);

			FlxG.renderer.begin(camera);
			FlxG.renderer.drawTriangles(graphic, data, material, _matrix, colorTransform);
		}
	}
}
