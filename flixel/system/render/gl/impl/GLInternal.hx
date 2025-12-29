package flixel.system.render.gl.impl;

import flixel.system.render.gl.impl.GL;
import flixel.system.render.gl.impl.GLInternal;

class GLInternal
{
    public static inline function texImage2D(target:Int, level:Int, internalformat:Int, width:Int, height:Int, border:Dynamic, ?format:Int, ?type:Int,
			?srcData:Dynamic, ?srcOffset:Int):Void
    {
        #if lime
        final context:lime.graphics.WebGL2RenderContext = cast GL.context;
        context.texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset);
        #else
        GL.texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset);
        #end
    }

    public static inline function bufferData(target:Int, srcData:Dynamic, usage:Int, ?srcOffset:Int, ?length:Int):Void
    {
        #if lime
        final context:lime.graphics.WebGL2RenderContext = cast GL.context;
        context.bufferData(target, srcData, usage, srcOffset, length);
        #else
        GL.bufferData(target, srcData, usage, srcOffset, length);
        #end
    }

    public static inline function bufferSubData(target:Int, dstByteOffset:Int, srcData:Dynamic, ?srcOffset:Int, ?length:Int):Void
    {
        #if lime
        final context:lime.graphics.WebGL2RenderContext = cast GL.context;
        context.bufferSubData(target, dstByteOffset, srcData, srcOffset, length);
        #else
        GL.bufferSubData(target, dstByteOffset, srcData, srcOffset, length);
        #end
    }

    public static inline function uniformMatrix4fv(location:GLUniformLocation, transpose:Bool, data:Dynamic, ?srcOffset:Int, ?srcLength:Int):Void
    {
        #if lime
        final context:lime.graphics.WebGL2RenderContext = cast GL.context;
        context.uniformMatrix4fv(location, transpose, data, srcOffset, srcLength);
        #else
        GL.uniformMatrix4fv(location, transpose, data, srcOffset, srcLength);
        #end
    }
}
