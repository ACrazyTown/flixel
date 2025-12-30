package flixel.system.render.gl;

import lime.graphics.WebGL2RenderContext;
import flixel.graphics.frames.FlxFrame;
import openfl.display.BitmapData;
import flixel.graphics.FlxMaterial;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.util.FlxColor;
import flixel.system.render.gl.impl.GL;
import lime.math.Matrix4;
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.display.DisplayObject;
import flixel.FlxCamera;

class FlxGLView extends FlxCameraView
{
    // Not actually used for anything, but we need to have a sprite...
    public var flashSprite:Sprite = new Sprite();

    public var projectionMatrix:Matrix4 = new Matrix4();
    public var renderTexture:FlxRenderTexture;

    var currentCommand:FlxDrawCommand<Dynamic> = null;
    var quads:FlxDrawQuadsCommand = new FlxDrawQuadsCommand(16383);
    var singleQuad:FlxDrawQuadsCommand = new FlxDrawQuadsCommand(1);

    public function new(camera:FlxCamera)
    {
        super(camera);

        renderTexture = new FlxRenderTexture(camera.width, camera.height);

        projectionMatrix.createOrtho(0, camera.width, camera.height, 0, -1000, 1000);
        // projectionMatrix.invert();
        singleQuad.__temp__uMat = projectionMatrix;
        quads.__temp__uMat = projectionMatrix;
        // singleQuads.__temp__uMat.copyFrom(projectionMatrix);
    }

    override function clear():Void
    {
        // renderTexture.clear(FlxColor.TRANSPARENT, true, true);
        // GL.clearColor(1.0, 0.5, 0.0, 1.0);
        // GL.clear(GL.COLOR_BUFFER_BIT);
    }

    override function render():Void
    {
        if (currentCommand != null)
        {
            currentCommand.flush();
            currentCommand = null;
        }
    }

    override function draw(?frame:FlxFrame, ?pixels:BitmapData, material:FlxMaterial, matrix:FlxMatrix, ?transform:ColorTransform):Void
    {
        //super.draw(frame, pixels, material, matrix, transform);
        // singleQuads.reset();
        // singleQuads.set(frame.parent, material, false, false);
        // singleQuads.addQuad(frame, matrix, transform, material);
        // singleQuads.flush();
        var c = getQuads(frame, material);
        c.addQuad(frame, matrix, transform, material);
    }

    function getQuads(frame:FlxFrame, material:FlxMaterial)
    {
        if (currentCommand != null)
		{
			if (material.batchable && currentCommand != quads)
				currentCommand.flush();
			else if (!material.batchable)
				currentCommand.flush();
		}

		var result = (material.batchable) ? quads : singleQuad;
		currentCommand = result;
		return result;
    }

    override function get_display():DisplayObjectContainer
    {
        return flashSprite;
    }
}
