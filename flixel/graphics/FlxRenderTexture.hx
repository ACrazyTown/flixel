package flixel.graphics;

import flixel.system.render.gl.GLHelper;
import lime.graphics.opengl.GL;
import flixel.util.FlxColor;

// interface IFlxRenderTargetHandle implements

typedef FlxRenderTargetHandle = #if FLX_RENDER_OPENGL flixel.system.render.gl.FlxGLRenderTarget #else Dynamic #end;

class FlxRenderTexture extends FlxTexture
{
    public var renderTarget(default, null):FlxRenderTargetHandle;

    /**
     * Whether the render texture has a depth/stencil buffer.
     */
    public var hasDepthStencil(default, null):Bool;

    public function new(width:Int, height:Int, depthStencil:Bool = true)
    {
        super(width, height);
        hasDepthStencil = depthStencil;

        renderTarget = FlxG.renderer.createRenderTargetHandle(this, depthStencil);
        FlxG.renderer.resizeRenderTarget(this, width, height);
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
