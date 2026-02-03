package flixel.system.render.gl;

import lime.math.Matrix4;
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;

class FlxGLView extends FlxCameraView
{
    // TODO: we need to have something to avoid crashes...
    var dummy:Sprite = new Sprite();

    // public var projection:Matrix4

    public var mat4lmao:Matrix4 = new Matrix4();

    public function new(camera:FlxCamera)
    {
        super(camera);

        mat4lmao.createOrtho(0, camera.width, camera.height, 0, -1000, 1000);
    }

    override function get_display():DisplayObjectContainer 
    {
        return dummy;
    }
}
