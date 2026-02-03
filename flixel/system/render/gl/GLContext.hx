package flixel.system.render.gl;

import flixel.graphics.shaders.FlxShader;
import flixel.FlxG;
import lime.graphics.opengl.GLTexture;
import flixel.graphics.FlxMaterial.FlxTextureWrap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Shader;
import lime.graphics.opengl.GL;

/**
 * Provides nice higher level helper methods for working with OpenGL,
 * while also keeping track of the global state
 */
// TODO ant: state cache
@:access(openfl.display)
class GLContext
{
    var _currentBlendMode:BlendMode;
    var _currentShader:FlxShader;

    public function new() {}

    public function invalidate():Void
    {
        _currentBlendMode = null;
        _currentShader = null;
    }

    public function reset():Void
    {
        // GL.enable(GL.BLEND);
    }

    public function setShader(shader:FlxShader):Void
    {
        if (_currentShader == shader)
            return;

        if (shader != null)
        {
            if (shader.__context == null)
            {
                shader.__context = FlxG.stage.context3D;
                shader.__init();
            }

            GL.useProgram(shader.glProgram);
            _currentShader = shader;
        }
    }

    public function setBlendMode(blend:BlendMode):Void
    {
        if (_currentBlendMode == blend)
            return;

        if (blend == null)
            blend = NORMAL;

        _currentBlendMode = blend;
    
        var equation:Int = GL.FUNC_ADD;
        var srcFactor:Int = GL.ONE;
        var destFactor:Int = GL.ONE_MINUS_SRC_ALPHA;

        switch (blend)
        {
            case ADD:
                srcFactor = GL.ONE;
                destFactor = GL.ONE;

            case MULTIPLY:
                srcFactor = GL.DST_COLOR;
                destFactor = GL.ONE_MINUS_SRC_ALPHA;

            case SCREEN:
                srcFactor = GL.ONE;
                destFactor = GL.ONE_MINUS_SRC_COLOR;
            
            case SUBTRACT:
                srcFactor = GL.ONE;
                destFactor = GL.ONE;
                equation = GL.FUNC_REVERSE_SUBTRACT;

            default:
        }

        // trace(equation);
        GL.blendEquation(equation);
        GL.blendFunc(srcFactor, destFactor);

        // update the OpenFL renderer's blend state to avoid blending issues
        // with other OpenFL sprites like the mouse and debugger
        FlxG.stage.__renderer.__blendMode = blend;
    }

    public function setTexture(texture:BitmapData, smoothing:Bool, wrap:FlxTextureWrap)
    {
        if (texture != null)
        {
            GL.activeTexture(GL.TEXTURE0);

            var glTexture = getGLTextureFromBitmap(texture);
            GL.bindTexture(GL.TEXTURE_2D, glTexture);

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
                    wrapT = u ? GL.REPEAT : GL.CLAMP_TO_EDGE;

                case MIRRORED_REPEAT(u, v):
                    wrapS = u ? GL.MIRRORED_REPEAT : GL.REPEAT;
                    wrapT = u ? GL.MIRRORED_REPEAT : GL.REPEAT;
            }

            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, minFilter);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, magFilter);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrapS);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrapT);
        }
    }

    inline function getGLTextureFromBitmap(bitmap:BitmapData):GLTexture
    {
        @:privateAccess
        return bitmap.getTexture(FlxG.stage.context3D).__getTexture();
    }
}
