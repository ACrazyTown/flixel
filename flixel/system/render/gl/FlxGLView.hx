package flixel.system.render.gl;

import lime.math.Matrix4;
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
