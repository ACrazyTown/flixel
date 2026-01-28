package flixel.system.render.gl;

import flixel.util.FlxColor;
import lime.graphics.opengl.GL;

// TODO: FlxRenderTexture
class FlxGLRenderer extends FlxRenderer
{
    public var view(get, never):FlxGLView;
    @:noCompletion inline function get_view():FlxGLView
        return cast camera.view;

    public function new()
    {
        super();
        method = OPENGL;

		maxTextureSize = cast GL.getParameter(GL.MAX_TEXTURE_SIZE);
    }

    override function clear():Void
    {
        GL.clearColor(0.0, 0.0, 0.0, 1.0);
        GL.clear(GL.COLOR_BUFFER_BIT);
    }
}
