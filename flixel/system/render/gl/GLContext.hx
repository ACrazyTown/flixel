package flixel.system.render.gl;

import lime.graphics.opengl.GLTexture;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import lime.graphics.opengl.GL;
import openfl.display.Shader;

/**
 * A helper class that provides high-level convenience methods for dealing with
 * the OpenGL context with Flixel types.
 */
@:access(openfl.display)
@:access(openfl.display3D)
class GLContext
{
    // TODO ant: This is currently an OpenFL shader but we should really abstract this, somehow
    var _shader:Shader;

    public function new() {}

    public function invalidate():Void
    {
        _shader = null;
    }

    /**
     * Sets `shader` as the currently active shader.
     * If `shader` is already in use, nothing is done. You can use the return value to determine
     * whether a shader swap actually occured.
     * 
     * @param   shader   The shader to use
     * @return  Whether the active shader was changed
     */
    public function setShader(shader:Shader):Bool
    {
        if (_shader == shader)
            return false;

        if (shader.__context == null)
        {
            shader.__context = FlxG.stage.context3D;
            shader.__init();
        }

        GL.useProgram(shader.glProgram);

        return true;
    }

    // TODO ant
    public function setBlendMode(blend:BlendMode):Void
    {
        // GL.blendEquation(GL.)
    }

    public function setTexture(texture:BitmapData, repeat:Bool, smoothing:Bool):Void
    {
        GL.bindTexture(GL.TEXTURE_2D, getGLTexture(texture));

        var wrap = repeat ? GL.REPEAT : GL.CLAMP_TO_EDGE;
        var filter = smoothing ? GL.LINEAR : GL.NEAREST;

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrap);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrap);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);

        /*
        GL.bindTexture(GL.TEXTURE_2D, texture);

        var minFilter:Int;
        var magFilter:Int;

        minFilter = magFilter = smoothing ? GL.LINEAR : GL.NEAREST;

        var wrapS:Int;
        var wrapT:Int;

        switch (wrap)
        {
            case CLAMP(u, v):
                wrapS = u ? GL.CLAMP_TO_EDGE : GL.REPEAT;
                wrapT = v ? GL.CLAMP_TO_EDGE : GL.REPEAT;

            case REPEAT(u, v):
                wrapS = u ? GL.REPEAT : GL.CLAMP_TO_EDGE;
                wrapT = v ? GL.REPEAT : GL.CLAMP_TO_EDGE;

            case MIRRORED_REPEAT(u, v):
                wrapS = u ? GL.MIRRORED_REPEAT : GL.REPEAT;
                wrapT = v ? GL.MIRRORED_REPEAT : GL.REPEAT;
        }

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, minFilter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, magFilter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrapS);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrapT);
        */
    }

    inline function getGLTexture(bitmap:BitmapData):GLTexture
    {
        return bitmap.getTexture(FlxG.stage.context3D).__getTexture();
    }
}
