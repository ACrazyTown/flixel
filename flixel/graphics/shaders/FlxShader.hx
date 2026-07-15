package flixel.graphics.shaders;

import flixel.graphics.textures.FlxTexture;
import flixel.system.FlxAssets.FlxShader as FlxLegacyShader;
import flixel.system.render.FlxRendererTypes;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import haxe.ds.StringMap;
import lime.graphics.opengl.GL;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import openfl.display.BitmapData;
import openfl.display.Shader;

/**
 * A `FlxShader` represents a single-pass shader program used to render a sprite.
 */
class FlxShader implements IFlxDestroyable
{
    // TODO: dispose
    // These are for internal use only, and will be removed once support for OpenFL shaders is dropped in v7
    @:noCompletion
    static var flashCache:Map<FlxLegacyShader, FlxShader> = [];

    @:noCompletion
    static var flashAttributeNames:Map<String, String> = [
		"flixel_aPosition" => "openfl_Position",
		"flixel_aTextureCoord" => "openfl_TextureCoord",
		"flixel_aColorMultiplier" => "openfl_ColorMultiplier",
		"flixel_aColorOffset" => "openfl_ColorOffset"
    ];

    @:noCompletion
    static var flashUniformNames:Map<String, String> = [
		"flixel_uMatrix" => "openfl_Matrix",
		"flixel_uTextureSize" => "openfl_TextureSize",
		"flixel_uTexture" => "bitmap",
    ];

    @:noCompletion
    public static function fromFlash(legacyShader:FlxLegacyShader):FlxShader
    {
        if (legacyShader == null)
            return null;

        var cached = flashCache.get(legacyShader);
        if (cached != null)
            return cached;

        cached = new FlxShader({flash: {shader: legacyShader}});
        flashCache.set(legacyShader, cached);
        return cached;
    }

    /**
     * The shader data provided through the constructor. 
     */
    public var data(default, null):FlxShaderData;

    /**
     * Internal reference to the backend shader handle.
     */
    var _handle:FlxShaderHandle;

    var _attributeLocations:StringMap<FlxShaderAttributeLocation>;

    /**
     * Map of internal uniform states, keyed by the uniform name.
     */
    var _uniformMap:StringMap<FlxShaderUniform<Any>>;

    /**
     * List of internal uniform states
     */
    var _uniforms:Array<FlxShaderUniform<Any>>;

    /**
     * Whether the texture slots were bound.
     * This will be set to true during the first `updateUniforms()` call.
     */
    var _boundTextureSlots:Bool = false;

    public function new(data:FlxShaderData)
    {
        this.data = data;

        _handle = FlxG.renderer.shaders.createHandle(data);
        _uniforms = FlxG.renderer.shaders.fetchUniforms(_handle);

        // To be able to modify the uniforms by name we need a fast way to fetch them so
        // we'll also make a map
        if (_uniforms != null)
        {
            _uniformMap = new StringMap<FlxShaderUniform<Any>>();
            for (uniform in _uniforms)
                _uniformMap.set(uniform.name, uniform);
        }

        _attributeLocations = new StringMap<FlxShaderAttributeLocation>();
    }

    /**
     * Destroys the shader and all data related to it.
     */
    public function destroy():Void
    {
        if (data.flash != null)
        {
            for (k => v in flashCache)
            {
                if (this == v)
                    flashCache.remove(k);
            }
        }

        if (_handle != null)
            FlxG.renderer.shaders.destroyHandle(_handle);

        _handle = null;
        _uniforms = null;
        _uniformMap = null;
        data = null;
    }

    /**
     * Checks if the specified uniform is present in the compiled shader.
     * 
     * Note that uniforms defined in shader code, if unused, may be removed by the
     * underlying shader compiler. Simply defining it does not guarantee it will be available.
     * 
     * @param   name   The uniform's name in the shader.
     * @return  Whether the uniform exists.
     */
    public inline function hasUniform(name:String):Bool
    {
        return _uniformMap.exists(name);
    }

    /**
     * Returns the location of the specified uniform.
     * 
     * If the uniform doesn't exist (not present at all, or was unused and the shader compiler removed it), the returned
     * location will be `null`.
     * 
     * @param   name   The uniform's name in the shader.
     * @return  `FlxShaderUniformLocation`, or `null` if it wasn't found.
     */
    public function getUniformLocation(name:String):Null<FlxShaderUniformLocation>
    {
        #if !flash
        if (data.flash != null)
        {
            inline function getOpenFLUniform(name:String):Dynamic
                return cast Reflect.field(data.flash.shader.data, name);

            // Hacky backwards compatibility solution for legacy shaders
            // Since new GL shaders have different variable names, we will try remapping them to the old OpenFL ones
            // (if the initial check fails)
            var uniform = getOpenFLUniform(name);
            if (uniform == null)
                uniform = getOpenFLUniform(flashUniformNames.get(name));

            return uniform != null ? cast uniform.index : null;
        }
        #end

        var uniform = cast _uniformMap.get(name);
        return uniform != null ? uniform.location : null;
    }

    /**
     * Returns the location of the specified attribute.
     * 
    * If the attribute doesn't exist (not present at all, or was unused and the shader compiler removed it), the returned
     * location will be `null`.
     * 
     * @param   name   The uniform's name in the shader.
     * @return  `FlxShaderAttributeLocation`, or `null` if it wasn't found.
     */
    public function getAttributeLocation(name:String):Null<FlxShaderAttributeLocation>
    {
        #if !flash
        if (data.flash != null)
        {
            inline function getOpenFLAttribute(name:String):Dynamic
                return cast Reflect.field(data.flash.shader.data, name);

            // Hacky backwards compatibility solution for legacy shaders
            // Since new GL shaders have different variable names, we will try remapping them to the old OpenFL ones
            // (if the initial check fails)
            var attribute = getOpenFLAttribute(name);
            if (attribute == null)
                attribute = getOpenFLAttribute(flashAttributeNames.get(name));
            
            return attribute != null ? cast attribute.index : null;
        }
        #end

        var location = _attributeLocations.get(name);
        if (location != null)
            return location;

        location = FlxG.renderer.shaders.getAttributeLocation(_handle, name);
        _attributeLocations.set(name, location);
        return location;
    }

    /**
     * Sets the value of the specified uniform to the integer `v1`.
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     An integer to set the uniform's value to.
     */
    public function setInt(name:String, v1:Int) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1]);
            return;
        }

        var uniform:FlxShaderUniform<Int> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = v1;
        uniform.dirty = true;
    }

    /**
     * Sets the values of the specified 2-component uniform to the integers (`v1`, `v2`).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     */
    public function setInt2(name:String, v1:Int, v2:Int) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1, v2]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderVec2<Int>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value.set(v1, v2);
        uniform.dirty = true;
    }

    /**
     * Sets the values of the specified 3-component uniform to the integers (`v1`, `v2`, `v3`).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     * @param   v3     The value of the third vector component.
     */
    public function setInt3(name:String, v1:Int, v2:Int, v3:Int) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1, v2, v3]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderVec3<Int>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value.set(v1, v2, v3);
        uniform.dirty = true;
    }

    /**
     * Sets the values of the specified 4-component uniform to the integers (`v1`, `v2`, `v3`, `v4`).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     * @param   v3     The value of the third vector component.
     * @param   v4     The value of the fourth vector component.
     */
    public function setInt4(name:String, v1:Int, v2:Int, v3:Int, v4:Int) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1, v2, v3, v4]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderVec4<Int>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value.set(v1, v2, v3, v4);
        uniform.dirty = true;
    }

    /**
     * Sets the value of the specified uniform to the int array `v`.
     * While this method is mainly intended for use with uniform arrays, you may also use it to update
     * a single or vector uniform as well.
     * 
     * This method is provided for convenience. It allocates a `Int32Array` and calls `setTypedIntArray()`,
     * as that's the format the GPU natively accepts. While likely negligible, if you want to avoid excess
     * allocations you should use `setTypedIntArray()` directly.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           An array of integers to set the uniform's value to.
     * @param   dimension   How many components there are per vector in array. For example, if `dimension` is `SCALAR`, 
     *                      the array is treated as a simple int array. If `dimension` is `VEC2`, the array is treated as 
     *                      an array of 2 component vectors (`vec2`)
     */
    public function setIntArray(name:String, v:Array<Int>, dimension:FlxShaderArrayDimension = SCALAR)
    {
        setTypedIntArray(name, new Int32Array(v), dimension);
    }

    /**
     * Sets the value of the specified uniform to the `Int32Array` `v`.
     * While this method is mainly intended for use with uniform arrays, you may also use it to update
     * a single or vector uniform as well.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           A `Int32Array` to set the uniform's value to.
     * @param   dimension   How many components there are per vector in array. For example, if `dimension` is `SCALAR`, 
     *                      the array is treated as a simple int array. If `dimension` is `VEC2`, the array is treated as 
     *                      an array of 2 component vectors (`vec2`)
     */
    public function setTypedIntArray(name:String, v:Int32Array, dimension:FlxShaderArrayDimension = SCALAR)
    {
        if (data.flash != null)
        {
            FlxG.log.error("OpenFL shaders do not support uniform arrays.");
            return;
        }

        var uniform:FlxShaderUniform<ShaderArray<Int32Array>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        if (uniform.value.data != v || uniform.value.dimension != dimension)
        {
            uniform.value.data = v;
            uniform.value.dimension = dimension;
            uniform.dirty = true;
        }
    }

    /**
     * Sets the value of the specified uniform to the float `v1`.
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     A float to set the uniform's value to.
     */
    public function setFloat(name:String, v1:Float) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1]);
            return;
        }

        var uniform:FlxShaderUniform<Float> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = v1;
        uniform.dirty = true;
    }

    /**
     * Sets the values of the specified 2-component uniform to the floats (`v1`, `v2`).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     */
    public function setFloat2(name:String, v1:Float, v2:Float) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1, v2]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderVec2<Float>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value.set(v1, v2);
        uniform.dirty = true;
    }

    /**
     * Sets the values of the specified 3-component uniform to the floats (`v1`, `v2`, `v3`).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     * @param   v3     The value of the third vector component.
     */
    public function setFloat3(name:String, v1:Float, v2:Float, v3:Float) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1, v2, v3]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderVec3<Float>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value.set(v1, v2, v3);
        uniform.dirty = true;
    }

    /**
     * Sets the values of the specified 4-component uniform to the floats (`v1`, `v2`, `v3`, `v4`).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     * @param   v3     The value of the third vector component.
     * @param   v4     The value of the fourth vector component.
     */
    public function setFloat4(name:String, v1:Float, v2:Float, v3:Float, v4:Float) 
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [v1, v2, v3, v4]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderVec4<Float>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value.set(v1, v2, v3, v4);
        uniform.dirty = true;
    }

    /**
     * Sets the value of the specified uniform to the float array `v`.
     * While this method is mainly intended for use with uniform arrays, you may also use it to update
     * a single or vector uniform as well.
     * 
     * This method is provided for convenience. It allocates a `Float32Array` and calls `setTypedFloatArray()`,
     * as that's the format the GPU natively accepts. While likely negligible, if you want to avoid excess
     * allocations you should use `setTypedFloatArray()` directly.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           An array of floats to set the uniform's value to.
     * @param   dimension   How many components there are per vector in array. For example, if `dimension` is `SCALAR`, 
     *                      the array is treated as a simple int array. If `dimension` is `VEC2`, the array is treated as 
     *                      an array of 2 component vectors (`vec2`)
     */
    public function setFloatArray(name:String, v:Array<Float>, dimension:FlxShaderArrayDimension = SCALAR)
    {
        setTypedFloatArray(name, new Float32Array(v), dimension);
    }

    /**
     * Sets the value of the specified uniform to the `Float32Array` `v`.
     * While this method is mainly intended for use with uniform arrays, you may also use it to update
     * a single or vector uniform as well.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           A `Float32Array` to set the uniform's value to.
     * @param   dimension   How many components there are per vector in array. For example, if `dimension` is `SCALAR`, 
     *                      the array is treated as a simple int array. If `dimension` is `VEC2`, the array is treated as 
     *                      an array of 2 component vectors (`vec2`)
     */
    public function setTypedFloatArray(name:String, v:Float32Array, dimension:FlxShaderArrayDimension = SCALAR)
    {
        if (data.flash != null)
        {
            FlxG.log.error("OpenFL shaders do not support uniform arrays.");
            return;
        }

        var uniform:FlxShaderUniform<ShaderArray<Float32Array>> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        if (uniform.value.data != v || uniform.value.dimension != dimension)
        {
            uniform.value.data = v;
            uniform.value.dimension = dimension;
            uniform.dirty = true;
        }
    }

    /**
     * Sets the value of the specified uniform to the bool `v1`.
     * 
     * This method is provided for convenience. As the GPU does not natively accept booleans,
     * it just sets the uniform to the integer representation of the bool. (`1` if true, `0` if false).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     A bool to set the uniform's value to.
     */
    public function setBool(name:String, v1:Bool) 
    {
        setInt(name, v1 ? 1 : 0);
    }

    /**
     * Sets the values of the specified 2-component uniform to the bools (`v1`, `v2`).
     * 
     * This method is provided for convenience. As the GPU does not natively accept booleans,
     * it just sets the uniform to the integer representation of the bool. (`1` if true, `0` if false).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     */
    public function setBool2(name:String, v1:Bool, v2:Bool) 
    {
        setInt2(name, v1 ? 1 : 0, v2 ? 1 : 0);
    }

    /**
     * Sets the values of the specified 3-component uniform to the bools (`v1`, `v2`, `v3`).
     * 
     * This method is provided for convenience. As the GPU does not natively accept booleans,
     * it just sets the uniform to the integer representation of the bool. (`1` if true, `0` if false).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     * @param   v3     The value of the third vector component.
     */
    public function setBool3(name:String, v1:Bool, v2:Bool, v3:Bool) 
    {
        setInt3(name, v1 ? 1 : 0, v2 ? 1 : 0, v3 ? 1 : 0);
    }

    /**
     * Sets the values of the specified 4-component uniform to the bools (`v1`, `v2`, `v3`, `v4`).
     * 
     * This method is provided for convenience. As the GPU does not natively accept booleans,
     * it just sets the uniform to the integer representation of the bool. (`1` if true, `0` if false).
     * 
     * @param   name   The uniform's name in the shader.
     * @param   v1     The value of the first vector component.
     * @param   v2     The value of the second vector component.
     * @param   v3     The value of the third vector component.
     * @param   v4     The value of the fourth vector component.
     */
    public function setBool4(name:String, v1:Bool, v2:Bool, v3:Bool, v4:Bool) 
    {
        setInt4(name, v1 ? 1 : 0, v2 ? 1 : 0, v3 ? 1 : 0, v4 ? 1 : 0);
    }


    /**
     * Sets the value of the specified uniform to the bool array `v`.
     * While this method is mainly intended for use with uniform arrays, you may also use it to update
     * a single or vector uniform as well.
     * 
     * This method is provided for convenience. As the GPU does not natively accept booleans,
     * it just sets the uniform to the integer representation of the bool. (`1` if true, `0` if false).
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           An array of bools to set the uniform's value to.
     * @param   dimension   How many components there are per vector in array. For example, if `dimension` is `SCALAR`, 
     *                      the array is treated as a simple int array. If `dimension` is `VEC2`, the array is treated as 
     *                      an array of 2 component vectors (`vec2`)
     */
    public function setBoolArray(name:String, v:Array<Bool>, dimension:FlxShaderArrayDimension)
    {
        setIntArray(name, [for (n in v) n ? 1 : 0], dimension);
    }

    /**
     * Sets the value of the specified matrix uniform to the float array `v`.
     * 
     * This method is provided for convenience. It allocates a `Float32Array` and calls `setTypedFloatArray()`,
     * as that's the format the GPU natively accepts. While likely negligible, if you want to avoid excess
     * allocations you should use `setTypedFloatArray()` directly.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           An array of floats to set the uniform's value to.
     * @param   transpose   Whether the matrix should be transposed (swap its rows and columns).
     */
    public function setMatrix(name:String, v:Array<Float>, ?transpose:Bool = false)
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, v);
            return;
        }

        setMatrixTypedArray(name, new Float32Array(v), transpose);
    }

    /**
     * Sets the value of the specified matrix uniform to the `Float32Array` `v`.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           An array of floats to set the uniform's value to.
     * @param   transpose   Whether the matrix should be transposed (swap its rows and columns).
     */
    public function setMatrixTypedArray(name:String, v:Float32Array, ?transpose:Bool = false)
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [for (i in 0...v.length) v[i]]);
            return;
        }

        var uniform:FlxShaderUniform<ShaderMatrix> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        if (uniform.value.data != v || uniform.value.transpose != transpose)
        {
            uniform.value.data = v;
            uniform.value.transpose = transpose;
            uniform.dirty = true;
        }
    }

    // /**
    //  * Sets the value of the specified uniform to `bitmap`.
    //  * 
    //  * @param   name        The uniform's name in the shader.
    //  * @param   bitmap      The `BitmapData` to set the uniform's value to.
    //  * @param   smoothing   Whether the bitmap should be smoothed.
    //  */
    // public function setBitmap(name:String, bitmap:BitmapData, smoothing:Bool)
    // {
    //     if (data.flash != null)
    //     {
    //         var input:openfl.display.ShaderInput<BitmapData> = Reflect.field(data.flash.shader.data, name);
    //         input.filter = smoothing ? LINEAR : NEAREST;
    //         input.input = bitmap;
    //         return;
    //     }

    //     var uniform = cast _uniformMap.get(name);
    //     if (uniform == null) 
    //     {
    //         FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
    //         return; 
    //     }

    //     uniform.value = BITMAP(bitmap, smoothing);
    // }

    /**
     * Sets the value of the specified uniform to `texture`.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   texture     The `FlxTexture` to set the uniform's value to.
     * @param   smoothing   Whether the texture should be smoothed.
     */
    public function setTexture(name:String, texture:FlxTexture, smoothing:Bool)
    {
        if (data.flash != null)
        {
            FlxG.log.error("shader.setTexture() is not supported with OpenFL shaders");
            return;
        }

        var uniform:FlxShaderUniform<ShaderTexture> = cast _uniformMap.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        if (uniform.value.texture != texture || uniform.value.smoothing != smoothing)
        {
            uniform.value.texture = texture;
            uniform.value.smoothing = smoothing;
            uniform.dirty = true;
        }
    }

    @:allow(flixel.system.render)
    function updateUniforms():Void
    {
        #if !flash
        if (data.flash != null)
        {
            // this is a copy of openfl.display.Shader.__updateGL();
            // but we only update uniforms and skip attributes
            @:privateAccess
            {
                var textureCount = 0;

                for (input in data.flash.shader.__inputBitmapData)
                {
                    if (!input.__isUniform) continue;

                    input.__updateGL(data.flash.shader.__context, textureCount);
                    textureCount++;
                }

                for (parameter in data.flash.shader.__paramBool)
                {
                    if (!parameter.__isUniform) continue;

                    parameter.__updateGL(data.flash.shader.__context);
                }

                for (parameter in data.flash.shader.__paramFloat)
                {
                    if (!parameter.__isUniform) continue;

                    parameter.__updateGL(data.flash.shader.__context);
                }

                for (parameter in data.flash.shader.__paramInt)
                {
                    if (!parameter.__isUniform) continue;

                    parameter.__updateGL(data.flash.shader.__context);
                }
            }

            return;
        }
        #end

        // We already know texture slot locations, so we do an extra loop once
        // to send them to the shader. This way we don't have to send them with every draw call.
        // TODO: could go even further and do this once per shader program, not per instance
        if (!_boundTextureSlots)
        {
            for (uniform in _uniforms)
            {
                if (uniform.type == TEXTURE)
                {
                    var t:ShaderTexture = cast uniform.value;
                    FlxG.renderer.shaders.setUniformInt(uniform.location, t.slot);
                }
            }

            _boundTextureSlots = true;
        }

        for (uniform in _uniforms)
        {
            if (!uniform.dirty)
                continue;

            switch uniform.type
            {
                case INT1:
                    var v:Int = cast uniform.value;
                    FlxG.renderer.shaders.setUniformInt(uniform.location, v);
                
                case INT2:
                    var v:ShaderVec2<Int> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformInt2(uniform.location, v.x, v.y);

                case INT3:
                    var v:ShaderVec3<Int> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformInt3(uniform.location, v.x, v.y, v.z);

                case INT4:
                    var v:ShaderVec4<Int> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformInt4(uniform.location, v.x, v.y, v.z, v.w);

                case INT_ARRAY:
                    var v:ShaderArray<Int32Array> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformIntArray(uniform.location, v.data, v.dimension);

                case FLOAT1:
                    var v:Float = cast uniform.value;
                    FlxG.renderer.shaders.setUniformFloat(uniform.location, v);
                
                case FLOAT2:
                    var v:ShaderVec2<Float> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformFloat2(uniform.location, v.x, v.y);

                case FLOAT3:
                    var v:ShaderVec3<Float> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformFloat3(uniform.location, v.x, v.y, v.z);

                case FLOAT4:
                    var v:ShaderVec4<Float> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformFloat4(uniform.location, v.x, v.y, v.z, v.w);

                case FLOAT_ARRAY:
                    var v:ShaderArray<Float32Array> = cast uniform.value;
                    FlxG.renderer.shaders.setUniformFloatArray(uniform.location, v.data, v.dimension);

                case MAT2X2:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix2x2(uniform.location, v.data, v.transpose);

                case MAT2X3:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix2x3(uniform.location, v.data, v.transpose);

                case MAT2X4:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix2x4(uniform.location, v.data, v.transpose);

                case MAT3X2:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix3x2(uniform.location, v.data, v.transpose);

                case MAT3X3:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix3x3(uniform.location, v.data, v.transpose);

                case MAT3X4:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix3x4(uniform.location, v.data, v.transpose);

                case MAT4X2:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix4x2(uniform.location, v.data, v.transpose);

                case MAT4X3:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix4x3(uniform.location, v.data, v.transpose);

                case MAT4X4:
                    var v:ShaderMatrix = cast uniform.value;
                    FlxG.renderer.shaders.setUniformMatrix4x4(uniform.location, v.data, v.transpose);

                case TEXTURE:
                    var v:ShaderTexture = cast uniform.value;
                    FlxG.renderer.shaders.setUniformTexture(uniform.location, v.texture, v.smoothing, v.slot);
            }
            
            uniform.dirty = false;
        }
    }

    function setFlashShaderUniform<T>(name:String, value:T):Void
    {
        #if !flash
        if (data.flash != null)
        {
            var param:Dynamic = Reflect.field(data.flash.shader.data, name);
            if (param == null)
                param = Reflect.field(data.flash.shader.data, flashUniformNames.get(name));

            if (param == null)
            {
                FlxG.log.error('Can\'t set nonexistent shader uniform "$name"');
                return;
            }

            param.value = cast value;
        }
        #end
    }
}

typedef FlxShaderData =
{
    /**
     * Flash/OpenFL shader data. This is usable both with the DRAW_TILES and OpenGL renderers, though it is
     * highly discouraged with the latter.
     * This option is available mostly for backwards compatibility reasons, and will be removed in a future major version.
     */
    @:deprecated("OpenFL shader support will be dropped in v7.0.0. Migrate your shaders to the new FlxShader API")
    @:optional var flash:FlxOpenFLShaderData;

    /**
     * GLSL data for the shader. This is only used with the OpenGL renderer.
     */
    @:optional var glsl:FlxGLSLShaderData;
}

typedef FlxOpenFLShaderData = 
{
    /**
     * The Flash/OpenFL shader instance 
     */
    var shader:Shader;
}

typedef FlxGLSLShaderData = 
{
    /**
     * Optional data for the vertex shader. If not provided, the default vertex shader data will be used.
     */
    @:optional var vertex:GLSLShader & 
    {
        /**
         * Ordered array of vertex attribute names.
         * If this is provided, the vertex attribute locations will be bound to their corresponding index in the array. 
         * If your shaders share the same vertex attributes, you should bind them in the same order so the
         * renderer can take advantage of internal optimisations.
         */
        var attributes:Array<String>;
    };

    /**
     * Data for the fragment shader.
     */
    var fragment:GLSLShader &
    {
        /**
         * 
         */
        @:optional var injectBuiltins:Bool;
    };
}

typedef GLSLShader = 
{
    /**
     * The GLSL source code for the shader.
     */
    var source:String;

    /**
     * Optional, the wanted GLSL shader version.
     * 
     * The default value is left unspecified, and as such will be automatically
     * set by the GPU driver. In this case you should assume you're working with the
     * lowest version possible (`110` on desktop and `100` on mobile/web).
     * 
     * Note that this will be ignored if the version is already set in the GLSL shader code.
     */
    @:optional var version:String;

    /**
     * Optional, the wanted floating-point precision for the shader.
     * This only has an effect when targeting OpenGL ES (mobile) or WebGL (HTML5).
     * 
     * Default value is `HIGH`.
     * 
     * Note that this will be ignored if the precision qualifier is already
     * set in the GLSL shader code.
     */
    @:optional var precision:GLSLPrecision;
}

enum abstract GLSLPrecision(String) from String to String
{
    var HIGH = "highp";
    var MEDIUM = "mediump";
    var LOW = "lowp";
}

// Under are various defines for internal shader uniform state. These have @:noCompletion instead of
// being private classes because they need to be referenced by FlxRenderer implementations but hidden from the user!

enum FlxShaderArrayDimension
{
    /**
     * The array is interpreted as an array of individual values.
     */
    SCALAR;

    /**
     * The array is interpreted as an array of 2-component vectors.
     */
    VEC2;

    /**
     * The array is interpreted as an array of 3-component vectors.
     */
    VEC3;

    /**
     * The array is interpreted as an array of 4-component vectors.
     */
    VEC4;
}

@:noCompletion
class FlxShaderUniform<T> 
{
    public var type:FlxUniformType;
    public var name:String;
    public var location:FlxShaderUniformLocation;
    public var value:T;
    public var dirty:Bool = false;

    public function new(type:FlxUniformType, name:String, location:FlxShaderUniformLocation, value:T)
    {
        this.type = type;
        this.name = name;
        this.location = location;
        this.value = value;
    }
}

@:noCompletion
enum abstract FlxUniformType(Int)
{
    var INT1 = 0;
    var INT2 = 1;
    var INT3 = 2;
    var INT4 = 3;
    var INT_ARRAY = 4;
    var FLOAT1 = 5;
    var FLOAT2 = 6;
    var FLOAT3 = 7;
    var FLOAT4 = 8;
    var FLOAT_ARRAY = 9;
    var MAT4X4 = 10;
    var MAT4X3 = 11;
    var MAT4X2 = 12;
    var MAT3X4 = 13;
    var MAT3X3 = 14;
    var MAT3X2 = 15;
    var MAT2X4 = 16;
    var MAT2X3 = 17;
    var MAT2X2 = 18;
    var TEXTURE = 19;
}

@:structInit
@:generic
class ShaderVec2<T>
{
	public var x:T;
	public var y:T;

    public inline function set(x:T, y:T):Void
    {
        this.x = x;
        this.y = y;
    }
}

@:structInit
@:generic
@:noCompletion
class ShaderVec3<T> 
{
	public var x:T;
	public var y:T;
	public var z:T;

    public inline function set(x:T, y:T, z:T):Void
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }
}

@:structInit
@:generic
@:noCompletion
class ShaderVec4<T> 
{
	public var x:T;
	public var y:T;
	public var z:T;
	public var w:T;

    public inline function set(x:T, y:T, z:T, w:T):Void
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }
}

@:structInit
@:generic
@:noCompletion
class ShaderArray<T>
{
    public var data:T;
    public var dimension:FlxShaderArrayDimension;
}

@:structInit
@:noCompletion
class ShaderMatrix
{
    public var data:Float32Array;
    public var transpose:Bool;
    // public var layout:FlxShaderMatrixType;
}

@:structInit
@:noCompletion
class ShaderTexture
{
    public var texture:FlxTexture;
    public var smoothing:Bool;
    public var slot:Int;
}
