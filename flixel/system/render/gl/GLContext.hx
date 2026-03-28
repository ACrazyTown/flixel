package flixel.system.render.gl;

import lime.graphics.opengl.GLFramebuffer;
#if FLX_RENDER_OPENGL
import lime.utils.UInt8Array;
import flixel.graphics.FlxTexture;
import flixel.graphics.FlxRenderTexture;
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

        var wrap = repeat ? GL.REPEAT : GL.CLAMP_TO_EDGE;
        var filter = smoothing ? GL.LINEAR : GL.NEAREST;

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrap);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrap);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);
    }

    // =============================================================================
	//}endregion                          TEXTURES
	// =============================================================================

    /**
     * Binds and uses `texture` as the render target. If `texture` is `null`,
     * the rendering is done on the screen (back buffer).
     * 
     * Also resizes the viewport to match the texture's dimensions.
     * 
     * @param   texture   The `FlxRenderTexture` to render to.
     */
    public function setRenderTexture(texture:Null<FlxRenderTexture>):Void
    {
        GL.bindFramebuffer(GL.FRAMEBUFFER, (texture != null) ? texture.renderTarget.framebuffer : null);

        if (texture != null)
            GL.viewport(0, 0, texture.width, texture.height);
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
}
#end
