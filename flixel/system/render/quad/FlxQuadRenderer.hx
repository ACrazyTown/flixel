package flixel.system.render.quad;

import flixel.graphics.FlxRenderTexture;
import flixel.math.FlxRect;
import flixel.FlxG;
import flixel.graphics.FlxBitmap;
import flixel.graphics.textures.FlxTexture;
import flixel.system.render.FlxRenderer;
import flixel.system.render.FlxRendererTypes;
import lime.utils.UInt8Array;

#if FLX_OPENGL_AVAILABLE
import lime.graphics.opengl.GL;
#end

using flixel.util.FlxColorTransformUtil;

@:access(flixel.FlxCamera)
@:access(flixel.system.render.quad)
class FlxQuadRenderer extends FlxTypedRenderer<FlxQuadView>
{
	public function new()
	{
		super();
		method = DRAW_TILES;
		textures = new FlxQuadTextureSystem();
		renderTargets = new FlxQuadRenderTargetSystem();
		
		#if FLX_OPENGL_AVAILABLE
		if (hasGL)
			maxTextureSize = cast GL.getParameter(GL.MAX_TEXTURE_SIZE);
		#end
	}
	
	public function createCameraView(camera:FlxCamera)
	{
		return new FlxQuadView(camera);
	}

	public inline function startFrame():Void
	{
		FlxG.renderer.totalDrawCalls = 0;
		FlxG.cameras.clear();
	}

	public inline function endFrame():Void
	{
		FlxG.cameras.render();
	}

	public function addCameraView(view:FlxQuadView):Void
	{
		FlxG.game.addChildAt(view.flashSprite, FlxG.game.getChildIndex(FlxG.game._inputContainer));
	}

	public function addCameraViewAt(view:FlxQuadView, index:Int):Void
	{
		final childIndex = FlxG.game.getChildIndex(FlxG.cameras.list[index].viewQuad.flashSprite);
        FlxG.game.addChildAt(view.flashSprite, childIndex);
	}

	public function removeCameraView(view:FlxQuadView):Void
	{
		FlxG.game.removeChild(view.flashSprite);
	}
}

@:access(flixel.graphics.textures.FlxTexture)
class FlxQuadTextureSystem implements IFlxTextureSystem
{
	public function new() {}

	// No-op, handle will get assigned at upload to avoid reallocating bitmaps
	public function createHandle():FlxTextureHandle { return null; }
	public function destroyHandle(handle:FlxTextureHandle):Void 
	{
		#if FLX_RENDER_DRAWQUADS
		handle.destroy();
		#end
	}

	public function destroyBitmap(bitmap:FlxBitmap):Void 
	{
		#if (FLX_RENDER_DRAWQUADS && !flash)
		// Since the bitmap is the same as the handle, we don't actually want to destroy it,
		// just get rid of the image buffer
		bitmap.disposeImage();

		// Also force the texture to get updated while we're at it
		bitmap.getTexture(FlxG.stage.context3D);
		#end
	}

	public function uploadBitmap(texture:FlxTexture, bitmap:FlxBitmap):Void 
	{
		#if FLX_RENDER_DRAWQUADS
		texture._handle = bitmap;
		#end
	}

	public function readPixels(texture:FlxTexture, buffer:UInt8Array, ?rect:FlxRect):Void 
	{
		#if (FLX_RENDER_DRAWQUADS && FLX_OPENGL_AVAILABLE)
		final gl = FlxG.stage.window.context.webgl;

		@:privateAccess
		final glTexture = texture._handle.getTexture(FlxG.stage.context3D).__getTexture();
		gl.bindTexture(gl.TEXTURE_2D, glTexture);

        // Create dummy framebuffer we'll read from
        var fb = gl.createFramebuffer();
        gl.bindFramebuffer(gl.FRAMEBUFFER, fb);

        // Attach texture to framebuffer and read the pixels from it into the buffer
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, glTexture, 0);
        gl.readPixels(Std.int(rect.x), Std.int(rect.y), Std.int(rect.width), Std.int(rect.height), gl.RGBA, gl.UNSIGNED_BYTE, buffer);

        // Delete the framebuffer
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        gl.deleteFramebuffer(fb);

		gl.bindTexture(gl.TEXTURE_2D, null);
		#end	
	}

	// No-op, handled in the FlxDrawItems
	public function setWrapU(texture:FlxTexture, wrap:FlxTextureWrap):Void {}
	public function setWrapV(texture:FlxTexture, wrap:FlxTextureWrap):Void {}
	// function setTextureFilter(texture:FlxTexture, filter:FlxTextureFilter):Void {}
}

// No-op, FlxRenderTexture is not supported with this renderer
class FlxQuadRenderTargetSystem implements IFlxRenderTargetSystem
{
	public function new() {}

	public function createHandle(texture:FlxRenderTexture, depthStencil:Bool):FlxRenderTargetHandle {return null;}
	public function destroyHandle(handle:FlxRenderTargetHandle):Void {}
	public function resize(texture:FlxRenderTexture, width:Int, height:Int):Void {}
	public function clear(texture:FlxRenderTexture, color:FlxColor, depth:Bool, stencil:Bool):Void {}
}
