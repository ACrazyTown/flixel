package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import lime.graphics.WebGL2RenderContext;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.opengl.GL;

// TODO ant: Maybe make an abstract over GL and expose what we need instead
/**
 * Lime's static GL class hides methods based on the compile defines used,
 * so we use this helper to have WebGL spec compliant methods on all targets.
 */
class GLHelper
{
    static var gl(get, never):WebGL2RenderContext;
    inline static function get_gl():WebGL2RenderContext
        return cast GL.context;

    public static inline function readPixels(x:Int, y:Int, width:Int, height:Int, format:Int, type:Int, pixels:Dynamic, ?dstOffset:Int):Void
	{
		gl.readPixels(x, y, width, height, format, type, pixels, dstOffset);
	}

    public static inline function texSubImage2D(target:Int, level:Int, xoffset:Int, yoffset:Int, width:Int, height:Int, format:Dynamic, ?type:Int,
		?srcData:Dynamic, ?srcOffset:Int):Void
	{
        
		gl.texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, srcData, srcOffset);
	}

    public static inline function texImage2D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, border:Dynamic, ?format:Int, ?type:Int,
		?srcData:Dynamic, ?srcOffset:Int):Void
    {
        gl.texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset);
    }

    public static inline function bufferData(target:Int, srcData:Dynamic, usage:Int, ?srcOffset:Int, ?length:Int):Void
    {
        gl.bufferData(target, srcData, usage, srcOffset, length);
    }

    public static inline function bufferSubData(target:Int, dstByteOffset:Int, srcData:Dynamic, ?srcOffset:Int, ?length:Int):Void
    {
        gl.bufferSubData(target, dstByteOffset, srcData, srcOffset, length);
    }

    public static inline function uniformMatrix4fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix4fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix4x3fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix4x3fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix4x2fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix4x2fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix3x4fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix3x4fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix3fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix3fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix3x2fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix3x2fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix2x4fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix2x4fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix2x3fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix2x3fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniformMatrix2fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        gl.uniformMatrix2fv(location, transpose, data, srcOffset, srcLength);
    }

    public static inline function uniform1iv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform1iv(location, v);
    }

    public static inline function uniform2iv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform2iv(location, v);
    }

    public static inline function uniform3iv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform3iv(location, v);
    }

    public static inline function uniform4iv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform4iv(location, v);
    }

    public static inline function uniform1fv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform1fv(location, v);
    }

    public static inline function uniform2fv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform2fv(location, v);
    }

    public static inline function uniform3fv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform3fv(location, v);
    }

    public static inline function uniform4fv(location:GLUniformLocation, v:Dynamic):Void
    {
        gl.uniform4fv(location, v);
    }
}
#end
