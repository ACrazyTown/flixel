package flixel.graphics.shaders;

// import flixel.graphics.shaders.FlxShaderUniforms;
import haxe.ds.StringMap;
import flixel.system.render.quad.FlxGraphicsShader;
import openfl.display.Shader;
import lime.graphics.opengl.GLShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import lime.graphics.opengl.GL;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import flixel.system.FlxAssets.FlxShader as FlxLegacyShader;
import openfl.display.ShaderParameter;
import lime.math.Matrix4;
import lime.utils.ArrayBufferView;

// typedef FlxShaderAttributeLocation = Int;
typedef FlxShaderUniformLocation = lime.graphics.opengl.GLUniformLocation;
typedef FlxShaderHandle = lime.graphics.opengl.GLProgram;

/**
 * A `FlxShader` represents a single-pass shader program used to render a sprite.
 */
@:haxe.warning("-WDeprecated")
class FlxShader implements IFlxDestroyable
{
    // TODO: dispose
    // These are for internal use only, and will be removed once support for OpenFL shaders is dropped in v7
    @:noCompletion
    static var flashCache:Map<FlxLegacyShader, FlxShader> = [];

    @:noCompletion
    static var flashAttributeNames:Map<String, String> = [
        "aPosition" => "openfl_Position",
        "aTexCoord" => "openfl_TextureCoord",
        "aColorMultiplier" => "openfl_ColorMultiplier",
        "aColorOffset" => "openfl_ColorOffset"
    ];

    @:noCompletion
    static var flashUniformNames:Map<String, String> = [
        "uMatrix" => "openfl_Matrix",
        "uTextureSize" => "openfl_TextureSize",
        "uImage0" => "bitmap",
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

    // public var uniforms(default, null):FlxShaderUniforms;

    var _handle:FlxShaderHandle;
    var _uniforms:Map<String, FlxShaderUniform>;

    public function new(data:FlxShaderData) 
    {
        this.data = data;

        _handle = _createShaderHandle(data);
        // uniforms = _createShaderUniforms(this);
        _uniforms = _createShaderUniformMap(_handle);
    }

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
    }


    /**
     * Returns the location of the `name` shader uniform.
     * If the uniform doesn't exist (not present at all or was unused and the shader compiler removed it), the returned
     * location will be `null`.
     * 
     * @param name 
     * @return Null<FlxShaderUniformLocation>
     */
    public function getUniformLocation(name:String):Null<FlxShaderUniformLocation>
    {
        if (data.flash != null)
        {
            inline function getOpenFLUniform(name:String):Dynamic
                return cast Reflect.field(data.flash.shader, name);

            // Hacky backwards compatibility solution for legacy shaders
            // Since new GL shaders have different variable names, we will try remapping them to the old OpenFL ones
            // (if the initial check fails)
            var uniform = getOpenFLUniform(name);
            if (uniform == null)
                uniform = getOpenFLUniform(flashUniformNames.get(name));

            return uniform != null ? cast uniform.index : null;
        }

        var uniform = _uniforms.get(name);
        return uniform != null ? uniform.location : null;
    }

    public function getAttributeLocation(name:String):Null<Int>
    {
        if (data.flash != null)
        {
            inline function getOpenFLAttribute(name:String):Dynamic
                return cast Reflect.field(data.flash.shader, name);

            // Hacky backwards compatibility solution for legacy shaders
            // Since new GL shaders have different variable names, we will try remapping them to the old OpenFL ones
            // (if the initial check fails)
            var attribute = getOpenFLAttribute(name);
            if (attribute == null)
                attribute = getOpenFLAttribute(flashAttributeNames.get(name));
            
            return attribute != null ? cast attribute.index : null;
        }

        return GL.getAttribLocation(_handle, name);
    }

    // public function setUniformInt(name:String, v1:Int):Void
    // {
    //     if (data.flash != null) 
    //     {
    //         setFlashShaderUniform(name, [v1]);
    //         return;
    //     }

    //     var uniform = _uniforms.get(name);
    //     if (uniform == null) 
    //     {
    //         FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
    //         return; 
    //     }

    //     uniform.value = INT1(v1);
    // }

    // public function setUniformInt2(name:String, v1:Int, v2:Int):Void
    // {
    //     if (data.flash != null)
    //     {
    //         setFlashShaderUniform(name, [v1, v2]);
    //         return;
    //     }

    //     var uniform = _uniforms.get(name);
    //     if (uniform == null) 
    //     {
    //         FlxG.log.error('Can\'t set non-existant shader uniform "$name"');
    //         return; 
    //     }
        
    //     uniform.value = INT2(v1, v2);
    // }

    // INT1-4

    overload extern public inline function setUniform(name:String, v1:Int) 
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

    overload extern public inline function setUniform(name:String, v1:Int, v2:Int) 
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

    overload extern public inline function setUniform(name:String, v1:Int, v2:Int, v3:Int) 
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

    overload extern public inline function setUniform(name:String, v1:Int, v2:Int, v3:Int, v4:Int) 
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

    // INT ARRAY
    overload extern public inline function setUniform(name:String, v:Array<Int>)
    {
        if (data.flash != null)
        {
            FlxG.log.error("OpenFL shaders do not support uniform arrays.");
            return;
        }

        setUniform(name, new Int32Array(v));
    }

    // FLOAT1-4

    overload extern public inline function setUniform(name:String, v1:Float) 
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

    overload extern public inline function setUniform(name:String, v1:Float, v2:Float) 
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

    overload extern public inline function setUniform(name:String, v1:Float, v2:Float, v3:Float) 
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

    overload extern public inline function setUniform(name:String, v1:Float, v2:Float, v3:Float, v4:Float) 
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

    overload extern public inline function setUniform(name:String, v:Array<Float>)
    {
        if (data.flash != null)
        {
            FlxG.log.error("OpenFL shaders do not support uniform arrays.");
            return;
        }

        setUniform(name, new Float32Array(v));
    }

    // This would've been seperated into two methods for Float32Array and Int32Array
    // but both of those are an abstract over ArrayBufferView and therefore were causing ambiguous overload errors
    overload extern public inline function setUniform(name:String, v:ArrayBufferView)
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

        if (v.type == Float32)
            uniform.value = FLOATV(v);
        else if (v.type == Int32)
            uniform.value = INTV(v);
        else
            FlxG.log.error('Unsupported array type for uniform "$name". Should be Float32 or Int32.');
    }

    // BOOL

    overload extern public inline function setUniform(name:String, v1:Bool) 
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

        uniform.value = INT1(v1 ? 1 : 0);
    }

    overload extern public inline function setUniform(name:String, v1:Bool, v2:Bool) 
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

        uniform.value = INT2(v1 ? 1 : 0, v2 ? 1 : 0);
    }

    overload extern public inline function setUniform(name:String, v1:Bool, v2:Bool, v3:Bool) 
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

        uniform.value = INT3(v1 ? 1 : 0, v2 ? 1 : 0, v3 ? 1 : 0);
    }

    overload extern public inline function setUniform(name:String, v1:Bool, v2:Bool, v3:Bool, v4:Bool) 
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

        uniform.value = INT4(v1 ? 1 : 0, v2 ? 1 : 0, v3 ? 1 : 0, v4 ? 1 : 0);
    }

    overload extern public inline function setUniform(name:String, v:Array<Bool>)
    {
        var i:Array<Int> = [for (b in v) b ? 1 : 0];
        setUniform(name, i);
    }

    @:allow(flixel.system.render)
    function updateUniforms():Void
    {
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

                case FLOAT1(v): GL.uniform1f(uniform.location, v);
                case FLOAT2(v1, v2): GL.uniform2f(uniform.location, v1, v2);
                case FLOAT3(v1, v2, v3): GL.uniform3f(uniform.location, v1, v2, v3);
                case FLOAT4(v1, v2, v3, v4): GL.uniform4f(uniform.location, v1, v2, v3, v4);

                default: 
            }
        }
    }

    function setFlashShaderUniform<T>(name:String, value:T):Void
    {
        if (data.flash != null)
        {
            final param:ShaderParameter<T> = Reflect.field(data.flash.shader.data, name);
            if (param == null)
            {
                FlxG.log.error('Can\'t set nonexistent shader uniform "$name"');
                return;
            }

            param.value = cast value;
        }
    }

    function _processSource(shader:GLSLShader):String
    {
        var prefix:StringBuf = new StringBuf();

        if (shader.version != null)
        {
            prefix.add('#version ${shader.version}\n');
        }

        if (shader.precision != null)
        {
            prefix.add("#ifdef GL_ES\n");

            // Not all GPUs support high precision so we have to see if its available
            // and fallback to medium if it's not
            if (shader.precision == HIGH)
            {
                prefix.add("#ifdef GL_FRAGMENT_PRECISION_HIGH\n");
                prefix.add("precision highp float;\n");
                prefix.add("#elseif\n");
                prefix.add("precision mediump float;\n");
                prefix.add("#endif\n");
            }
            else
            {
                prefix.add('precision ${shader.precision} float;\n');
            }

            prefix.add("#endif\n");
        }

        prefix.add("\n");

        return prefix.toString() + shader.source;
    }

    function _createShaderHandle(data:FlxShaderData):FlxShaderHandle
    {
        // TODO: use default shader data when certain params are null

        if (data.flash != null)
        {
            var fshader = data.flash.shader;

            trace(fshader);

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

        function createShader(type:Int, data:GLSLShader):GLShader 
        {
            var shader = GL.createShader(type);
            GL.shaderSource(shader, _processSource(data));
            GL.compileShader(shader);

            if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0)
            {
                var error = GL.getShaderInfoLog(shader);
                trace('Error compiling ${type == GL.FRAGMENT_SHADER ? 'fragment' : 'vertex'} shader:\n$error');
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

    // function _createShaderUniforms(shader:FlxShader):FlxShaderUniforms
    // {
    //     var uniforms = new FlxShaderUniforms(shader);

    //     var numUniforms = GL.getProgramParameter(shader._handle, GL.ACTIVE_UNIFORMS);
    //     for (i in 0...numUniforms)
    //     {
    //         var info = GL.getActiveUniform(shader._handle, i);
    //         var location = GL.getUniformLocation(shader._handle, info.name);
    //         // var value = GL.getUniform()
            
    //         trace(location, info.type, info.size, info.name);

    //         var type:FlxShaderUniformTypeWIP = switch (info.type) {
    //             case GL.FLOAT: FLOAT1(0);
    //             case GL.FLOAT_VEC2: FLOAT2(0, 0);
    //             case GL.FLOAT_VEC3: FLOAT3(0, 0, 0);
    //             case GL.FLOAT_VEC4: FLOAT4(0, 0, 0, 0);

    //             // GLSL booleans can be represented with an int
    //             case GL.INT, GL.BOOL: INT1(0);
    //             case GL.INT_VEC2, GL.BOOL_VEC2: INT2(0, 0);
    //             case GL.INT_VEC3, GL.BOOL_VEC3: INT3(0, 0, 0);
    //             case GL.INT_VEC4, GL.BOOL_VEC4: INT4(0, 0, 0, 0);

    //             case _: null;
    //         }

    //         var uniform:FlxShaderUniform = 
    //         {
    //             value: [],
    //             type: 0,
    //             size: info.size,
    //             location: location,
    //             dirty: false
    //         };
    //         uniforms._uniforms[info.name] = uniform;
    //     }

    //     return uniforms;
    // }

    function _createShaderUniformMap(handle:FlxShaderHandle):StringMap<FlxShaderUniform>
    {
        var uniforms = new StringMap<FlxShaderUniform>();

        var stamp = haxe.Timer.stamp();

        var numUniforms = GL.getProgramParameter(handle, GL.ACTIVE_UNIFORMS);
        for (i in 0...numUniforms)
        {
            var info = GL.getActiveUniform(handle, i);
            var location = GL.getUniformLocation(handle, info.name);


            // var u:Uniform<Dynamic>;

            // switch (info.type)
            // {
            //     case GL.FLOAT: var un:Uniform<Float> = {location: location, value: 0}
            //     case GL.FLOAT_VEC2: var un:Uniform<Vec2<Float>> = {location: location, value: {x: 0, y: 0}};
            // }

            // var umap:StringMap<Uniform<Dynamic>> = new StringMap<Uniform<Dynamic>>();

            // switch (info.type)
            // {
            //     case GL.FLOAT:
            //         var u:UniformFloat = {location: location, value: 0};
            //         umap.set(info.name, u);

            //     case GL.FLOAT_VEC2:
            //         var u:UniformVec2 = {location: location, value: {x: 0, y: 0}}
            //         umap.set(info.name, u);

            //     case GL.FLOAT_VEC3:
            //         var u:UniformVec3 = {location: location, value: {x: 0, y: 0, z: 0}};
            //         umap.set(info.name, u);

            //     case GL.FLOAT_VEC4:
            //         var u:UniformVec4 = {location: location, value: {x: 0, y: 0, z: 0, w: 0}};
            //         umap.set(info.name, u);

            //     case GL.INT:
            //         var u:UniformInt = {location: location, value: 0};
            //         umap.set(info.name, u);

            //     case GL.INT_VEC2:
            //         var u:UniformIVec2 = {location: location, value: {x: 0, y: 0}}
            //         umap.set(info.name, u);

            //     case GL.INT_VEC3:
            //         var u:UniformIVec3 = {location: location, value: {x: 0, y: 0, z: 0}};
            //         umap.set(info.name, u);

            //     case GL.INT_VEC4:
            //         var u:UniformIVec4 = {location: location, value: {x: 0, y: 0, z: 0, w: 0}};
            //         umap.set(info.name, u);
                    
            // }

            // trace(umap);
            
            trace('Detected ${info.name} (${info.type})');

            var uniform:FlxShaderUniform = 
            {
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

                    // Matrices can be represented as a int/float array
                    case GL.FLOAT_MAT4: FLOATV(new Float32Array(4 * 4));
                    case GL.FLOAT_MAT3: FLOATV(new Float32Array(3 * 3));

                    default: throw 'Unsupported ${info.name} ${info.type})';
                }
            };

            uniforms.set(info.name, uniform);
        }

        trace('Uniform assembly took ${(haxe.Timer.stamp()-stamp)*1000}ms');

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

// typedef FlxGLShaderData = 
// {
//     /**
//      * The wanted GLSL version
//      */
//     // var version:String;

//     // -- Vertex shader --
//     /**
//      * The GLSL source code for the vertex shader.
//      */
//      @:optional var vertexSource:String;

//     /**
//      * An array of ordered vertex attributes in the vertex shader.
//      * The order of the elements in the array will be used to determine
//      * their location in the shader.
//      */
//      @:optional var vertexAttributes:Array<String>;

//     /**
//      * The preferred floating-point precision for the vertex shader.
//      * Note that not all devices support all precision profiles, so this value may be ignored.
//      */
//     @:optional var vertexPrecision:GLShaderPrecision;

//     // -- Fragment shader --
//     /**
//      * The GLSL source code for the fragment shader.
//      */
//     var fragmentSource:String;

//     /**
//      * The preferred floating-point precision for the fragment shader.
//      * Note that not all devices support all precision profiles, so this value may be ignored.
//      */
//      @:optional var fragmentPrecision:GLShaderPrecision;

// }

typedef GLSLShader = 
{
    /**
     * The GLSL source code for the shader.
     */
    var source:String;

    @:optional var version:String;
    @:optional var precision:GLSLPrecision; // only does something on GLES/WebGL? 
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
private class FlxShaderUniform
{
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

        return this.value = value;
    }
}

enum FlxShaderUniformValue
{
    INT1(v:Int);
    INT2(v1:Int, v2:Int);
    INT3(v1:Int, v2:Int, v3:Int);
    INT4(v1:Int, v2:Int, v3:Int, v4:Int);
    INTV(v:Int32Array);

    FLOAT1(v:Float);
    FLOAT2(v1:Float, v2:Float);
    FLOAT3(v1:Float, v2:Float, v3:Float);
    FLOAT4(v1:Float, v2:Float, v3:Float, v4:Float);
    FLOATV(v:Float32Array);

    // MAT3X3(v:Float32Array);
    // MAT4X4(v:Float32Array);
}

// @:structInit
// class Uniform<T>
// {
//     public var location:FlxShaderUniformLocation;
//     public var value:T;
//     public var dirty:Bool = false;
// }

// typedef UniformFloat = Uniform<Float>;
// typedef UniformInt = Uniform<Int>;
// typedef UniformVec2 = Uniform<Vec2<Float>>;
// typedef UniformVec3 = Uniform<Vec3<Float>>;
// typedef UniformVec4 = Uniform<Vec4<Float>>;
// typedef UniformIVec2 = Uniform<Vec2<Int>>;
// typedef UniformIVec3 = Uniform<Vec3<Int>>;
// typedef UniformIVec4 = Uniform<Vec4<Int>>;

// @:structInit
// private class Vec2<T>
// {
//     public var x:T;
//     public var y:T;
// }

// @:structInit
// private class Vec3<T>
// {
//     public var x:T;
//     public var y:T;
//     public var z:T;
// }

// @:structInit
// private class Vec4<T>
// {
//     public var x:T;
//     public var y:T;
//     public var z:T;
//     public var w:T;
// }

// typedef FlxShaderUniform = 
// {
//     location:FlxShaderUniformLocation,
//     value:Dynamic,
//     dirty:Bool
// }

// enum FlxShaderUniformType
// {
//     FLOAT;

//     VEC2;
//     VEC3;
//     VEC4;

//     MAT2;
//     MAT3;
//     MAT4;

//     SAMPLER2D;
// }
