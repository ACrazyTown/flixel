package flixel.graphics;

import flixel.system.render.gl.GLHelper;
import lime.graphics.opengl.GL;
import flixel.util.FlxColor;

// interface IFlxRenderTargetHandle implements

typedef FlxRenderTargetHandle = #if FLX_RENDER_OPENGL flixel.system.render.gl.FlxGLRenderTarget #else Dynamic #end;

class FlxRenderTexture extends FlxTexture
{
    public var renderTarget(default, null):FlxRenderTargetHandle;

    public function new(width:Int, height:Int, depth:Bool = true, stencil:Bool = true)
    {
        super(width, height);
        renderTarget = FlxG.renderer.createRenderTargetHandle(this, depth, stencil);
    }

    override function destroy():Void
    {
        super.destroy();

        if (renderTarget != null)
        {
            FlxG.renderer.destroyRenderTargetHandle(renderTarget);
            renderTarget = null;
        }
    }

    public function clear(color:FlxColor, depth:Bool = true, stencil:Bool = true):Void
    {
        FlxG.renderer.clearRenderTarget(this, color, depth, stencil);
    }

    public function resize(width:Int, height:Int):Void
    {
        if (this.width == width && this.height == height)
            return;

        this.width = width;
        this.height = height;
        FlxG.renderer.resizeRenderTarget(this, width, height);
    }
}
