package flixel.graphics;

import openfl.display.BlendMode;
import openfl.display3D.Context3DWrapMode;
import flixel.system.FlxAssets.FlxShader;
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

	/**
	 * Helper function to check if two materials are equal.
     * 
	 * @param   material         The `FlxMaterial` to compare against.
     * @param   checkBatchable   Also checks if both materials are batchable, `true` by default.
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

    public function destroy():Void
    {
		shader = null;
		wrap = null;
	}
}

// TODO ant: move this to FlxTexture, whenever that gets made
@:using(flixel.graphics.FlxMaterial.FlxTextureWrapTools)
enum FlxTextureWrap
{
	CLAMP(s:Bool, t:Bool);
	REPEAT(s:Bool, t:Bool);
	MIRRORED_REPEAT(s:Bool, t:Bool);
}

private class FlxTextureWrapTools
{
	public static inline function toContext3DWrap(wrap:FlxTextureWrap):Context3DWrapMode
	{
		// return switch (wrap)
		// {
		// 	case CLAMP(s, t):
		// 		if (s && t) CLAMP;
		// 		if (s && !t) CLAMP_U_REPEAT_V;
		// 		if (!s && t) CLAMP

		// 	// OpenFL doesn't support mirrored repeat, fall back to repeat
		// 	case MIRRORED_REPEAT(s, t):

		// }

		return switch (wrap)
		{
			case CLAMP(s, t):
				if (s && t) CLAMP;
				else if (s && !t) CLAMP_U_REPEAT_V;
				else if (!s && t) REPEAT_U_CLAMP_V;
				else REPEAT;

			// OpenFL doesn't support mirrored repeat, so we have to fall back to regular repeat
			case MIRRORED_REPEAT(s, t), REPEAT(s, t):
				if (s && t) REPEAT;
				else if (s && !t) REPEAT_U_CLAMP_V;
				else if (!s && t) CLAMP_U_REPEAT_V;
				else CLAMP;
		}

		// return null;
	}
}
