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
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.geom.ColorTransform;
import openfl.geom.Point;

class FlxGLView extends FlxCameraView
{
    /**
     * Whether this view needs to be rendered (there's sprites queued to be drawn).
     */
    public var needsRender(get, never):Bool;
    inline function get_needsRender():Bool
        return _drawQueue.length > 0;

    var _useRenderMatrix:Bool = false;
    var _renderMatrix:FlxMatrix = new FlxMatrix();

    public var renderTextureQuad:FlxQuadDrawData;
    var renderTextureFrame:FlxFrame;
    var renderTextureGraphic:FlxGraphic;
    var renderTexture:FlxRenderTexture;

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
    }

    override function render()
    {
        if (!needsRender)
            return;

        _renderer.resize(camera.width, camera.height);
        // Switch to rendering on the camera's texture
        _renderer.setRenderTexture(renderTexture);
        renderTexture.clear(0); // TODO: actually implement fills

        // Submit all the collected sprites to the batcher
        for (data in _drawQueue)
        {
            _renderer.batcher.add(data);
        }

        // Force a flush to draw whatever was left in the buffer
        _renderer.batcher.flush();
    }

    override function fill(color:FlxColor, blendAlpha:Bool = true)
	{
		// super.fill(color, blendAlpha);
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

    public function offsetView(x:Float, y:Float):Void {}

    function updateInternals():Void {}

    function updateOffset():Void {}

    function updatePosition():Void {}
    
    function updateScale():Void 
    {
        updateRenderMatrix();
    }

    function updateScrollRect():Void {}

    inline function updateRenderMatrix():Void
    {
        _useRenderMatrix = camera.zoom != 1;
        if (_useRenderMatrix)
        {
            _renderMatrix.identity();
            _renderMatrix.translate(-camera.viewMarginLeft, -camera.viewMarginTop);
            _renderMatrix.scale(camera.scaleX, camera.scaleY);
        }
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
