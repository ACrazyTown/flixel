package flixel.graphics.filters;

import flixel.graphics.shaders.FlxShader;

/**
 * `FlxShaderFilter` allows you to easily apply a `FlxShader` to a sprite,
 * without having to extend `FlxFilter`.
 * 
 * Note that like `FlxShader`, `FlxShaderFilter` is limited to being single-pass only.
 */
class FlxShaderFilter extends FlxFilter
{
    public var shader(default, null):FlxShader;

    public function new(shader:FlxShader)
    {
        this.shader = shader;
    }
}