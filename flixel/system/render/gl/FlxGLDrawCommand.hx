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

    /**
	 * Transformation matrix for this item on camera.
	 */
	public var matrix(default, set):FlxMatrix;
	var _matrix4:Matrix4 = new Matrix4();

    @:deprecated("oh my god bruh")
    public var __temp__uMat:lime.math.Matrix4;

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

    function set_matrix(value:FlxMatrix):FlxMatrix
	{
		if (value != null)
		{
			_matrix4.identity();
			_matrix4[0] = value.a;
			_matrix4[1] = value.b;
			_matrix4[4] = value.c;
			_matrix4[5] = value.d;
			_matrix4[12] = value.tx;
			_matrix4[13] = value.ty;
		}

		return matrix = value;
	}
}
