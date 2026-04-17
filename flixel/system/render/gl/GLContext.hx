package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import lime.utils.UInt8Array;
import flixel.graphics.FlxTexture;
import flixel.graphics.FlxRenderTexture;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLFramebuffer;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import lime.graphics.opengl.GL;
import openfl.display.Shader;
import flixel.FlxG;

/**
 * A helper class that provides high-level convenience methods for dealing with
 * the OpenGL context with Flixel types.
 */
// TODO ant: look into state cache
@:access(openfl.display)
@:access(openfl.display3D)
class GLContext
{
    // TODO ant: This is currently an OpenFL shader but we should really abstract this, somehow
    var _shader:Shader;
    var _curBlendMode:BlendMode;

    public function new() {}

    public function invalidate():Void
    {
        _shader = null;
        _curBlendMode = null;
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

    public function allocTextureData(texture:FlxTexture, textureFormat:Int, data:UInt8Array, dataFormat:Int):Void
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
     * @param   texture   The `FlxRenderTexture` to render to.
     */
    public inline function setRenderTexture(texture:Null<FlxRenderTexture>):Void
    {
        GL.bindFramebuffer(GL.FRAMEBUFFER, (texture != null) ? texture.renderTarget.framebuffer : null);
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

    public function setBlendMode(blend:BlendMode):Void
    {
        if (blend == null) 
            blend = NORMAL;
        
        if (_curBlendMode == blend)
            return;

        switch (blend)
        {
            case ADD:
                GL.blendEquation(GL.FUNC_ADD);
                GL.blendFunc(GL.ONE, GL.ONE);

            case MULTIPLY:
                GL.blendEquation(GL.FUNC_ADD);
                GL.blendFunc(GL.DST_COLOR, GL.ONE_MINUS_SRC_ALPHA);

            case SCREEN:
                GL.blendEquation(GL.FUNC_ADD);
                GL.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_COLOR);

            case SUBTRACT:
                GL.blendEquationSeparate(GL.FUNC_REVERSE_SUBTRACT, GL.FUNC_ADD);
                GL.blendFunc(GL.ONE, GL.ONE);

            default:
                GL.blendEquation(GL.FUNC_ADD);
                GL.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA);
        }

        _curBlendMode = blend;

        // TODO ant: I can't get this to happen anymore but if it does come back this should fix it
        // update the OpenFL renderer's blend state to avoid blending issues
        // with other OpenFL sprites like the mouse and debugger
        // FlxG.stage.__renderer.__blendMode = blend;
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
