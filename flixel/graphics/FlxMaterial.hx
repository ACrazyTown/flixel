package flixel.graphics;

import openfl.display.BlendMode;
import openfl.display3D.Context3DWrapMode;
import flixel.graphics.shaders.FlxShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;

class FlxMaterial implements IFlxDestroyable
{
    /**
	 * Shader of the material. Different materials could have the same shader, 
	 * but material stores different data (uniforms, textures).
	 */
	public var shader:Null<FlxShader>;

	/**
	 * Data of the material, stores values for shader uniforms.
	 * Use this property only after setting shader of the material, or you could get null pointer access error.
	 */
	// public var data(default, null):FlxShaderData;

	/**
	 * Blend mode for the material.
	 */
	public var blendMode:Null<BlendMode>;

	/**
	 * Tells if textures of the material should be smoothed or not.
	 */
	public var smoothing:Bool = false;

	/**
	 * The texture wrapping mode that decides how textures should be rendered
	 * if coordinates outside the normal range are used.
	 * 
	 * If `null`, the texture's wrapping mode will be used.
	 */
	public var wrap:Null<FlxTextureWrap> = null;

	/**
	 * Tells if this material should be batched (try to batch it with another sprites or not).
	 */
	public var batchable:Bool = true;

    public function new() {}

	public function destroy():Void
	{
		shader = null;
		wrap = null;
	}

	/**
	 * Helper function to check if two materials are equal.
     * 
	 * @param    material         The `FlxMaterial` to compare against.
	 * @param    checkBatchable   Also checks if both materials are batchable, `true` by default.
	 * @return   Whether the two materials are equal.
	 */
	public inline function equals(material:FlxMaterial, checkBatchable:Bool = true):Bool
	{
		return (shader == material.shader
			&& blendMode == material.blendMode
			&& smoothing == material.smoothing
			&& wrap == material.wrap
            && (checkBatchable ? batchable == material.batchable : true));
	}

	/**
	 * Determines the texture wrap mode to use when rendering.
	 * Uses the material's wrap if it's set, otherwise it will fall back to the texture's wrap
	 * 
	 * @return The texture wrapping mode to sue.
	 */
	public inline function getWrap():FlxTextureWrap
	{
		return wrap != null ? wrap : CLAMP(true, true); // TODO ant: temp fallback until FlxTexture is made
	}
}

// TODO ant: move this to FlxTexture, whenever that gets made
@:using(flixel.graphics.FlxMaterial.FlxTextureWrapTools)
enum FlxTextureWrap
{
	CLAMP(u:Bool, v:Bool);
	REPEAT(u:Bool, v:Bool);
	MIRRORED_REPEAT(u:Bool, v:Bool);
}

private class FlxTextureWrapTools
{
	public static inline function toContext3DWrap(wrap:FlxTextureWrap):Context3DWrapMode
	{
		return switch (wrap)
		{
			case CLAMP(u, v):
				if (u && v) CLAMP; else if (u && !v) CLAMP_U_REPEAT_V; else if (!u && v) REPEAT_U_CLAMP_V;
				else REPEAT;

			// Context3D doesn't support mirrored repeat, so we have to fall back to regular repeat
			case MIRRORED_REPEAT(u, v), REPEAT(u, v):
				if (u && v) REPEAT; else if (u && !v) REPEAT_U_CLAMP_V; else if (!u && v) CLAMP_U_REPEAT_V;
				else CLAMP;
		}
	}
	
	/**
	 * Determines whether there the `REPEAT` wrap mode is used in any form.
	 * This is useful for targets like Flash where wrapping can't be done per-axis,
	 * but is rather just enabled or disabled.
	 * 
	 * @param    wrap   The `FlxTextureWrap` to check.
	 * @return   Whether the `REPEAT` wrap mode is used.
	 */
	public static inline function isRepeat(wrap:FlxTextureWrap):Bool
	{
		return switch (wrap)
		{
			// Context3D doesn't support mirrored repeat, so we have to fall back to regular repeat
			case MIRRORED_REPEAT(u, v), REPEAT(u, v):
				if (!u && !v) false; else true;

			default: false;
		}
	}
}
