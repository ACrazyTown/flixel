package flixel.system.render.gl;

import flixel.graphics.textures.FlxRenderTexture;
#if FLX_RENDER_OPENGL
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
