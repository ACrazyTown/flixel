package flixel.system.render.gl;

import flixel.graphics.FlxGraphic;
import flixel.graphics.FlxTrianglesData;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxRect;
import lime.math.Matrix4;
import flixel.graphics.frames.FlxFrame;
import openfl.display.BitmapData;
import flixel.graphics.FlxMaterial;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.util.FlxColor;
import lime.graphics.opengl.GL;

// TODO: FlxRenderTexture
class FlxGLRenderer extends FlxRenderer
{
    public var view(get, never):FlxGLView;
    @:noCompletion inline function get_view():FlxGLView
        return cast camera.view;

    public var context:GLContext;

    public var projection:Matrix4;
    public var projectionFlipped:Matrix4;

    var singleQuadCommand:FlxDrawQuadsCommand;
    var quadsCommand:FlxDrawQuadsCommand;
    var trianglesCommand:FlxDrawTrianglesCommand;
    var currentCommand:FlxGLDrawCommand;

    var _fillMaterial:FlxMaterial;
    var _fillRect:FlxRect = FlxRect.get();

    public function new()
    {
        super();
        method = OPENGL;

        maxTextureSize = cast GL.getParameter(GL.MAX_TEXTURE_SIZE);

        context = new GLContext();

        singleQuadCommand = new FlxDrawQuadsCommand(this, 1);
        quadsCommand = new FlxDrawQuadsCommand(this, 16383); // TODO ant: add quads per batch constant
        trianglesCommand = new FlxDrawTrianglesCommand(this);

        _fillMaterial = new FlxMaterial();
        _fillMaterial.batchable = false;
    }

    override function destroy():Void
    {
        super.destroy();

        currentCommand = null;
        singleQuadCommand = FlxDestroyUtil.destroy(singleQuadCommand);
        quadsCommand = FlxDestroyUtil.destroy(quadsCommand);

        _fillMaterial = FlxDestroyUtil.destroy(_fillMaterial);
        _fillRect = FlxDestroyUtil.put(_fillRect);
    }

    override function clear():Void
    {
        // GL.clearColor(0.0, 0.0, 0.0, 1.0);
        // GL.clear(GL.COLOR_BUFFER_BIT);
        // context.reset();

        fill(camera.bgColor, camera.useBgAlphaBlending);
    }

    override function render():Void
    {
        if (currentCommand != null)
        {
            currentCommand.flush();
            currentCommand = null;
        }
    }

    override function drawPixelsInternal(?frame:FlxFrame, ?pixels:BitmapData, material:FlxMaterial, matrix:FlxMatrix, ?transform:ColorTransform)
    {
        // super.drawPixelsInternal(frame, pixels, material, matrix, transform);

        var c = getQuads(material);
        c.__temp__uMat = view.mat4lmao;
        // c.matrix = matrix;

        c.addQuad(frame, material, matrix, transform);
    }

    override function drawTrianglesInternal(graphic:FlxGraphic, data:FlxTrianglesData, material:FlxMaterial, matrix:FlxMatrix, ?transform:ColorTransform) 
    {
        var c = getTriangles();
        c.set(graphic, material, true, false);
        c.__temp__uMat = view.mat4lmao;
        c.data = data;
        c.matrix = matrix;
        c.color = transform;
        c.flush();
    }

    override function fill(color:FlxColor, blendAlpha:Bool = true):Void
    {
        if (color.alphaFloat == 0)
            return;

        _fillRect.set(camera.viewMarginLeft - 1, camera.viewMarginTop - 1, camera.viewWidth + 2, camera.viewHeight + 2);

        var cmd = getQuads(_fillMaterial);
        cmd.__temp__uMat = view.mat4lmao;
        cmd.addColorQuad(_fillRect, _fillMaterial, _helperMatrix, color);
    }

    function getQuads(material:FlxMaterial):FlxDrawQuadsCommand
    {
        if (currentCommand != null)
		{
			if (material.batchable && currentCommand != quadsCommand)
				currentCommand.flush();
			else if (!material.batchable)
				currentCommand.flush();
		}

		var result = (material.batchable) ? quadsCommand : singleQuadCommand;
		currentCommand = result;
		return result;
    }

    function getTriangles():FlxDrawTrianglesCommand
    {
        if (currentCommand != null)
            currentCommand.flush();

        currentCommand = null;
        return trianglesCommand;
    }
}
