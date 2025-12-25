package flixel.system.render.gl;

import openfl.display.Shader;
import lime.graphics.opengl.GL;

/**
 * Provides nice higher level helper methods for working with OpenGL,
 * while also keeping track of the global state
 */
// TODO: state cache
@:access(openfl.display)
class GLContext
{
    public function new() {}

    public function reset():Void
    {
        // GL.enable(GL.BLEND);
    }

    public function setShader(shader:Shader):Void
    {
        // if (shader != null)
        //     shader.__init();
    }
}
