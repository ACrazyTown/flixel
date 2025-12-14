package flixel.graphics;

import flixel.graphics.shader.FlxShader;
import openfl.display.BlendMode;
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

	public inline function equals(material:FlxMaterial):Bool
	{
		return (shader == material.shader
			&& blendMode == material.blendMode
			&& antialiasing == material.antialiasing
			&& repeat == material.repeat);
	}

    public function destroy():Void
    {
		shader = null;
	}
}
