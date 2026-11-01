package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.graphics.textures.FlxRenderTexture;
import lime.graphics.opengl.GLRenderbuffer;
import lime.graphics.opengl.GLFramebuffer;

class FlxGLRenderTarget
{
    public var texture:FlxRenderTexture;

    public var framebuffer:GLFramebuffer;
    public var renderbuffer:GLRenderbuffer;
    
    public function new() {}
}
#end
