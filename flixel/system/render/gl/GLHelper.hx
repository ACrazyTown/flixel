package flixel.system.render.gl;

import flixel.system.render.gl.impl.GL;

/**
 * Helper methods for working with OpenGL
 */
class GLHelper
{
    /**
     * Sets the texture's smoothing value.
     * 
     * **NOTE**: The texture must be bound before calling this!
     * @param   smoothing   Whether the texture should be smoothed or not.
     */
    public static function setTextureSmoothing(smoothing:Bool):Void
    {
        final value = smoothing ? GL.LINEAR : GL.NEAREST;
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, value);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, value);
    }

     /**
     * Sets the texture's repeat value.
     * 
     * **NOTE**: The texture must be bound before calling this!
     * @param   smoothing   Whether the texture should repeat or not.
     */
    public static function setTextureRepeat(repeat:Bool):Void
    {
        final value = repeat ? GL.REPEAT : GL.CLAMP_TO_EDGE;
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, value);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, value);
    }
}
