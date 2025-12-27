package flixel.system.render.gl;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import lime.graphics.opengl.GLRenderbuffer;
import flixel.system.render.gl.impl.GL;
import flixel.system.render.gl.impl.GLFramebuffer;
import flixel.system.render.gl.impl.GLTexture;
import flixel.system.render.gl.impl.GLInternal;
import flixel.system.render.gl.GLHelper;

class FlxRenderTexture implements IFlxDestroyable
{
    public var width(default, null):Int;
    public var height(default, null):Int;

    var glFramebuffer:GLFramebuffer;
    var glRenderbuffer:GLRenderbuffer;
    var glTexture:GLTexture;

    public function new(width:Int, height:Int)
    {
        this.width = width;
        this.height = height;

        resize(width, height);
    }

    public function destroy():Void
    {
        if (glTexture != null)
            GL.deleteTexture(glTexture);

        if (glRenderbuffer != null)
            GL.deleteRenderbuffer(glRenderbuffer);

        if (glFramebuffer != null)
            GL.deleteFramebuffer(glFramebuffer);
    }

    public function resize(width:Int, height:Int):Void
    {
        if (this.width == width && this.height == height)
            return;

        // TODO ant: proejction matrix

        // bind the framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, glFramebuffer);

        // delete the texture and renderbuffer, as we need to recreate them
        if (glTexture != null)
            GL.deleteTexture(glTexture);
        if (glRenderbuffer != null)
            GL.deleteRenderbuffer(glRenderbuffer);

        createTexture(width, height);
        createRenderbuffer(width, height);

        // unbind framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, null);
    }

    inline function createTexture(width:Int, height:Int):Void
    {
        // create texture & bind it
        glTexture = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, glTexture);

        // upload blank data
        GLInternal.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);

        GLHelper.setTextureRepeat(false);
        GLHelper.setTextureSmoothing(true);

        // specify texture as color attachment
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, glTexture, 0);

        // unbind texture
        GL.bindTexture(GL.TEXTURE_2D, null);
    }

    inline function createRenderbuffer(width:Int, height:Int):Void
    {
        // create renderbuffer & bind it
        glRenderbuffer = GL.createRenderbuffer();
        GL.bindRenderbuffer(GL.RENDERBUFFER, glRenderbuffer);

        // set the renderbuffer up as a depth buffer
        GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, width, height);

        // specify renderbuffer as depth attachment
        GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, glRenderbuffer);

        // unbind renderbuffer
        GL.bindRenderbuffer(GL.RENDERBUFFER, null);
    }
}
