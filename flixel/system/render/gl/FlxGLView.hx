package flixel.system.render.gl;

import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.display.DisplayObject;
import flixel.FlxCamera;

class FlxGLView extends FlxCameraView
{
    // Not actually used for anything, but we need to have a sprite...
    public var flashSprite:Sprite = new Sprite();

    public function new(camera:FlxCamera)
    {
        super(camera);
    }

    override function get_display():DisplayObjectContainer
    {
        return flashSprite;
    }
}
