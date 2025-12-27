package flixel.system.render.gl.impl;

import flixel.system.render.gl.impl.GL;

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
}
