package flixel.system.render.gl;

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

    public function new(camera:FlxCamera)
    {
        super(camera);

        renderTexture = new FlxRenderTexture(camera.width, camera.height);
    }

    override function get_display():DisplayObjectContainer
    {
        return flashSprite;
    }
}
