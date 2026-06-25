package flixel.system.render;

/**
 * Underlying representation of the texture.
 * The actual type is dependant on the renderer, and is determined at compile time.
 */
typedef FlxTextureHandle = #if FLX_RENDER_OPENGL lime.graphics.opengl.GLTexture #else flixel.graphics.FlxBitmap #end;

/**
 * Underlying representation of a render target.
 * The actual type is dependant on the renderer, and is determined at compile time.
 */
typedef FlxRenderTargetHandle = #if FLX_RENDER_OPENGL flixel.system.render.gl.FlxGLRenderTarget #else Dynamic #end;
