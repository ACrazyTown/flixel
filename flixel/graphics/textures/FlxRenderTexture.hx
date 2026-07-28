package flixel.graphics.textures;

import flixel.system.render.gl.GLHelper;
import lime.graphics.opengl.GL;
import flixel.util.FlxColor;
import flixel.system.render.FlxRendererTypes;

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

        renderTarget = FlxG.renderer.renderTargets.createHandle(this, depthStencil);
        FlxG.renderer.renderTargets.resize(this, width, height);
    }

    override function destroy():Void
    {
        super.destroy();

        if (renderTarget != null)
        {
            FlxG.renderer.renderTargets.destroyHandle(renderTarget);
            renderTarget = null;
        }
    }

    public function clear(color:FlxColor, depth:Bool = true, stencil:Bool = true):Void
    {
        FlxG.renderer.renderTargets.clear(this, color, depth, stencil);
    }

    public function resize(width:Int, height:Int):Void
    {
        if (this.width == width && this.height == height)
            return;

        this.width = width;
        this.height = height;
        FlxG.renderer.renderTargets.resize(this, width, height);
    }
}
