package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import lime.utils.UInt8Array;
import flixel.graphics.FlxTexture;
import lime.graphics.opengl.GLTexture;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import lime.graphics.opengl.GL;
import openfl.display.Shader;
import flixel.FlxG;

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

    // =============================================================================
	//{region                             TEXTURES
	// =============================================================================

    public inline function bindTexture(texture:FlxTexture):Void
    {
        GL.bindTexture(GL.TEXTURE_2D, texture.handle);
    }

    public inline function setTextureWrapU(wrap:FlxTextureWrap):Void
    {
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, getGLWrap(wrap));
    }

    public inline function setTextureWrapV(wrap:FlxTextureWrap):Void
    {
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, getGLWrap(wrap));
    }

    // public inline function setTextureFilter(filter:FlxTextureFilter):Void
    // {
    //     final glFilter = getGLFilter(filter);
    //     GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, glFilter);
    //     GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, glFilter);
    // }

    public function allocTextureData(texture:FlxTexture, data:UInt8Array, dataFormat:Int, textureFormat:Int):Void
    {
        bindTexture(texture);
        GLHelper.texImage2D(GL.TEXTURE_2D, 0, textureFormat, texture.width, texture.height, 0, dataFormat, GL.UNSIGNED_BYTE, data);
    }

    public function uploadTextureData(texture:FlxTexture, data:UInt8Array, dataFormat:Int):Void
    {
        bindTexture(texture);
        GLHelper.texSubImage2D(GL.TEXTURE_2D, 0, 0, 0, texture.width, texture.height, dataFormat, GL.UNSIGNED_BYTE, data);
    }

    @:deprecated
    public function setTexture(texture:FlxTexture, repeat:Bool, smoothing:Bool):Void
    {
        GL.bindTexture(GL.TEXTURE_2D, texture.handle);

        // var wrap = repeat ? GL.REPEAT : GL.CLAMP_TO_EDGE;
        // var filter = smoothing ? GL.LINEAR : GL.NEAREST;

        // GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrap);
        // GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrap);
        // GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);
        // GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);

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

    // =============================================================================
	//}endregion                          TEXTURES
	// =============================================================================

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
        _shader = shader;

        return true;
    }

    // TODO ant
    public function setBlendMode(blend:BlendMode):Void
    {
        // GL.blendEquation(GL.)
    }

    inline function getGLWrap(wrap:FlxTextureWrap):Int
    {
        return switch (wrap)
        {
            case CLAMP: GL.CLAMP_TO_EDGE;
            case REPEAT: GL.REPEAT;
        }
    }

    // inline function getGLFilter(filter:FlxTextureFilter):Int
    // {
    //     return switch(filter)
    //     {
    //         case NEAREST: GL.NEAREST;
    //         case LINEAR: GL.LINEAR;
    //     }
    // }
}
#end
