package flixel.render.tiles;

import flixel.math.FlxPoint;
import openfl.geom.Point;
import flixel.graphics.frames.FlxFrame;
import openfl.display.BitmapData;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.util.FlxDestroyUtil;
import openfl.display.DisplayObjectContainer;
import openfl.geom.Rectangle;
import flixel.util.FlxColor;
import openfl.display.Sprite;
import openfl.display.Sprite;
import flixel.render.FlxCameraView;

import flixel.graphics.FlxGraphic;
import openfl.display.BlendMode;
import flixel.system.FlxAssets.FlxShader;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;
import openfl.geom.ColorTransform;
import openfl.Vector;
import flixel.math.FlxRect;

using flixel.util.FlxColorTransformUtil;

class FlxTilesView extends FlxCameraView
{
    public var flashSprite:Sprite;
    public var canvas:Sprite;
    public var debugLayer:Sprite;

    var _scrollRect:Sprite;

    var _helperMatrix:FlxMatrix = new FlxMatrix();
	var _helperPoint:Point = new Point();
	var _currentDrawItem:FlxDrawBaseItem<Dynamic>;
	var _headOfDrawStack:FlxDrawBaseItem<Dynamic>;
	var _headTiles:FlxDrawQuadsItem;
	var _headTriangles:FlxDrawTrianglesItem;
	var _bounds:FlxRect = FlxRect.get();
	static var _storageTilesHead:FlxDrawQuadsItem;
	static var _storageTrianglesHead:FlxDrawTrianglesItem;
	static var drawVertices:Vector<Float> = new Vector<Float>();
	static var renderRect:FlxRect = FlxRect.get();

    public function new(camera:FlxCamera)
    {
        super(camera);

        _scrollRect = new Sprite();
		_scrollRect.scrollRect = new Rectangle();

        flashSprite = new Sprite();
        flashSprite.addChild(_scrollRect);

		canvas = new Sprite();
		_scrollRect.addChild(canvas);

		#if FLX_DEBUG
		debugLayer = new Sprite();
		_scrollRect.addChild(debugLayer);
		#end
    }

    override public function destroy():Void
    {
        super.destroy();

        FlxDestroyUtil.removeChild(flashSprite, _scrollRect);

		#if FLX_DEBUG
		FlxDestroyUtil.removeChild(_scrollRect, debugLayer);
		debugLayer = null;
		#end

		FlxDestroyUtil.removeChild(_scrollRect, canvas);
		if (canvas != null)
		{
			for (i in 0...canvas.numChildren)
			{
				canvas.removeChildAt(0);
			}
			canvas = null;
		}

		if (_headOfDrawStack != null)
		{
			clearDrawStack();
		}

		flashSprite = null;
		_scrollRect = null;
        _helperMatrix = null;
		_helperPoint = null;
        _bounds = FlxDestroyUtil.put(_bounds);
    }

    override public function lock():Void
    {
        clearDrawStack();

        canvas.graphics.clear();
        #if FLX_DEBUG
        debugLayer.graphics.clear();
        #end

        fill(camera.bgColor.rgb, camera.bgColor.alphaFloat);
    }

    override public function render():Void
	{
		flashSprite.filters = camera.filtersEnabled ? filters : null;
		
		var currItem:FlxDrawBaseItem<Dynamic> = _headOfDrawStack;
		while (currItem != null)
		{
			currItem.render(camera);
			currItem = currItem.next;
		}
	}

    override public function unlock():Void
    {
        drawFX();
    }

    override public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, smoothing:Bool = false, ?shader:FlxShader):Void 
    {
        var isColored = (transform != null #if !html5 && transform.hasRGBMultipliers() #end);
		var hasColorOffsets:Bool = (transform != null && transform.hasRGBAOffsets());

		#if FLX_RENDER_TRIANGLE
		final drawItem:FlxDrawTrianglesItem = startTrianglesBatch(frame.parent, smoothing, isColored, blend, hasColorOffsets, shader);
		#else
		final drawItem:FlxDrawQuadsItem = startQuadBatch(frame.parent, isColored, hasColorOffsets, blend, smoothing, shader);
		#end
		drawItem.addQuad(frame, matrix, transform);
    }

    override function copyPixels(?frame:FlxFrame, ?pixels:BitmapData, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform, ?blend:BlendMode, smoothing:Bool = false, ?shader:FlxShader) 
    {
        _helperMatrix.identity();
		_helperMatrix.translate(destPoint.x + frame.offset.x, destPoint.y + frame.offset.y);

		var isColored = (transform != null && transform.hasRGBMultipliers());
		var hasColorOffsets:Bool = (transform != null && transform.hasRGBAOffsets());

		#if FLX_RENDER_TRIANGLE
		final drawItem:FlxDrawTrianglesItem = startTrianglesBatch(frame.parent, smoothing, isColored, blend, hasColorOffsets, shader);
		#else
		final drawItem:FlxDrawQuadsItem = startQuadBatch(frame.parent, isColored, hasColorOffsets, blend, smoothing, shader);
		#end
		drawItem.addQuad(frame, _helperMatrix, transform);
    }

    override function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>, ?position:FlxPoint, ?blend:BlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform, ?shader:FlxShader) 
    {
        final cameraBounds = _bounds.set(viewMarginLeft, viewMarginTop, viewWidth, viewHeight);
		
		final isColored = (colors != null && colors.length != 0) || (transform != null && transform.hasRGBMultipliers());
		final hasColorOffsets = (transform != null && transform.hasRGBAOffsets());

		final drawItem = startTrianglesBatch(graphic, smoothing, isColored, blend, hasColorOffsets, shader);
		drawItem.addTriangles(vertices, indices, uvtData, colors, position, cameraBounds, transform);
    }

    override public function fill(color:FlxColor, fxAlpha:Float = 1.0):Void
    {
        final targetGraphics = canvas.graphics; //(graphics == null) ? canvas.graphics : graphics;

        targetGraphics.overrideBlendMode(null);
        targetGraphics.beginFill(color, fxAlpha);
        // i'm drawing rect with these parameters to avoid light lines at the top and left of the camera,
        // which could appear while cameras fading
        targetGraphics.drawRect(viewMarginLeft - 1, viewMarginTop - 1, viewWidth + 2, viewHeight + 2);
        targetGraphics.endFill();
    }

    override public function updatePosition():Void
    {
        if (flashSprite != null)
		{
			flashSprite.x = camera.x * FlxG.scaleMode.scale.x + _flashOffset.x;
			flashSprite.y = camera.y * FlxG.scaleMode.scale.y + _flashOffset.y;
		}
    }

    override public function updateScrollRect():Void
    {
        var rect:Rectangle = (_scrollRect != null) ? _scrollRect.scrollRect : null;

		if (rect != null)
		{
			rect.x = rect.y = 0;

			rect.width = camera.width * camera.initialZoom * FlxG.scaleMode.scale.x;
			rect.height = camera.height * camera.initialZoom * FlxG.scaleMode.scale.y;

			_scrollRect.scrollRect = rect;

			_scrollRect.x = -0.5 * rect.width;
			_scrollRect.y = -0.5 * rect.height;
		}
    }

    override public function updateInternals():Void
    {
        if (canvas != null)
		{
			canvas.x = -0.5 * camera.width * (camera.scaleX - camera.initialZoom) * FlxG.scaleMode.scale.x;
			canvas.y = -0.5 * camera.height * (camera.scaleY - camera.initialZoom) * FlxG.scaleMode.scale.y;

			canvas.scaleX = camera.totalScaleX;
			canvas.scaleY = camera.totalScaleY;

			#if FLX_DEBUG
			if (debugLayer != null)
			{
				debugLayer.x = canvas.x;
				debugLayer.y = canvas.y;

				debugLayer.scaleX = camera.totalScaleX;
				debugLayer.scaleY = camera.totalScaleY;
			}
			#end
		}
    }

    override function get_display():DisplayObjectContainer
    {
        return flashSprite;
    }

    // TEMP OLD TILES STUFF
    @:noCompletion
    @:deprecated
	public function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false, ?shader:FlxShader)
	{
		#if FLX_RENDER_TRIANGLE
		return startTrianglesBatch(graphic, smooth, colored, blend);
		#else
		var itemToReturn = null;

		if (_currentDrawItem != null
			&& _currentDrawItem.type == FlxDrawItemType.TILES
			&& _headTiles.graphics == graphic
			&& _headTiles.colored == colored
			&& _headTiles.hasColorOffsets == hasColorOffsets
			&& _headTiles.blend == blend
			&& _headTiles.antialiasing == smooth
			&& _headTiles.shader == shader)
		{
			return _headTiles;
		}

		if (_storageTilesHead != null)
		{
			itemToReturn = _storageTilesHead;
			var newHead = _storageTilesHead.nextTyped;
			itemToReturn.reset();
			_storageTilesHead = newHead;
		}
		else
		{
			itemToReturn = new FlxDrawQuadsItem();
		}
		
		// TODO: catch this error when the dev actually messes up, not in the draw phase
		if (graphic.isDestroyed)
			throw 'Cannot queue ${graphic.key}. This sprite was destroyed.';

		itemToReturn.graphics = graphic;
		itemToReturn.antialiasing = smooth;
		itemToReturn.colored = colored;
		itemToReturn.hasColorOffsets = hasColorOffsets;
		itemToReturn.blend = blend;
		itemToReturn.shader = shader;

		itemToReturn.nextTyped = _headTiles;
		_headTiles = itemToReturn;

		if (_headOfDrawStack == null)
		{
			_headOfDrawStack = itemToReturn;
		}

		if (_currentDrawItem != null)
		{
			_currentDrawItem.next = itemToReturn;
		}

		_currentDrawItem = itemToReturn;

		return itemToReturn;
		#end
	}

	@:noCompletion
    @:deprecated
	public function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool, ?shader:FlxShader):FlxDrawTrianglesItem
	{
		if (_currentDrawItem != null
			&& _currentDrawItem.type == FlxDrawItemType.TRIANGLES
			&& _headTriangles.graphics == graphic
			&& _headTriangles.antialiasing == smoothing
			&& _headTriangles.colored == isColored
			&& _headTriangles.blend == blend
			&& _headTriangles.hasColorOffsets == hasColorOffsets
			&& _headTriangles.shader == shader
			)
		{
			return _headTriangles;
		}

		return getNewDrawTrianglesItem(graphic, smoothing, isColored, blend, hasColorOffsets, shader);
	}

	@:noCompletion
    @:deprecated
	public function getNewDrawTrianglesItem(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool, ?shader:FlxShader):FlxDrawTrianglesItem
	{
		var itemToReturn:FlxDrawTrianglesItem = null;

		if (_storageTrianglesHead != null)
		{
			itemToReturn = _storageTrianglesHead;
			var newHead:FlxDrawTrianglesItem = _storageTrianglesHead.nextTyped;
			itemToReturn.reset();
			_storageTrianglesHead = newHead;
		}
		else
		{
			itemToReturn = new FlxDrawTrianglesItem();
		}

		itemToReturn.graphics = graphic;
		itemToReturn.antialiasing = smoothing;
		itemToReturn.colored = isColored;
		itemToReturn.blend = blend;
		itemToReturn.hasColorOffsets = hasColorOffsets;
		itemToReturn.shader = shader;

		itemToReturn.nextTyped = _headTriangles;
		_headTriangles = itemToReturn;

		if (_headOfDrawStack == null)
		{
			_headOfDrawStack = itemToReturn;
		}

		if (_currentDrawItem != null)
		{
			_currentDrawItem.next = itemToReturn;
		}

		_currentDrawItem = itemToReturn;

		return itemToReturn;
	}

	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	function clearDrawStack():Void
	{
		var currTiles = _headTiles;
		var newTilesHead;

		while (currTiles != null)
		{
			newTilesHead = currTiles.nextTyped;
			currTiles.reset();
			currTiles.nextTyped = _storageTilesHead;
			_storageTilesHead = currTiles;
			currTiles = newTilesHead;
		}

		var currTriangles:FlxDrawTrianglesItem = _headTriangles;
		var newTrianglesHead:FlxDrawTrianglesItem;

		while (currTriangles != null)
		{
			newTrianglesHead = currTriangles.nextTyped;
			currTriangles.reset();
			currTriangles.nextTyped = _storageTrianglesHead;
			_storageTrianglesHead = currTriangles;
			currTriangles = newTrianglesHead;
		}

		_currentDrawItem = null;
		_headOfDrawStack = null;
		_headTiles = null;
		_headTriangles = null;
	}
}
