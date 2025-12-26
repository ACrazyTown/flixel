package flixel.system.render.gl;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import lime.graphics.opengl.GLRenderbuffer;
import flixel.system.render.gl.impl.GL;
import flixel.system.render.gl.impl.GLFramebuffer;
import flixel.system.render.gl.impl.GLTexture;

class FlxRenderTexture implements IFlxDestroyable
{
    public var width(default, null):Int;
    public var height(default, null):Int;

    var glFramebuffer:GLFramebuffer;
    var glRenderbuffer:GLRenderbuffer;
    var glTexture:GLTexture;

    public function new(width:Int, height:Int)
    {
        this.width = width;
        this.height = height;
    }

    public function destroy():Void
    {
        // if (glTexture != null)
            // GL
    }

    public function resize(width:Int, height:Int):Void
    {
        if (this.width == width && this.height == height)
            return;


    }
}
