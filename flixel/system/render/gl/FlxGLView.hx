package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import lime.graphics.opengl.GL;
import flixel.graphics.FlxRenderTexture;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import flixel.system.render.gl.FlxDrawData;
import flixel.system.render.quad.FlxDrawTrianglesItem.DrawData;
import flixel.util.FlxColor;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import openfl.geom.Point;

using flixel.util.FlxColorTransformUtil;

@:access(flixel.FlxCamera)
class FlxGLView extends FlxCameraView
{
    /**
     * Whether this view needs to be rendered (there's sprites queued to be drawn).
     */
    public var needsRender(get, never):Bool;
    inline function get_needsRender():Bool
        return _drawQueue.length > 0 || camera._fxFadeAlpha > 0 || camera._fxFlashAlpha > 0; // TODO: better way to check if there's pending FX?

	/**
	 * Checks whether `_renderMatrix` should be applied to sprites.
	 * True only if `camera.zoom != camera.initialZoom`.
	 */
	var _useRenderMatrix(get, never):Bool;
	
	inline function get__useRenderMatrix():Bool
		return camera.zoom != camera.initialZoom;
		
	/**
	 * Helper matrix applied to all sprites when `camera.zoom != camera.initialZoom`.
	 * Used to scale sprites according to the camera zoom.
	 */
    var _renderMatrix:FlxMatrix = new FlxMatrix();

    public var renderTextureQuad:FlxQuadDrawData;
    var renderTextureFrame:FlxFrame;
    var renderTextureGraphic:FlxGraphic;
    var renderTexture:FlxRenderTexture;
	var _scaleX:Float;
	var _scaleY:Float;
	var _offsetX:Float;
	var _offsetY:Float;

    /**
     * An array containing the draw data for all the sprites drawn to this camera.
     * 
     * The view's draw methods only push data to the queue. When the camera renders, the data
     * from this array is sent to the batcher which will figure out the most optimal way to draw them.
     */
    var _drawQueue:Array<FlxDrawData> = [];

    var _renderer(get, never):FlxGLRenderer;
	inline function get__renderer() return cast (FlxG.renderer, FlxGLRenderer);

    public function new(camera:FlxCamera)
    {
        super(camera);

        renderTexture = new FlxRenderTexture(camera.width, camera.height, true);
        
        // TODO ant: bruh
        @:privateAccess 
        renderTextureGraphic = new FlxGraphic(null, renderTexture);
        renderTextureFrame = renderTextureGraphic.imageFrame.frame;

        renderTextureQuad = FlxQuadDrawData.get(renderTextureFrame, antialiasing, false, null, null, null, null);
    }

    // =============================================================================
	//{ region                         RENDERING
	// =============================================================================

    override function destroy():Void
    {
        super.destroy();
    }

    // To avoid redundant framebuffer swaps we won't actually clear here, and we'll do it
    // at the beginning of render() instead. When we do it doesn't matter as long as it's before drawing.
    override function clear() 
    {
        _drawQueue.resize(0);
        fill(camera.bgColor);
    }

    override function render()
    {
        if (!needsRender)
            return;

        // Switch to rendering on the camera's texture
        _renderer.setRenderTexture(renderTexture);
        renderTexture.clear(0);

        camera.drawFX();

        // Submit all the collected sprites to the batcher
        for (data in _drawQueue)
            _renderer.batcher.add(data);

        // Force a flush to draw whatever was left in the buffer
        _renderer.batcher.flush();
    }

    override function fill(color:FlxColor, blendAlpha:Bool = true)
	{
        // super.fill(color, blendAlpha);
        // TODO: support !blendAlpha via glClear?

        if (color.alphaFloat == 0)
            return;

		final frame = FlxG.bitmap.whitePixel;
        final quad = FlxQuadDrawData.get(frame, false, false, null, null, FlxColor.fromRGB(0, 0, 0, color.alpha), color.rgb, null);

        frame.prepareMatrix(quad.matrix);
        quad.matrix.scale(camera.width, camera.height);

        _drawQueue.push(quad);
	}
	
	override function drawPixels(pixels, matrix, ?transform, ?blend, smoothing = false, ?shader)
	{
		// super.drawPixels(frame, matrix, transform, blend, smoothing, shader);
		throw "Not implemented";
	}
	
	override function copyPixels(pixels, ?sourceRect, destPoint, ?transform, ?blend, smoothing = false, ?shader)
	{
		// super.copyPixels(pixels, sourceRect, destPoint, transform, blend, smoothing, shader);
		throw "Not implemented";
	}
	
	override function drawFrame(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, smoothing = false, ?shader)
	{
		// super.drawFrame(frame, matrix, transform, blend, smoothing, shader);
        frame.parent.texture.applyIfNeeded();

        if (_useRenderMatrix)
            matrix.concat(_renderMatrix);

        // Queue a quad to be drawn when the camera renders
        var quad = FlxQuadDrawData.get(frame, (antialiasing || smoothing), false, shader, blend, transform, matrix);
        _drawQueue.push(quad);
	}
	
	override function copyFrame(frame:FlxFrame, destPoint:Point, ?transform:ColorTransform, ?blend:BlendMode, smoothing = false, ?shader:FlxShader)
	{
		// super.copyFrame(frame, destPoint, transform, blend, smoothing, shader);
        frame.parent.texture.applyIfNeeded();

        // Queue a quad to be drawn when the camera renders
        var quad = FlxQuadDrawData.get(frame, (antialiasing || smoothing), false, shader, blend, transform, null);
        quad.matrix.tx = destPoint.x;
        quad.matrix.ty = destPoint.y;
        if (_useRenderMatrix)
            quad.matrix.concat(_renderMatrix);
        _drawQueue.push(quad);
	}
	
	override function drawTriangles(graphic:FlxGraphic, vertices:FlxVector2d<Float>, indices:FlxVector2d<Int>, uvtData:FlxVector2d<Float>, ?colors:FlxVector2d<Int>,
			?position:FlxPoint, ?blend:BlendMode, repeat = false, smoothing = false, ?transform:ColorTransform, ?shader:FlxShader)
	{
		// super.drawTriangles(graphic, vertices, indices, uvtData, colors, position, blend, repeat, smoothing, transform, shader);

        // TODO: matrix support
        var triangle = FlxTrianglesDrawData.get(vertices, indices, uvtData, colors, graphic, (antialiasing || smoothing), repeat, shader, blend, transform, null);
        triangle.matrix.tx = position.x;
        triangle.matrix.ty = position.y;
        if (_useRenderMatrix)
            triangle.matrix.concat(_renderMatrix);
        _drawQueue.push(triangle);
	}

    // =============================================================================
	//} endregion                      RENDERING
	// =============================================================================

    // =============================================================================
	//{ region                            DEBUG DRAW
	// =============================================================================

    public function beginDrawDebug():Void {}

	public function endDrawDebug():Void {}

    #if FLX_DEBUG
	public function getDebugBuffer():FlxCanvas { return null; }
	
	function worldToDebugX(worldX:Float):Float
    {
        //TODO: find out what "debug space" actually is, rename and make public
        return worldX;
    }

	function worldToDebugY(worldY:Float):Float
    {
        //TODO: find out what "debug space" actually is, rename and make public
        return worldY;
    }
	#end

    // =============================================================================
	//} endregion                         DEBUG DRAW
	// =============================================================================

    // =============================================================================
	//{ region                             HELPERS
	// =============================================================================

	/**
	 * Returns the `FlxQuadDrawData` for the camera's texture, while also updating its matrix.
	 */
	public inline function getDrawData():FlxQuadDrawData
	{
		final matrix = renderTextureQuad.matrix;
		
		matrix.identity();
		matrix.scale(FlxG.scaleMode.scale.x * camera.initialZoom, FlxG.scaleMode.scale.y * camera.initialZoom);
		matrix.translate(FlxG.game.x + camera.x * FlxG.scaleMode.scale.x + _offsetX, FlxG.game.y + camera.y * FlxG.scaleMode.scale.y + _offsetY);
		
		return renderTextureQuad;
	}
	
	public function offsetView(x:Float, y:Float):Void
	{
		_offsetX += x;
		_offsetY += y;
	}

	function updateInternals():Void {}

    function updateOffset():Void {}

	function updatePosition():Void
	{
        _offsetX = 0;
        _offsetY = 0;
	}
    
    function updateScale():Void 
    {
		if (_useRenderMatrix)
			updateRenderMatrix();
    }

    function updateScrollRect():Void {}

    inline function updateRenderMatrix():Void
	{
		_renderMatrix.identity();
		_renderMatrix.translate(-camera.viewMarginLeft, -camera.viewMarginTop);
		_renderMatrix.scale(camera.scaleX, camera.scaleY);
    }

    // =============================================================================
	//} endregion                          HELPERS
	// =============================================================================

    // =============================================================================
	//{ region                             GETTERS
	// =============================================================================

    override function set_antialiasing(value:Bool):Bool
    {
        renderTextureQuad.textureSmoothing = value;
        return super.set_antialiasing(value);
    }

    // =============================================================================
	//} endregion                          GETTERS
	// =============================================================================
}
#end
