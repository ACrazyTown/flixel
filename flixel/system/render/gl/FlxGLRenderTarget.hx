package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import lime.graphics.opengl.GL;
import flixel.graphics.FlxRenderTexture;
import lime.graphics.opengl.GLRenderbuffer;
import lime.graphics.opengl.GLFramebuffer;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;

class FlxGLRenderTarget implements IFlxDestroyable
{
    public var parent:FlxRenderTexture;

    public var frameBuffer:GLFramebuffer;

    public var depth:Bool;
    public var depthRenderBuffer:GLRenderbuffer;

    public var stencil:Bool;
    public var stencilRenderBuffer:GLRenderbuffer;

    public function new(parent:FlxRenderTexture, depth:Bool, stencil:Bool)
    {
        this.parent = parent;
        this.depth = depth;
        this.stencil = stencil;

        frameBuffer = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, frameBuffer);

        // Attach the texture to the framebuffer
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, parent.handle, 0);

        if (GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE)
            throw "Incomplete framebuffer";

        initRenderBuffers();
    }

    public function initRenderBuffers():Void
    {
        // Delete previous buffers
        if (depthRenderBuffer != null)
            GL.deleteRenderbuffer(depthRenderBuffer);
        if (stencilRenderBuffer != null)
            GL.deleteRenderbuffer(stencilRenderBuffer);

        if (depth)
        {
            // Create depth buffer
            depthRenderBuffer = GL.createRenderbuffer();
            GL.bindRenderbuffer(GL.RENDERBUFFER, depthRenderBuffer);
            GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT24, parent.width, parent.height);

            // Attach it to the framebuffer
            GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, depthRenderBuffer);
        }

        if (stencil)
        {
            // Create stencil buffer
            stencilRenderBuffer = GL.createRenderbuffer();
            GL.bindRenderbuffer(GL.RENDERBUFFER, stencilRenderBuffer);
            GL.renderbufferStorage(GL.RENDERBUFFER, GL.STENCIL_INDEX8, parent.width, parent.height);

            // Attach it to the framebuffer
            GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.STENCIL_ATTACHMENT, GL.RENDERBUFFER, stencilRenderBuffer);
        }
    }

    public function destroy():Void
    {
        // if (frameBuffer != null)
        //     GL.deleteFramebuffer(frameBuffer);

        // if (renderBuffer != null)
        //     GL.deleteRenderbuffer(renderBuffer);

        if (frameBuffer != null)
            GL.deleteFramebuffer(frameBuffer);
        if (depthRenderBuffer != null)
            GL.deleteRenderbuffer(depthRenderBuffer);
        if (stencilRenderBuffer != null)
            GL.deleteRenderbuffer(stencilRenderBuffer);
    }
}
#end
