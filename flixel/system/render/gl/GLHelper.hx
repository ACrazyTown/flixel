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
    public static inline function readPixels(x:Int, y:Int, width:Int, height:Int, format:Int, type:Int, pixels:Dynamic, ?dstOffset:Int):Void
	{
		cast (GL.context, WebGL2RenderContext).readPixels(x, y, width, height, format, type, pixels, dstOffset);
	}

    public static inline function texSubImage2D(target:Int, level:Int, xoffset:Int, yoffset:Int, width:Int, height:Int, format:Dynamic, ?type:Int,
		?srcData:Dynamic, ?srcOffset:Int):Void
	{
		cast (GL.context, WebGL2RenderContext).texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, srcData, srcOffset);
	}

    public static inline function texImage2D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, border:Dynamic, ?format:Int, ?type:Int,
		?srcData:Dynamic, ?srcOffset:Int):Void
    {
        cast (GL.context, WebGL2RenderContext).texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset);
    }

    public static inline function bufferData(target:Int, srcData:Dynamic, usage:Int, ?srcOffset:Int, ?length:Int):Void
    {
        cast (GL.context, WebGL2RenderContext).bufferData(target, srcData, usage, srcOffset, length);
    }

    public static inline function bufferSubData(target:Int, dstByteOffset:Int, srcData:Dynamic, ?srcOffset:Int, ?length:Int):Void
    {
        cast (GL.context, WebGL2RenderContext).bufferSubData(target, dstByteOffset, srcData, srcOffset, length);
    }

    public static inline function uniformMatrix4fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        cast (GL.context, WebGL2RenderContext).uniformMatrix4fv(location, transpose, data, srcOffset, srcLength);
    }
}
#end
