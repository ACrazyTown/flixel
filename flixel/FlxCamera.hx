package flixel;

import flixel.render.FlxCameraView;
import flixel.render.context3d.FlxContext3DView;
import flixel.render.tiles.FlxTilesView;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSpriteUtil;
import openfl.Vector;
import openfl.display.BlendMode;
import openfl.filters.BitmapFilter;

using flixel.util.FlxColorTransformUtil;

/**
 * The camera class is used to display the game's visuals.
 * By default one camera is created automatically, that is the same size as window.
 * You can add more cameras or even replace the main camera using utilities in `FlxG.cameras`.
 *
 * Every camera has following display list:
 * `flashSprite:Sprite` (which is a container for everything else in the camera, it's added to FlxG.game sprite)
 *     |-> `_scrollRect:Sprite` (which is used for cropping camera's graphic, mostly in tile render mode)
 *         |-> `canvas:Sprite`        (its graphics is used for rendering objects in tile render mode)
 *         |-> `debugLayer:Sprite`    (this sprite is used in tile render mode for rendering debug info, like bounding boxes)
 */
class FlxCamera extends FlxBasic
{
	/**
	 * Any `FlxCamera` with a zoom of 0 (the default value) will have this zoom value.
	 */
	public static var defaultZoom:Float = 1.0;
	
	/**
	 * Used behind-the-scenes during the draw phase so that members use the same default
	 * cameras as their parent.
	 * 
	 * This is the non-deprecated list that the public `defaultCameras` proxies. Allows flixel classes
	 * to use it without warning.
	 */
	@:allow(flixel.FlxBasic.get_cameras)
	@:allow(flixel.FlxBasic.get_camera)
	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	@:allow(flixel.group.FlxTypedGroup.draw)
	static var _defaultCameras:Array<FlxCamera>;

	/**
	 * The `FlxCameraView` instance for this camera.
	 */
	public var view:FlxCameraView;

	/**
	 * A shortcut for `view`, but typed as `FlxContext3DView`.
	 * Will be `null` if this render method is not used.
	 */
	public var view3D:Null<FlxContext3DView> = null;

	/**
	 * A shortcut for `view`, but typed as `FlxTilesView`.
	 * Will be `null` if this render method is not used.
	 */
	@:deprecated("remove refs to viewTiles from flixel code !!!")
	public var viewTiles:Null<FlxTilesView> = null;

	/**
	 * The X position of this camera's display. `zoom` does NOT affect this number.
	 * Measured in pixels from the left side of the window.
	 * You might be interested in using camera's `scroll.x` instead.
	 */
	public var x(default, set):Float = 0;

	/**
	 * The Y position of this camera's display. `zoom` does NOT affect this number.
	 * Measured in pixels from the top of the window.
	 * You might be interested in using camera's `scroll.y` instead.
	 */
	public var y(default, set):Float = 0;

	/**
	 * The scaling on horizontal axis for this camera.
	 * Setting `scaleX` changes `scaleX` and x coordinate of camera's internal display objects.
	 */
	public var scaleX(default, null):Float = 0;

	/**
	 * The scaling on vertical axis for this camera.
	 * Setting `scaleY` changes `scaleY` and y coordinate of camera's internal display objects.
	 */
	public var scaleY(default, null):Float = 0;

	/**
	 * Product of camera's `scaleX` and game's scale mode `scale.x` multiplication.
	 */
	public var totalScaleX(default, null):Float;

	/**
	 * Product of camera's scaleY and game's scale mode scale.y multiplication.
	 */
	public var totalScaleY(default, null):Float;

	/**
	 * Tells the camera to use this following style.
	 */
	public var style:FlxCameraFollowStyle;

	/**
	 * Tells the camera to follow this FlxObject object around.
	 */
	public var target:FlxObject;

	/**
	 * Offset the camera target.
	 */
	public var targetOffset(default, null):FlxPoint = FlxPoint.get();

	/**
	 * The ratio of the distance to the follow `target` the camera moves per 1/60 sec.
	 * Valid values range from `0.0` to `1.0`. `1.0` means the camera always snaps to its target
	 * position. `0.5` means the camera always travels halfway to the target position, `0.0` means
	 * the camera does not move. Generally, the lower the value, the more smooth.
	 */
	public var followLerp:Float = 1.0;

	/**
	 * You can assign a "dead zone" to the camera in order to better control its movement.
	 * The camera will always keep the focus object inside the dead zone, unless it is bumping up against
	 * the camera bounds. The `deadzone`'s coordinates are measured from the camera's upper left corner in game pixels.
	 * For rapid prototyping, you can use the preset deadzones (e.g. `PLATFORMER`) with `follow()`.
	 */
	public var deadzone:FlxRect;

	/**
	 * Lower bound of the camera's `scroll` on the x axis.
	 */
	public var minScrollX:Null<Float>;

	/**
	 * Upper bound of the camera's `scroll` on the x axis.
	 */
	public var maxScrollX:Null<Float>;

	/**
	 * Lower bound of the camera's `scroll` on the y axis.
	 */
	public var minScrollY:Null<Float>;

	/**
	 * Upper bound of the camera's `scroll` on the y axis.
	 */
	public var maxScrollY:Null<Float>;

	/**
	 * Stores the basic parallax scrolling values.
	 * This is basically the camera's top-left corner position in world coordinates.
	 * There is also `focusOn(point:FlxPoint)` which you can use to
	 * make the camera look at specified point in world coordinates.
	 */
	public var scroll:FlxPoint = FlxPoint.get();

	/**
	 * The natural background color of the camera, in `AARRGGBB` format. Defaults to `FlxG.cameras.bgColor`.
	 * On Flash, transparent backgrounds can be used in conjunction with `useBgAlphaBlending`.
	 */
	public var bgColor:FlxColor;

	/**
	 * Whether the positions of the objects rendered on this camera are rounded.
	 * If set on individual objects, they ignore the global camera setting.
	 * Defaults to `false` with `FlxG.renderTile` and to `true` with `FlxG.renderBlit`.
	 * WARNING: setting this to `false` on blitting targets is very expensive.
	 */
	public var pixelPerfectRender:Bool;
	
	/**
	 * If true, screen shake will be rounded to game pixels. If null, pixelPerfectRender is used.
	 * @since 5.4.0
	 */
	public var pixelPerfectShake:Null<Bool> = null;

	/**
	 * How wide the camera display is, in game pixels.
	 */
	public var width(default, set):Int = 0;

	/**
	 * How tall the camera display is, in game pixels.
	 */
	public var height(default, set):Int = 0;

	/**
	 * The zoom level of this camera. `1` = 1:1, `2` = 2x zoom, etc.
	 * Indicates how far the camera is zoomed in.
	 * Note: Changing this property from it's initial value will change properties like:
	 * `viewX`, `viewY`, `viewWidth`, `viewHeight` and many others. Cameras always zoom in to
	 * their center, meaning as you zoom in, the view is cut off on all sides.
	 */
	public var zoom(default, set):Float;

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

	// delegates

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
	 * The alpha value of this camera display (a number between `0.0` and `1.0`).
	 */
	public var alpha(default, set):Float = 1;

	/**
	 * The angle of the camera display (in degrees).
	 */
	public var angle(default, set):Float = 0;

	/**
	 * The color tint of the camera display.
	 */
	public var color(default, set):FlxColor = FlxColor.WHITE;

	/**
	 * Whether the camera display is smooth and filtered, or chunky and pixelated.
	 * Default behavior is chunky-style.
	 */
	public var antialiasing(default, set):Bool = false;

	/**
	 * Used to force the camera to look ahead of the target.
	 */
	public var followLead(default, null):FlxPoint = FlxPoint.get();

	/**
	 * Enables or disables the filters set via the `filters` array.
	 */
	public var filtersEnabled:Bool = true;

	/**
	 * Internal, represents the color of `flash()` special effect.
	 */
	var _fxFlashColor:FlxColor = FlxColor.TRANSPARENT;

	/**
	 * Internal, stores `flash()` special effect duration.
	 */
	var _fxFlashDuration:Float = 0;

	/**
	 * Internal, camera's `flash()` complete callback.
	 */
	var _fxFlashComplete:Void->Void = null;

	/**
	 * Internal, used to control the `flash()` special effect.
	 */
	var _fxFlashAlpha:Float = 0;

	/**
	 * Internal, color of fading special effect.
	 */
	var _fxFadeColor:FlxColor = FlxColor.TRANSPARENT;

	/**
	 * Used to calculate the following target current velocity.
	 */
	var _lastTargetPosition:FlxPoint;

	/**
	 * Helper to calculate follow target current scroll.
	 */
	var _scrollTarget:FlxPoint = FlxPoint.get();

	/**
	 * Internal, `fade()` special effect duration.
	 */
	var _fxFadeDuration:Float = 0;

	/**
	 * Internal, "direction" of the `fade()` effect.
	 * `true` means that camera fades from a color, `false` - camera fades to it.
	 */
	var _fxFadeIn:Bool = false;

	/**
	 * Internal, used to control the `fade()` special effect complete callback.
	 */
	var _fxFadeComplete:Void->Void = null;

	/**
	 * Internal, alpha component of fade color.
	 * Changes from 0 to 1 or from 1 to 0 as the effect continues.
	 */
	var _fxFadeAlpha:Float = 0;

	/**
	 * Internal, percentage of screen size representing the maximum distance that the screen can move while shaking.
	 */
	var _fxShakeIntensity:Float = 0;

	/**
	 * Internal, duration of the `shake()` effect.
	 */
	var _fxShakeDuration:Float = 0;

	/**
	 * Internal, `shake()` effect complete callback.
	 */
	var _fxShakeComplete:Void->Void;

	/**
	 * Internal, defines on what axes to `shake()`. Default value is `XY` / both.
	 */
	var _fxShakeAxes:FlxAxes = XY;

	/**
	 * Internal, used for repetitive calculations and added to help avoid costly allocations.
	 */
	var _point:FlxPoint = FlxPoint.get();

	/**
	 * The filters array to be applied to the camera.
	 */
	public var filters(get, set):Null<Array<BitmapFilter>>;

	/**
	 * Camera's initial zoom value. Used for camera's scale handling.
	 */
	public var initialZoom(default, null):Float = 1;

	public function render():Void
	{
		if (view != null)
			view.render();
	}

	public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false,
			?shader:FlxShader):Void
	{
		if (view != null)
			view.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
	}

	public function copyPixels(?frame:FlxFrame, ?pixels:BitmapData, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform, ?blend:BlendMode,
			?smoothing:Bool = false, ?shader:FlxShader):Void
	{
		if (view != null)
			view.copyPixels(frame, pixels, sourceRect, destPoint, transform, blend, smoothing, shader);
	}

	public function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>,
			?position:FlxPoint, ?blend:BlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform, ?shader:FlxShader):Void
	{		
		if (view != null)
			view.drawTriangles(graphic, vertices, indices, uvtData, colors, position, blend, repeat, smoothing, transform, shader);
	}

	public function unlock():Void
	{
		if (view != null)
			view.unlock();
	}

	public function lock():Void
	{
		if (view != null)
			view.lock();
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
		if (view != null)
			return view.transformObject(object);

		return object;
	}

	/**
	 * Instantiates a new camera at the specified location, with the specified size and zoom level.
	 *
	 * @param   x       X location of the camera's display in pixels. Uses native, 1:1 resolution, ignores zoom.
	 * @param   y       Y location of the camera's display in pixels. Uses native, 1:1 resolution, ignores zoom.
	 * @param   width   The width of the camera display in pixels.
	 * @param   height  The height of the camera display in pixels.
	 * @param   zoom    The initial zoom level of the camera.
	 *                  A zoom level of 2 will make all pixels display at 2x resolution.
	 */
	public function new(x = 0.0, y = 0.0, width = 0, height = 0, zoom = 0.0)
	{
		super();

		this.x = x;
		this.y = y;

		if (zoom == 0)
			zoom = defaultZoom;
		
		// Use the game dimensions if width / height are <= 0
		if (width <= 0)
			width = Math.ceil(FlxG.width / zoom);
		if (height <= 0)
			height = Math.ceil(FlxG.height / zoom);
		
		this.width = width;
		this.height = height;

		view = FlxCameraView.create(this);
		if (view is FlxTilesView)
			viewTiles = cast view;
		if (view is FlxContext3DView)
			view3D = cast view;

		set_color(FlxColor.WHITE);
		
		// sets the scale of flash sprite, which in turn loads flashOffset values
		this.zoom = initialZoom = zoom;
		
		updateScrollRect();
		updateFlashOffset();
		updateViewPosition();
		updateInternalPositions();
		updateScale();

		bgColor = FlxG.cameras.bgColor;
	}

	/**
	 * Clean up memory.
	 */
	override public function destroy():Void
	{
		if (view != null)
			view.destroy();

		view = null;

		scroll = FlxDestroyUtil.put(scroll);
		targetOffset = FlxDestroyUtil.put(targetOffset);
		deadzone = FlxDestroyUtil.put(deadzone);

		target = null;
		_fxFlashComplete = null;
		_fxFadeComplete = null;
		_fxShakeComplete = null;

		super.destroy();
	}

	/**
	 * Updates the camera scroll as well as special effects like screen-shake or fades.
	 */
	override public function update(elapsed:Float):Void
	{
		// follow the target, if there is one
		if (target != null)
		{
			updateFollow();
			updateLerp(elapsed);
		}

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		updateViewPosition();
		updateShake(elapsed);
	}

	/**
	 * Updates (bounds) the camera scroll.
	 * Called every frame by camera's `update()` method.
	 */
	public function updateScroll():Void
	{
		// Make sure we didn't go outside the camera's bounds
		bindScrollPos(scroll);
	}
	
	/**
	 * Takes the desired scroll position and restricts it to the camera's min/max scroll properties.
	 * This modifies the given point.
	 * 
	 * @param   scrollPos  The scroll position
	 * @return  The same point passed in, moved within the scroll bounds
	 * @since 5.4.0
	 */
	public function bindScrollPos(scrollPos:FlxPoint)
	{
		final minX:Null<Float> = minScrollX == null ? null : minScrollX - viewMarginLeft;
		final maxX:Null<Float> = maxScrollX == null ? null : maxScrollX - viewMarginRight;
		final minY:Null<Float> = minScrollY == null ? null : minScrollY - viewMarginTop;
		final maxY:Null<Float> = maxScrollY == null ? null : maxScrollY - viewMarginBottom;

		// keep point within bounds
		scrollPos.x = FlxMath.bound(scrollPos.x, minX, maxX);
		scrollPos.y = FlxMath.bound(scrollPos.y, minY, maxY);
		return scrollPos;
	}

	/**
	 * Updates camera's scroll.
	 * Called every frame by camera's `update()` method (if camera's `target` isn't `null`).
	 */
	function updateFollow():Void
	{
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.add(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= viewRight)
				{
					_scrollTarget.x += viewWidth;
				}
				else if (targetX + target.width < viewLeft)
				{
					_scrollTarget.x -= viewWidth;
				}

				if (targetY >= viewBottom)
				{
					_scrollTarget.y += viewHeight;
				}
				else if (targetY + target.height < viewTop)
				{
					_scrollTarget.y -= viewHeight;
				}
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
				{
					_scrollTarget.x = edge;
				}
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
				{
					_scrollTarget.x = edge;
				}

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
				{
					_scrollTarget.y = edge;
				}
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
				{
					_scrollTarget.y = edge;
				}
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
				{
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				}
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}
	}
	
	function updateLerp(elapsed:Float)
	{
		if (followLerp >= 1.0)
		{
			scroll.copyFrom(_scrollTarget); // no easing
		}
		else if (followLerp > 0.0)
		{
			// Adjust lerp based on the current frame rate so lerp is less framerate dependant
			final adjustedLerp = 1.0 - Math.pow(1.0 - followLerp, elapsed * 60);
			
			scroll.x += (_scrollTarget.x - scroll.x) * adjustedLerp;
			scroll.y += (_scrollTarget.y - scroll.y) * adjustedLerp;
		}
	}

	function updateFlash(elapsed:Float):Void
	{
		// Update the "flash" special effect
		if (_fxFlashAlpha > 0.0)
		{
			_fxFlashAlpha -= elapsed / _fxFlashDuration;
			if ((_fxFlashAlpha <= 0) && (_fxFlashComplete != null))
			{
				_fxFlashComplete();
			}
		}
	}

	function updateFade(elapsed:Float):Void
	{
		if (_fxFadeDuration == 0.0)
			return;

		if (_fxFadeIn)
		{
			_fxFadeAlpha -= elapsed / _fxFadeDuration;
			if (_fxFadeAlpha <= 0.0)
			{
				_fxFadeAlpha = 0.0;
				completeFade();
			}
		}
		else
		{
			_fxFadeAlpha += elapsed / _fxFadeDuration;
			if (_fxFadeAlpha >= 1.0)
			{
				_fxFadeAlpha = 1.0;
				completeFade();
			}
		}
	}

	function completeFade()
	{
		_fxFadeDuration = 0.0;
		if (_fxFadeComplete != null)
			_fxFadeComplete();
	}

	// TODO!
	function updateShake(elapsed:Float):Void
	{
		if (_fxShakeDuration > 0)
		{
			_fxShakeDuration -= elapsed;
			if (_fxShakeDuration <= 0)
			{
				if (_fxShakeComplete != null)
				{
					_fxShakeComplete();
				}
			}
			else
			{
				final pixelPerfect = pixelPerfectShake == null ? pixelPerfectRender : pixelPerfectShake;
				if (_fxShakeAxes.x)
				{
					var shakePixels = FlxG.random.float(-1, 1) * _fxShakeIntensity * width;
					if (pixelPerfect)
						shakePixels = Math.round(shakePixels);
					
					viewTiles.flashSprite.x += shakePixels * zoom * FlxG.scaleMode.scale.x;
				}
				
				if (_fxShakeAxes.y)
				{
					var shakePixels = FlxG.random.float(-1, 1) * _fxShakeIntensity * height;
					if (pixelPerfect)
						shakePixels = Math.round(shakePixels);
					
					viewTiles.flashSprite.y += shakePixels * zoom * FlxG.scaleMode.scale.y;
				}
			}
		}
	}

	/**
	 * Recalculates `_flashOffset` point, which is used for positioning flashSprite in the game.
	 * It's called every time you resize the camera or the game.
	 */
	function updateFlashOffset():Void
	{
		if (view != null)
			view.updateOffset();
	}

	/**
	 * Updates `_scrollRect` sprite to crop graphics of the camera:
	 * 1) `scrollRect` property of this sprite
	 * 2) position of this sprite inside `flashSprite`
	 *
	 * It takes camera's size and game's scale into account.
	 * It's called every time you resize the camera or the game.
	 */
	function updateScrollRect():Void
	{
		if (view != null)
			view.updateScrollRect();
	}

	function updateInternalPositions():Void	
	{
		if (view != null)
			view.updateInternals();
	}

	/**
	 * Tells this camera object what `FlxObject` to track.
	 *
	 * @param   target   The object you want the camera to track. Set to `null` to not follow anything.
	 * @param   style    Leverage one of the existing "deadzone" presets. Default is `LOCKON`.
	 *                   If you use a custom deadzone, ignore this parameter and
	 *                   manually specify the deadzone after calling `follow()`.
	 * @param   lerp     How much lag the camera should have (can help smooth out the camera movement).
	 */
	public function follow(target:FlxObject, style = LOCKON, lerp = 1.0):Void
	{
		this.style = style;
		this.target = target;
		followLerp = lerp;
		_lastTargetPosition = FlxDestroyUtil.put(_lastTargetPosition);
		deadzone = FlxDestroyUtil.put(deadzone);

		switch (style)
		{
			case LOCKON:
				var w:Float = 0;
				var h:Float = 0;
				if (target != null)
				{
					w = target.width;
					h = target.height;
				}
				deadzone = FlxRect.get((width - w) / 2, (height - h) / 2 - h * 0.25, w, h);

			case PLATFORMER:
				final w:Float = (width / 8);
				final h:Float = (height / 3);
				deadzone = FlxRect.get((width - w) / 2, (height - h) / 2 - h * 0.25, w, h);

			case TOPDOWN:
				final helper = Math.max(width, height) / 4;
				deadzone = FlxRect.get((width - helper) / 2, (height - helper) / 2, helper, helper);

			case TOPDOWN_TIGHT:
				final helper = Math.max(width, height) / 8;
				deadzone = FlxRect.get((width - helper) / 2, (height - helper) / 2, helper, helper);

			case SCREEN_BY_SCREEN:
				deadzone = FlxRect.get(0, 0, width, height);

			case NO_DEAD_ZONE:
				deadzone = null;
		}
	}

	/**
	 * Snaps the camera to the current `target`. Useful to move the camera without
	 * any easing when the `target` position changes and there is a `followLerp`.
	 */
	public function snapToTarget():Void
	{
		updateFollow();
		scroll.copyFrom(_scrollTarget);
	}

	/**
	 * Move the camera focus to this location instantly.
	 *
	 * @param   Point   Where you want the camera to focus.
	 */
	public inline function focusOn(point:FlxPoint):Void
	{
		scroll.set(point.x - width * 0.5, point.y - height * 0.5);
		point.putWeak();
	}

	/**
	 * The screen is filled with this color and gradually returns to normal.
	 *
	 * @param   Color        The color you want to use.
	 * @param   Duration     How long it takes for the flash to fade.
	 * @param   OnComplete   A function you want to run when the flash finishes.
	 * @param   Force        Force the effect to reset.
	 */
	public function flash(Color:FlxColor = FlxColor.WHITE, Duration:Float = 1, ?OnComplete:Void->Void, Force:Bool = false):Void
	{
		if (!Force && (_fxFlashAlpha > 0.0))
			return;

		_fxFlashColor = Color;
		if (Duration <= 0)
			Duration = 0.000001;
		_fxFlashDuration = Duration;
		_fxFlashComplete = OnComplete;
		_fxFlashAlpha = 1.0;
	}

	/**
	 * The screen is gradually filled with this color.
	 *
	 * @param   Color        The color you want to use.
	 * @param   Duration     How long it takes for the fade to finish.
	 * @param   FadeIn       `true` fades from a color, `false` fades to it.
	 * @param   OnComplete   A function you want to run when the fade finishes.
	 * @param   Force        Force the effect to reset.
	 */
	public function fade(Color:FlxColor = FlxColor.BLACK, Duration:Float = 1, FadeIn:Bool = false, ?OnComplete:Void->Void, Force:Bool = false):Void
	{
		if (_fxFadeDuration > 0 && !Force)
			return;

		_fxFadeColor = Color;
		if (Duration <= 0)
			Duration = 0.000001;

		_fxFadeIn = FadeIn;
		_fxFadeDuration = Duration;
		_fxFadeComplete = OnComplete;

		_fxFadeAlpha = _fxFadeIn ? 0.999999 : 0.000001;
	}

	/**
	 * A simple screen-shake effect.
	 *
	 * @param   Intensity    Percentage of screen size representing the maximum distance
	 *                       that the screen can move while shaking.
	 * @param   Duration     The length in seconds that the shaking effect should last.
	 * @param   OnComplete   A function you want to run when the shake effect finishes.
	 * @param   Force        Force the effect to reset (default = `true`, unlike `flash()` and `fade()`!).
	 * @param   Axes         On what axes to shake. Default value is `FlxAxes.XY` / both.
	 */
	public function shake(Intensity:Float = 0.05, Duration:Float = 0.5, ?OnComplete:Void->Void, Force:Bool = true, ?Axes:FlxAxes):Void
	{
		if (Axes == null)
			Axes = XY;

		if (!Force && _fxShakeDuration > 0)
			return;

		_fxShakeIntensity = Intensity;
		_fxShakeDuration = Duration;
		_fxShakeComplete = OnComplete;
		_fxShakeAxes = Axes;
	}

	/**
	 * Stops the fade effect on `this` camera.
	 */
	public function stopFade():Void
	{
		_fxFadeAlpha = 0.0;
		_fxFadeDuration = 0.0;
	}

	/**
	 * Stops the flash effect on `this` camera.
	 */
	public function stopFlash():Void
	{
		_fxFlashAlpha = 0.0;
		// updateFlashSpritePosition(); TODO
	}

	/**
	 * Stops the shake effect on `this` camera.
	 */
	public function stopShake():Void
	{
		_fxShakeDuration = 0.0;
	}

	/**
	 * Stops all effects on `this` camera.
	 */
	public function stopFX():Void
	{
		_fxFadeAlpha = 0.0;
		_fxFadeDuration = 0.0;
		_fxFlashAlpha = 0.0;
		// updateFlashSpritePosition(); TODO
		_fxShakeDuration = 0.0;
	}

	/**
	 * Copy the bounds, focus object, and `deadzone` info from an existing camera.
	 *
	 * @param   Camera  The camera you want to copy from.
	 * @return  A reference to this `FlxCamera` object.
	 */
	public function copyFrom(Camera:FlxCamera):FlxCamera
	{
		setScrollBounds(Camera.minScrollX, Camera.maxScrollX, Camera.minScrollY, Camera.maxScrollY);

		target = Camera.target;

		if (target != null)
		{
			if (Camera.deadzone == null)
			{
				deadzone = null;
			}
			else
			{
				if (deadzone == null)
				{
					deadzone = FlxRect.get();
				}
				deadzone.copyFrom(Camera.deadzone);
			}
		}
		return this;
	}

	/**
	 * Fill the camera with the specified color.
	 *
	 * @param   Color        The color to fill with in `0xAARRGGBB` hex format.
	 * @param   BlendAlpha   Whether to blend the alpha value or just wipe the previous contents. Default is `true`.
	 */
	public function fill(color:FlxColor, blendAlpha:Bool = true, fxAlpha:Float = 1.0, ?graphics:Graphics):Void
	{
		if (view != null)
			view.fill(color, fxAlpha);
	}

	/**
	 * Internal helper function, handles the actual drawing of all the special effects.
	 */
	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	function drawFX():Void
	{
		// Draw the "flash" special effect onto the buffer
		if (_fxFlashAlpha > 0.0)
		{
			final alpha = _fxFlashColor.alphaFloat * _fxFlashAlpha;
			fill(_fxFlashColor.rgb, true, alpha, viewTiles.canvas.graphics);
		}
		
		// Draw the "fade" special effect onto the buffer
		if (_fxFadeAlpha > 0.0)
		{
			final alpha = _fxFadeColor.alphaFloat * _fxFadeAlpha;
			fill(_fxFadeColor.rgb, true, alpha, viewTiles.canvas.graphics);
		}
	}

	/**
	 * Shortcut for setting both `width` and `height`.
	 *
	 * @param   Width    The new camera width.
	 * @param   Height   The new camera height.
	 */
	public inline function setSize(Width:Int, Height:Int)
	{
		width = Width;
		height = Height;
	}

	/**
	 * Helper function to set the coordinates of this camera.
	 * Handy since it only requires one line of code.
	 *
	 * @param   X   The new x position.
	 * @param   Y   The new y position.
	 */
	public inline function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		x = X;
		y = Y;
	}

	/**
	 * Specify the bounding rectangle of where the camera is allowed to move.
	 *
	 * @param   X             The smallest X value of your level (usually `0`).
	 * @param   Y             The smallest Y value of your level (usually `0`).
	 * @param   Width         The largest X value of your level (usually the level width).
	 * @param   Height        The largest Y value of your level (usually the level height).
	 * @param   UpdateWorld   Whether the global quad-tree's dimensions should be updated to match (default: `false`).
	 */
	public function setScrollBoundsRect(X:Float = 0, Y:Float = 0, Width:Float = 0, Height:Float = 0, UpdateWorld:Bool = false):Void
	{
		if (UpdateWorld)
		{
			FlxG.worldBounds.set(X, Y, Width, Height);
		}

		setScrollBounds(X, X + Width, Y, Y + Height);
	}

	/**
	 * Specify the bounds of where the camera is allowed to move.
	 * Set the boundary of a side to `null` to leave that side unbounded.
	 *
	 * @param   MinX   The minimum X value the camera can scroll to
	 * @param   MaxX   The maximum X value the camera can scroll to
	 * @param   MinY   The minimum Y value the camera can scroll to
	 * @param   MaxY   The maximum Y value the camera can scroll to
	 */
	public function setScrollBounds(MinX:Null<Float>, MaxX:Null<Float>, MinY:Null<Float>, MaxY:Null<Float>):Void
	{
		minScrollX = MinX;
		maxScrollX = MaxX;
		minScrollY = MinY;
		maxScrollY = MaxY;
		updateScroll();
	}

	/**
	 * Helper function to set the scale of this camera.
	 * Handy since it only requires one line of code.
	 *
	 * @param   X   The new scale on x axis
	 * @param   Y   The new scale of y axis
	 */
	public function setScale(X:Float, Y:Float):Void
	{
		scaleX = X;
		scaleY = Y;

		totalScaleX = scaleX * FlxG.scaleMode.scale.x;
		totalScaleY = scaleY * FlxG.scaleMode.scale.y;

		updateScale();

		updateViewPosition();
		updateScrollRect();
		updateInternalPositions();

		FlxG.cameras.cameraResized.dispatch(this);
	}

	// TODO: move down
	function updateScale():Void
	{
		if (view != null)
			view.updateScale();
	}

	function updateViewPosition():Void
	{
		if (view != null)
			view.updatePosition();
	}

	/**
	 * Called by camera front end every time you resize the game.
	 * It triggers reposition of camera's internal display objects.
	 */
	public function onResize():Void
	{
		updateFlashOffset();
		setScale(scaleX, scaleY);
	}
	
	/**
	 * The size and position of this camera's margins, via `viewMarginLeft`, `viewMarginTop`, `viewWidth`
	 * and `viewHeight`.
	 * @since 5.2.0
	 */
	public function getViewMarginRect(?rect:FlxRect)
	{
		if (rect == null)
			rect = FlxRect.get();
		
		return rect.set(viewMarginLeft, viewMarginTop, viewWidth, viewHeight);
	}
	
	/**
	 * Checks whether this camera contains a given point or rectangle, in
	 * screen coordinates.
	 * @since 4.3.0
	 */
	public inline function containsPoint(point:FlxPoint, width:Float = 0, height:Float = 0):Bool
	{
		var contained = (point.x + width > viewMarginLeft) && (point.x < viewMarginRight)
			&& (point.y + height > viewMarginTop) && (point.y < viewMarginBottom);
		point.putWeak();
		return contained;
	}
	
	/**
	 * Checks whether this camera contains a given rectangle, in screen coordinates.
	 * @since 4.11.0
	 */
	public inline function containsRect(rect:FlxRect):Bool
	{
		var contained = (rect.right > viewMarginLeft) && (rect.x < viewMarginRight)
			&& (rect.bottom > viewMarginTop) && (rect.y < viewMarginBottom);
		rect.putWeak();
		return contained;
	}

	function set_width(Value:Int):Int
	{
		if (width != Value && Value > 0)
		{
			width = Value;

			view?.calcMarginX();

			updateFlashOffset();
			updateScrollRect();
			updateInternalPositions();

			FlxG.cameras.cameraResized.dispatch(this);
		}
		return Value;
	}

	function set_height(Value:Int):Int
	{
		if (height != Value && Value > 0)
		{
			height = Value;

			view?.calcMarginY();

			updateFlashOffset();
			updateScrollRect();
			updateInternalPositions();

			FlxG.cameras.cameraResized.dispatch(this);
		}
		return Value;
	}

	function set_zoom(Zoom:Float):Float
	{
		zoom = (Zoom == 0) ? defaultZoom : Zoom;
		setScale(zoom, zoom);
		return zoom;
	}

	function set_alpha(Alpha:Float):Float
	{
		alpha = FlxMath.bound(Alpha, 0, 1);
		if (view != null)
			view.alpha = Alpha;
		return Alpha;
	}

	function set_angle(Angle:Float):Float
	{
		angle = Angle;
		if (view != null)
			view.angle = Angle;
		return Angle;
	}

	// TODO
	function set_color(Color:FlxColor):FlxColor
	{
		color = Color;
		var colorTransform:ColorTransform;

		colorTransform = viewTiles.canvas.transform.colorTransform;

		colorTransform.redMultiplier = color.redFloat;
		colorTransform.greenMultiplier = color.greenFloat;
		colorTransform.blueMultiplier = color.blueFloat;

		// canvas.transform.colorTransform = colorTransform;

		if (view != null)
			view.color = Color;

		return Color;
	}

	function set_antialiasing(Antialiasing:Bool):Bool
	{
		antialiasing = Antialiasing;
		
		if (view != null)
			view.antialiasing = Antialiasing;

		return Antialiasing;
	}

	function set_x(x:Float):Float
	{
		this.x = x;
		// updateFlashSpritePosition();
		updateViewPosition();
		return x;
	}

	function set_y(y:Float):Float
	{
		this.y = y;
		// updateFlashSpritePosition();
		updateViewPosition();
		return y;
	}

	override function set_visible(visible:Bool):Bool
	{
		if (view != null)
			view.visible = visible;

		return this.visible = visible;
	}
	
	static inline function get_defaultCameras():Array<FlxCamera>
	{
		return _defaultCameras;
	}
	
	static inline function set_defaultCameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		return _defaultCameras = value;
	}
	
	inline function get_viewMarginLeft():Float
	{
		return view?.viewMarginLeft;
	}
	
	inline function get_viewMarginTop():Float
	{
		return view?.viewMarginTop;
	}
	
	inline function get_viewMarginRight():Float
	{
		return view?.viewMarginRight;
	}
	
	inline function get_viewMarginBottom():Float
	{
		return view?.viewMarginBottom;
	}
	
	inline function get_viewWidth():Float
	{
		return view?.viewWidth;
	}
	
	inline function get_viewHeight():Float
	{
		return view?.viewHeight;
	}
	
	inline function get_viewX():Float
	{
		return view?.viewX;
	}
	
	inline function get_viewY():Float
	{
		return view?.viewY;
	}
	
	inline function get_viewLeft():Float
	{
		return view?.viewLeft;
	}
	
	inline function get_viewTop():Float
	{
		return view?.viewTop;
	}
	
	inline function get_viewRight():Float
	{
		return view?.viewRight;
	}
	
	inline function get_viewBottom():Float
	{
		return view?.viewBottom;
	}
	
	function get_filters():Null<Array<BitmapFilter>> 
	{
		if (view != null)
			return view.filters;

		return null;
	}

	function set_filters(filters:Null<Array<BitmapFilter>>):Null<Array<BitmapFilter>> 
	{
		if (view != null)
			return view.filters = filters;
		
		return null;
	}

	/**
	 * Do not use the following fields! They only exists because FlxCamera extends FlxBasic,
	 * we're hiding them because they've only caused confusion.
	 */
	@:deprecated("don't reference camera.camera")
	@:noCompletion
	override function get_camera():FlxCamera throw "don't reference camera.camera";
	
	@:deprecated("don't reference camera.camera")
	@:noCompletion
	override function set_camera(value:FlxCamera):FlxCamera throw "don't reference camera.camera";
	
	@:deprecated("don't reference camera.cameras")
	@:noCompletion
	override function get_cameras():Array<FlxCamera> throw "don't reference camera.cameras";
	
	@:deprecated("don't reference camera.cameras")
	@:noCompletion
	override function set_cameras(value:Array<FlxCamera>):Array<FlxCamera> throw "don't reference camera.cameras";
}

enum FlxCameraFollowStyle
{
	/**
	 * Camera has no deadzone, just tracks the focus object directly.
	 */
	LOCKON;

	/**
	 * Camera's deadzone is narrow but tall.
	 */
	PLATFORMER;

	/**
	 * Camera's deadzone is a medium-size square around the focus object.
	 */
	TOPDOWN;

	/**
	 * Camera's deadzone is a small square around the focus object.
	 */
	TOPDOWN_TIGHT;

	/**
	 * Camera will move screenwise.
	 */
	SCREEN_BY_SCREEN;

	/**
	 * Camera has no deadzone, just tracks the focus object directly and centers it.
	 */
	NO_DEAD_ZONE;
}
