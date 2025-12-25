package flixel.graphics;

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
	public var blendMode:Null<FlxBlendMode>;

	/**
	 * Tells if textures of the material should be antialiased (smoothed) or not.
	 */
	public var antialiasing:Bool = false;

	/**
	 * Tells if textures of the material should be repeated or not.
	 */
	public var repeat:Bool = false;

	/**
	 * Tells if this material should be batched (try to batch it with another sprites or not).
	 */
	public var batchable:Bool = true;

    public function new() {}

	/**
	 * Helper function to check if two materials are equal.
     * 
	 * @param material The `FlxMaterial` to compare against.
     * @param checkBatchable Also checks if both materials are batchable, false by default.
	 * @return Whether the two materials are equal.
	 */
	public inline function equals(material:FlxMaterial, checkBatchable:Bool = false):Bool
	{
		return (shader == material.shader
			&& blendMode == material.blendMode
			&& antialiasing == material.antialiasing
			&& repeat == material.repeat
            && (checkBatchable ? batchable == material.batchable : true));
	}

    public function destroy():Void
    {
		shader = null;
	}
}

