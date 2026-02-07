package flixel.system.render.gl;

import flixel.system.render.gl.FlxGLRenderer;
import flixel.system.render.gl.GLContext;
import flixel.math.FlxMatrix;
import flixel.system.render.FlxDrawCommand;
import lime.math.Matrix4;

class FlxGLDrawCommand extends FlxDrawCommand
{
    /**
     * A reference to the renderer's `GLContext`.
     */
    public var context:GLContext;

    /**
     * A reference to the renderer.
     */
    public var renderer:FlxGLRenderer;

    var textured(get, never):Bool;
    @:noCompletion inline function get_textured():Bool
    {
        return graphic != null;
    }

    public function new(renderer:FlxGLRenderer)
    {
        super();
        this.renderer = renderer;
        context = renderer.context;
    }
}
