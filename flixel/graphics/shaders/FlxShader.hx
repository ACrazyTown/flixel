package flixel.graphics.shaders;

// import flixel.graphics.shaders.FlxShaderUniforms;
import openfl.display.BitmapData;
import flixel.graphics.FlxTexture;
import flixel.system.FlxAssets.FlxShader as FlxLegacyShader;
import flixel.system.render.quad.FlxGraphicsShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import haxe.ds.StringMap;
import lime.utils.ArrayBufferView;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import openfl.display.Shader;
import openfl.display.ShaderParameter;

import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLShader;
#if FLX_RENDER_OPENGL // TODO: temp to pass CI, will be removed afterwards
import flixel.system.render.gl.GLHelper;
#end

typedef FlxShaderAttributeLocation = Int;
typedef FlxShaderUniformLocation = lime.graphics.opengl.GLUniformLocation;
typedef FlxShaderHandle = lime.graphics.opengl.GLProgram;

// TODO: support for WebGL2 specifics like uints and more matrices
// TODO: get rid of all the traces bro & clean up

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

    /**
     * Internal map, keyed by the uniform names, storing data about the state of the shader uniforms.
     */
    var _uniforms:Map<String, FlxShaderUniform>;

    public function new(data:FlxShaderData) 
    {
        this.data = data;

        _handle = _createShaderHandle(data);
        _uniforms = _createShaderUniformMap(_handle);
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
            _destroyShaderHandle(_handle);

        _handle = null;
        _uniforms = null;
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
        return _uniforms.exists(name);
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

        var uniform = _uniforms.get(name);
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

        return GL.getAttribLocation(_handle, name);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = INT1(v1);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = INT2(v1, v2);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = INT3(v1, v2, v3);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = INT4(v1, v2, v3, v4);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = INT_ARRAY(v, dimension);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = FLOAT1(v1);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = FLOAT2(v1, v2);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = FLOAT3(v1, v2, v3);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = FLOAT4(v1, v2, v3, v4);
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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = FLOAT_ARRAY(v, dimension);
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
     * @param   type        The format/type of the matrix data. Note that non-square matrices may not be
     *                      supported on older devices (only supported on WebGL 2, OpenGL ES 3.0+ and OpenGL 2.1+). 
     * @param   transpose   Whether the matrix should be transposed (swap its rows and columns).
     */
    public function setMatrix(name:String, v:Array<Float>, type:FlxShaderMatrixType, ?transpose:Bool = false)
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, v);
            return;
        }

        setMatrixTypedArray(name, new Float32Array(v), type, transpose);
    }

    /**
     * Sets the value of the specified matrix uniform to the `Float32Array` `v`.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   v           An array of floats to set the uniform's value to.
     * @param   type        The format/type of the matrix data. Note that non-square matrices may not be
     *                      supported on older devices (only supported on WebGL 2, OpenGL ES 3.0+ and OpenGL 2.1+). 
     * @param   transpose   Whether the matrix should be transposed (swap its rows and columns).
     */
    public function setMatrixTypedArray(name:String, v:Float32Array, type:FlxShaderMatrixType, ?transpose:Bool = false)
    {
        if (data.flash != null)
        {
            setFlashShaderUniform(name, [for (i in 0...v.length) v[i]]);
            return;
        }

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = MATRIX(v, type, transpose);
    }

    /**
     * Sets the value of the specified uniform to `bitmap`.
     * 
     * @param   name        The uniform's name in the shader.
     * @param   bitmap      The `BitmapData` to set the uniform's value to.
     * @param   smoothing   Whether the bitmap should be smoothed.
     */
    public function setBitmap(name:String, bitmap:BitmapData, smoothing:Bool)
    {
        if (data.flash != null)
        {
            var input:openfl.display.ShaderInput<BitmapData> = Reflect.field(data.flash.shader.data, name);
            input.filter = smoothing ? LINEAR : NEAREST;
            input.input = bitmap;
            return;
        }

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = BITMAP(bitmap, smoothing);
    }

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

        var uniform = _uniforms.get(name);
        if (uniform == null) 
        {
            FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
            return; 
        }

        uniform.value = TEXTURE(texture, smoothing);
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

        #if FLX_RENDER_OPENGL // TODO: temp, remove after moving
        var curTextureSlot:Int = 0;

        for (key in _uniforms.keys())
        {
            var uniform = _uniforms.get(key);
            if (!uniform.dirty)
                continue;

            switch (uniform.value)
            {
                case INT1(v): GL.uniform1i(uniform.location, v);
                case INT2(v1, v2): GL.uniform2i(uniform.location, v1, v2);
                case INT3(v1, v2, v3): GL.uniform3i(uniform.location, v1, v2, v3);
                case INT4(v1, v2, v3, v4): GL.uniform4i(uniform.location, v1, v2, v3, v4);
                case INT_ARRAY(v, dimension):
                    if (v == null) continue;

                    switch (dimension)
                    {
                        case SCALAR: GLHelper.uniform1iv(uniform.location, v);
                        case VEC2: GLHelper.uniform2iv(uniform.location, v);
                        case VEC3: GLHelper.uniform3iv(uniform.location, v);
                        case VEC4: GLHelper.uniform4iv(uniform.location, v);
                    }

                case FLOAT1(v): GL.uniform1f(uniform.location, v);
                case FLOAT2(v1, v2): GL.uniform2f(uniform.location, v1, v2);
                case FLOAT3(v1, v2, v3): GL.uniform3f(uniform.location, v1, v2, v3);
                case FLOAT4(v1, v2, v3, v4): GL.uniform4f(uniform.location, v1, v2, v3, v4);
                case FLOAT_ARRAY(v, dimension):
                    if (v == null) continue;

                    switch (dimension)
                    {
                        case SCALAR: GLHelper.uniform1fv(uniform.location, v);
                        case VEC2: GLHelper.uniform2fv(uniform.location, v);
                        case VEC3: GLHelper.uniform3fv(uniform.location, v);
                        case VEC4: GLHelper.uniform4fv(uniform.location, v);
                    }

                case MATRIX(v, type, transpose):
                    if (v == null) continue;

                    switch (type)
                    {
                        case MAT4X4: GLHelper.uniformMatrix4fv(uniform.location, transpose, v);
                        case MAT3X3: GLHelper.uniformMatrix3fv(uniform.location, transpose, v);
                        case MAT2X2: GLHelper.uniformMatrix2fv(uniform.location, transpose, v);
                        default: throw "implement webgl2 matrices"; // TODO
                    }

                case TEXTURE(texture, smoothing):
                    if (texture == null) continue;

                    GL.activeTexture(GL.TEXTURE0 + curTextureSlot);
                    // TODO: after moving this to renderer GET RID OF THIS
                    cast (FlxG.renderer, flixel.system.render.gl.FlxGLRenderer).context.bindTexture(texture);

                    final filter = smoothing ? GL.LINEAR : GL.NEAREST;
                    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);
                    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);

                    GL.uniform1i(uniform.location, curTextureSlot);

                    curTextureSlot++;

                case BITMAP(bitmap, smoothing):
                    if (bitmap == null) continue;

                    GL.activeTexture(GL.TEXTURE0 + curTextureSlot);
                    @:privateAccess
                    GL.bindTexture(GL.TEXTURE_2D, bitmap.getTexture(FlxG.stage.context3D).__getTexture());

                    final filter = smoothing ? GL.LINEAR : GL.NEAREST;
                    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);
                    GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);

                    GL.uniform1i(uniform.location, curTextureSlot);

                    curTextureSlot++;

                default: 
            }
        }
        #end
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

    function _processSource(shader:GLSLShader):String
    {
        var prefix:StringBuf = new StringBuf();

        var versionRegex = ~/^#version/m;

        if (shader.version != null)
        {
            if (!versionRegex.match(shader.source))
                prefix.add('#version ${shader.version}\n');
            else
                FlxG.log.warn("Can't inject shader version because the shader code already specifies it!");

            // if (shader.allowConvert)
            // {
            //     // Based off of the implementation by EliteMasterEric (https://github.com/openfl/openfl/pull/2722)
            //     var attributeRegex = ~/attribute ([A-Za-z0-9]+) ([A-Za-z0-9_]+)/g;
            //     var varyingRegex = ~/varying ([A-Za-z0-9]+) ([A-Za-z0-9_]+)/g;

            //     var texture2DRegex = ~/texture2D/g;
            //     var glFragColorRegex = ~/gl_FragColor/g;

            //     switch (shader.version)
            // }
        }

        var precisionRegex = ~/^precision/m;

        // Precision qualifiers are only supported on OpenGL ES and WebGL
        if (GL.type != OPENGL && shader.precision != null)
        {
            if (!precisionRegex.match(shader.source))
            {
                prefix.add("#ifdef GL_ES\n");

                // Not all GPUs support high precision so we have to see if its available
                // and fallback to medium if it's not
                if (shader.precision == HIGH)
                {
                    prefix.add("#ifdef GL_FRAGMENT_PRECISION_HIGH\n");
                    prefix.add("precision highp float;\n");
                    prefix.add("#else\n");
                    prefix.add("precision mediump float;\n");
                    prefix.add("#endif\n");
                }
                else
                {
                    prefix.add('precision ${shader.precision} float;\n');
                }

                prefix.add("#endif\n");
            }
            else
                FlxG.log.warn("Can't inject shader precision qualifier because the shader code already specifies it!");
        }

        prefix.add("\n");

        return prefix.toString() + shader.source;
    }

    function _createShaderHandle(data:FlxShaderData):FlxShaderHandle
    {
        // TODO: use default shader data when certain params are null

        #if !flash
        if (data.flash != null)
        {
            var fshader = data.flash.shader;

            // https://github.com/openfl/openfl/blob/de55e8c592826d6f56b424badeaf2eebd1a7b0c2/src/openfl/display/OpenGLRenderer.hx#L537-L554
            @:privateAccess
            {
                if (fshader.__context == null)
                {
                    fshader.__context = FlxG.stage.context3D;
                    fshader.__init();
                }
            }

            return fshader.glProgram;
        }
        #end

        function createShader(type:Int, data:GLSLShader):GLShader 
        {
            var shader = GL.createShader(type);
            var src = _processSource(data);
            GL.shaderSource(shader, src);
            GL.compileShader(shader);

            if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0)
            {
                var error = GL.getShaderInfoLog(shader);
                trace('Error compiling ${type == GL.FRAGMENT_SHADER ? 'fragment' : 'vertex'} shader:\n$error');
                trace(src);
            }

            return shader;
        }

        var program = GL.createProgram();

        if (data.glsl.vertex != null)
        {
            var vs = createShader(GL.VERTEX_SHADER, data.glsl.vertex);
            GL.attachShader(program, vs);

            // Before linking the shader program we want to ensure our attributes
            // will be assigned to the locations we want them to be in
            // This is so that we can take advantage of VAOs properly
            if (data.glsl.vertex.attributes != null)
            {
                for (i in 0...data.glsl.vertex.attributes.length)
                {
                    GL.bindAttribLocation(program, i, data.glsl.vertex.attributes[i]);
                }
            }
        }

        if (data.glsl.fragment != null)
        {
            var fs = createShader(GL.FRAGMENT_SHADER, data.glsl.fragment);
            GL.attachShader(program, fs);
        }

        GL.linkProgram(program);

        if (GL.getProgramParameter(program, GL.LINK_STATUS) == 0)
        {
            var error = GL.getProgramInfoLog(program);
            trace('Error linking program:\n$error');
        }

        return program;
    }

    function _createShaderUniformMap(handle:FlxShaderHandle):StringMap<FlxShaderUniform>
    {
        var uniforms = new StringMap<FlxShaderUniform>();

        var numUniforms = GL.getProgramParameter(handle, GL.ACTIVE_UNIFORMS);
        for (i in 0...numUniforms)
        {
            var info = GL.getActiveUniform(handle, i);
            var location = GL.getUniformLocation(handle, info.name);

            var uniform:FlxShaderUniform = 
            {
                name: info.name,
                location: location,
                value: switch (info.type) 
                {
                    case GL.FLOAT: FLOAT1(0);
                    case GL.FLOAT_VEC2: FLOAT2(0, 0);
                    case GL.FLOAT_VEC3: FLOAT3(0, 0, 0);
                    case GL.FLOAT_VEC4: FLOAT4(0, 0, 0, 0);

                    // GLSL booleans can be represented with an int
                    // 0x9108 = GL.SAMPLER_2D_MULTISAMPLE
                    case GL.INT, GL.BOOL, GL.SAMPLER_2D, 0x9108: INT1(0);
                    case GL.INT_VEC2, GL.BOOL_VEC2: INT2(0, 0);
                    case GL.INT_VEC3, GL.BOOL_VEC3: INT3(0, 0, 0);
                    case GL.INT_VEC4, GL.BOOL_VEC4: INT4(0, 0, 0, 0);

                    case GL.FLOAT_MAT4: MATRIX(null, MAT4X4, false);
                    case GL.FLOAT_MAT3: MATRIX(null, MAT3X3, false);
                    case GL.FLOAT_MAT2: MATRIX(null, MAT2X2, false);
                    case GL.FLOAT_MAT2x3: MATRIX(null, MAT2X3, false);
                    case GL.FLOAT_MAT2x4: MATRIX(null, MAT2X4, false);
                    case GL.FLOAT_MAT3x2: MATRIX(null, MAT3X2, false);
                    case GL.FLOAT_MAT3x4: MATRIX(null, MAT3X4, false);
                    case GL.FLOAT_MAT4x2: MATRIX(null, MAT4X2, false);
                    case GL.FLOAT_MAT4x3: MATRIX(null, MAT4X3, false);

                    // TODO: temporary throw until I figure out what's missing
                    default: throw 'Unsupported ${info.name} ${info.type})';
                }
            };

            uniforms.set(info.name, uniform);
        }

        return uniforms;
    }

    function _destroyShaderHandle(handle:FlxShaderHandle):Void 
    {
        GL.deleteProgram(handle);    
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
         * Optional ordered array of vertex attribute names.
         * If this is provided, the vertex attribute locations will be bound to their corresponding index
         * in the array. 
         * If your shaders share the same vertex attributes, you should bind them in the same order so the
         * renderer can take advantage of internal optimisations.
         */
        @:optional var attributes:Array<String>;
    };

    /**
     * Data for the fragment shader.
     */
    var fragment:GLSLShader;
}

typedef GLSLShader = 
{
    /**
     * The GLSL source code for the shader.
     */
    var source:String;

    /**
     * The wanted GLSL shader version.
     * 
     * Note that this will be ignored if the version is already set in the GLSL shader code.
     */
    @:optional var version:String;

    /**
     * When enabled, if the GLSL shader source is written against an older version, but
     * the target version is higher, Flixel will process the shader code and attempt to convert
     * it to be compatible with the target version.
     */
    @:optional var allowConvert:Bool;

    /**
     * The wanted floating-point precision for the shader.
     * This only has an effect when targeting OpenGL ES (mobile) or WebGL (HTML5).
     * 
     * Note that this will be ignored if the precision qualifier is already
     * set in the GLSL shader code.
     */
    @:optional var precision:GLSLPrecision;

    @:optional var extensions:Array<GLShaderExtension>;
}

typedef GLShaderExtension =
{
    name:String,
    behavior:GLShaderExtensionBehavior
}

enum abstract GLSLPrecision(String) from String to String
{
    var HIGH = "highp";
    var MEDIUM = "mediump";
    var LOW = "lowp";
}

enum abstract GLShaderExtensionBehavior(String) from String to String
{
    var REQUIRE = "require";
    var ENABLE = "enable";
    var WARN = "warn";
    var DISABLE = "disable";
}

@:structInit
class FlxShaderUniform
{
    public var name:String;
    public var location:FlxShaderUniformLocation;
    public var value(default, set):FlxShaderUniformValue;
    public var dirty:Bool = false;

    // var initialValueName:Null<String> = null;

    function set_value(value:FlxShaderUniformValue) 
    {
        // if (initialValueName == null) 
        // {
        //     initialValueName = value.getName();
        // } 
        // else 
        // {
        //     if (initialValueName != value.getName())
        //     {
        //         FlxG.log.error("Can't change shader uniform type");
        //         return this.value;
        //     }
        // }
        this.dirty = true;
        return this.value = value;
    }
}

enum FlxShaderUniformValue
{
    INT1(v:Int);
    INT2(v1:Int, v2:Int);
    INT3(v1:Int, v2:Int, v3:Int);
    INT4(v1:Int, v2:Int, v3:Int, v4:Int);
    INT_ARRAY(v:Int32Array, dimension:FlxShaderArrayDimension);

    FLOAT1(v:Float);
    FLOAT2(v1:Float, v2:Float);
    FLOAT3(v1:Float, v2:Float, v3:Float);
    FLOAT4(v1:Float, v2:Float, v3:Float, v4:Float);
    FLOAT_ARRAY(v:Float32Array, dimension:FlxShaderArrayDimension);

    MATRIX(v:Float32Array, type:FlxShaderMatrixType, transpose:Bool);

    TEXTURE(v:FlxTexture, smoothing:Bool);

    // Temporary backwards compatibility stuff
    BITMAP(v:BitmapData, smoothing:Bool);
}

enum FlxShaderMatrixType
{
    MAT4X4;
    MAT3X3;
    MAT2X2;

    MAT2X3; 
    MAT2X4;
    MAT3X2;
    MAT3X4;
    MAT4X2;
    MAT4X3;
}

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
