package flixel.system.render.gl;

import flixel.graphics.FlxBlendMode;

class GLContext
{
    var blendMode:FlxBlendMode;

    public function new()
    {

    }

    public function setBlendMode(blendMode:FlxBlendMode):Void
    {
        if (this.blendMode != blendMode)
        {
            this.blendMode = blendMode;
        }
    }
}
