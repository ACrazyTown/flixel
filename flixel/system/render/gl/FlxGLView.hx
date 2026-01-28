package flixel.system.render.gl;

import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;

class FlxGLView extends FlxCameraView
{
    // TODO: we need to have something to avoid crashes...
    var dummy:Sprite = new Sprite();

    public function new(camera:FlxCamera)
    {
        super(camera);
    }

    override function get_display():DisplayObjectContainer 
    {
        return dummy;
    }
}
