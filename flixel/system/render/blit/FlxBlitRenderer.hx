package flixel.system.render.blit;

import flixel.graphics.FlxBitmap;
import flixel.graphics.shaders.FlxShader;
import flixel.graphics.textures.FlxRenderTexture;
import flixel.graphics.textures.FlxTexture;
import flixel.math.FlxRect;
import flixel.system.render.FlxRenderer;
import flixel.system.render.FlxRendererTypes;
import flixel.util.FlxColor;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import lime.utils.UInt8Array;

@:access(flixel.FlxCamera)
@:access(flixel.system.render.blit)
class FlxBlitRenderer extends FlxTypedRenderer<FlxBlitView>
{
	/**
	 * Whether the camera's buffer should be locked and unlocked during render calls.
	 * 
	 * Allows you to possibly slightly optimize the rendering process IF
	 * you are not doing any pre-processing in your game state's draw() call.
	 * 
	 * This property only has effects when targeting Flash.
	 */
	public var useBufferLocking:Bool = false;
	
	public function new()
	{
		super();
		method = BLITTING;
		textures = new FlxBlitTextureSystem();
		renderTargets = new FlxBlitRenderTargetSystem();
	}
	
	override function initGlobals()
	{
		super.initGlobals();
		
		FlxObject.defaultPixelPerfectPosition = true;
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

	public function createCameraView(camera:FlxCamera)
	{
		return new FlxBlitView(camera);
	}

	public function addCameraView(view:FlxBlitView):Void
	{
		FlxG.game.addChildAt(view.flashSprite, FlxG.game.getChildIndex(FlxG.game._inputContainer));
	}

	public function addCameraViewAt(view:FlxBlitView, index:Int):Void
	{
		final childIndex = FlxG.game.getChildIndex(FlxG.cameras.list[index].viewBlit.flashSprite);
        FlxG.game.addChildAt(view.flashSprite, childIndex);
	}

	public function removeCameraView(view:FlxBlitView):Void
	{
		FlxG.game.removeChild(view.flashSprite);
	}
}

class FlxBlitTextureSystem implements IFlxTextureSystem
{
	public function new() {}
	
	public function createHandle():FlxTextureHandle {return null;}
	public function destroyHandle(handle:FlxTextureHandle):Void {}
	public function destroyBitmap(bitmap:FlxBitmap):Void {}

	public function uploadBitmap(texture:FlxTexture, bitmap:FlxBitmap):Void {}
	public function readPixels(texture:FlxTexture, buffer:UInt8Array, ?rect:FlxRect):Void {}

	public function setWrapU(texture:FlxTexture, wrap:FlxTextureWrap):Void {}
	public function setWrapV(texture:FlxTexture, wrap:FlxTextureWrap):Void {}
}

class FlxBlitRenderTargetSystem implements IFlxRenderTargetSystem
{
	public function new() {}

	public function createHandle(texture:FlxRenderTexture, depthStencil:Bool):FlxRenderTargetHandle {return null;}
	public function destroyHandle(handle:FlxRenderTargetHandle):Void {}
	public function resize(texture:FlxRenderTexture, width:Int, height:Int):Void {}
	public function clear(texture:FlxRenderTexture, color:FlxColor, depth:Bool, stencil:Bool):Void {}

	public function fetchUniforms(handle:FlxShaderHandle):Array<FlxShaderUniform<Any>> {return null;}
	public function setUniformInt(location:FlxShaderUniformLocation, v:Int):Void {}
	public function setUniformInt2(location:FlxShaderUniformLocation, v1:Int, v2:Int):Void {}
	public function setUniformInt3(location:FlxShaderUniformLocation, v1:Int, v2:Int, v3:Int):Void {}
	public function setUniformInt4(location:FlxShaderUniformLocation, v1:Int, v2:Int, v3:Int, v4:Int):Void {}
	public function setUniformIntArray(location:FlxShaderUniformLocation, v:Int32Array, dimension:FlxShaderArrayDimension):Void {}
	public function setUniformFloat(location:FlxShaderUniformLocation, v:Float):Void {}
	public function setUniformFloat2(location:FlxShaderUniformLocation, v1:Float, v2:Float):Void {}
	public function setUniformFloat3(location:FlxShaderUniformLocation, v1:Float, v2:Float, v3:Float):Void {}
	public function setUniformFloat4(location:FlxShaderUniformLocation, v1:Float, v2:Float, v3:Float, v4:Float):Void {}
	public function setUniformFloatArray(location:FlxShaderUniformLocation, v:Float32Array, dimension:FlxShaderArrayDimension):Void {}
	public function setUniformMatrix4x4(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix4x3(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix4x2(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix3x4(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix3x3(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix3x2(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix2x4(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix2x3(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformMatrix2x2(location:FlxShaderUniformLocation, v:Float32Array, transpose:Bool):Void {}
	public function setUniformTexture(location:FlxShaderUniformLocation, v:FlxTexture, smoothing:Bool, slot:Int):Void {}
}
