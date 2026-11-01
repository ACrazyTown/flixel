package flixel.graphics.shaders.glsl;

import lime.graphics.opengl.GL;

/**
 * A `GLSLProgram` stores information needed to create a shader from GLSL sources.
 * It also does some minimal processing on the shader code (e.g. forcing a specific version), 
 * though extending classes can use this to implement additional functionality.
 * 
 * Note that this class expects the given shader code to be ready to be compiled. If you're working
 * with Flixel shaders that rely on `#pragma header` and the like you should use `FlxGLSLProgram` instead,
 * which will handle those templates properly!
 * 
 * Example usage:
 * ```haxe
 * var program = new GLSLProgram();
 * 
 * // Currently, vertex and fragment shader sources are both required for a shader to be valid.
 * // These sources MUST be ready to be compiled (i.e. no `#pragma` templates).
 * program.vertexSource = myVertexSource;
 * program.fragmentSource = myFragmentSource;
 * 
 * // These fields are optional
 * program.extensions.push({name: "GL_some_extension", behavior: ENABLE, shaderTypes: [FRAGMENT]});
 * program.version = "330 core";
 * program.precisionHint = MEDIUM;
 * 
 * var shader = new FlxShader({glsl: program});
 * ```
 */
class GLSLProgram 
{
    /**
     * Default GLSL version to use when compiling shaders.
     * 
	 * If left `null`, assume the lowest possible version will be used (`110` on desktop, `100` on mobile/web).
     */
    public static var DEFAULT_VERSION:Null<String> = null;

    /**
     * Default floating point precision.
     * This only affects shaders on mobile and web, as OpenGL always uses high precision on desktop.
     * Note that this is a hint, and `HIGH` precision may not be always available!
     */
    public static var DEFAULT_PRECISION_HINT:GLSLFloatPrecision = HIGH;

    /**
     * Floating point precision for this shader.
     * Note that this is a hint, and `HIGH` precision may not be always available!
     * 
     * If left `null`, the value of `DEFAULT_PRECISION_HINT` will be used instead.
     */
    public var precisionHint:Null<GLSLFloatPrecision> = DEFAULT_PRECISION_HINT;

    /**
     * GLSL version to use when compiling this shader.
     * 
     * NOTE: This version must be higher than the one specified in the shader (if any).
     * 
     * If left `null`, the value of `DEFAULT_VERSION` will be used instead.
     */
    public var version:Null<String> = DEFAULT_VERSION;

    /**
     * GLSL extensions to apply to the given sources.
     */
    public var extensions:Array<GLSLExtension> = [];

    /**
     * GLSL source code for the vertex shader.
     * This will be modified depending on other parameters of this `GLSLProgram`.
     */
    public var vertexSource:String;

    /**
     * Optional array of vertex attribute names in the vertex shader, ordered by the vertex location.
     * While it is optional, you should always strive to provide this as it
     * lets the renderer take advantage of some internal optimizations.
     * 
     * Note that modern GLSL versions let you specify vertex locations in the vertex shader,
     * in which case specifying this array is not needed.
     */
    public var vertexAttributes:Null<Array<String>>;

    /**
     * GLSL source code for the vertex shader.
     * This will be modified depending on other parameters of this `GLSLProgram`.
     */
    public var fragmentSource:String;

    public function new() {}

    /**
     * Ran right before shader compilation, calls `prepareSource()` on all non-null sources.
     * 
     * Extending implementations may override this to add custom logic before any sources are processed
     * (e.g. to set default values).
     * 
     * This is called internally by the renderer implementation prior to compiling the shader. 
     * Please don't call it yourself. Pretty please.
     */
    @:allow(flixel.system.render)
    function prepare():Void
    {
        if (vertexSource != null)
            vertexSource = prepareSource(vertexSource, VERTEX);

        if (fragmentSource != null)
            fragmentSource = prepareSource(fragmentSource, FRAGMENT);
    }

    /**
     * Processes a single shader source and applies the version override, float precision hint
     * and extensions.
     * 
     * Extending implementations may override this to add custom logic per shader type.
     * 
     * @param   source   Input GLSL shader source to be processed.
     * @param   type     The shader type.
     * @return  Processed shader source.
     */
    function prepareSource(source:String, type:GLSLShaderType):String
    {
        final version = this.version != null ? this.version : DEFAULT_VERSION;
        final precisionHint = this.precisionHint != null ? this.precisionHint : DEFAULT_PRECISION_HINT;

        var prefix:StringBuf = new StringBuf();
        var needsCompatDefines:Bool = false;

        final versionRegex = ~/^#version ([0-9]+) ?([a-z]*)/m;
        if (version != null)
        {
            var versionSplit = version.split(" ");
            final versionNumber = Std.parseInt(versionSplit[0]);
            final versionProfile = versionSplit.length > 1 ? versionSplit[1] : "";

            if (versionRegex.match(source))
            {
                if (versionNumber >= Std.parseInt(versionRegex.matched(1)))
                {
                    // Wipe original #version statement cause we're gonna inject stuff and we gotta make sure it goes first
                    source = versionRegex.replace(source, "");
                    prefix.add('#version $versionNumber $versionProfile\n\n');
                }
                else
                {
                    throw "The program version override cannot be lower than the version specified in the shader.";
                }
            }
            else
            {
                // source = '#version $versionNumber $versionProfile\n' + source;
                prefix.add('#version $versionNumber $versionProfile\n\n');
            }

            // Newer GLSL versions deprecate and remove some features, so we need to handle that if we're targeting a higher GLSL version
            // For OpenGL ES and WebGL we only have to check if we're targeting version 300 or higher
            // On desktop OpenGL we check if we're targeting version 130 or higher AND it's NOT a compatibility profile (which doesn't remove anything)
            // TODO: I wonder if there's a better way to check this without querying the GL class
            if ((GL.type == OPENGLES || GL.type == WEBGL) && versionNumber >= 300 ||
                (GL.type == OPENGL && versionNumber >= 130 && versionProfile != "compatibility"))
            {
                needsCompatDefines = true;
            }
        }
        else if (versionRegex.match(source))
        {
            // Wipe original #version statement cause we're gonna inject stuff and we gotta make sure it goes first
            source = versionRegex.replace(source, "");
            prefix.add('#version ${versionRegex.matched(1)} ${versionRegex.matched(2)}\n\n');
        }

        for (extension in extensions)
        {   
            if (extension.shaderTypes != null && !extension.shaderTypes.contains(type)) 
                continue;

            prefix.add('#extension ${extension.name} : ${extension.behavior}\n');
        }

        // Float precision can only be specified on mobile and web
        prefix.add("#ifdef GL_ES\n");

        if (precisionHint == HIGH)
        {
            // High precision is not guaranteed
            prefix.add("#ifdef GL_FRAGMENT_PRECISION_HIGH\n");
            prefix.add("precision highp float;\n");
            prefix.add("#else\n");
            prefix.add("precision mediump float;\n");
            prefix.add("#endif\n");
        }
        else
            prefix.add('precision $precisionHint float;\n');

        prefix.add("#endif\n");

        if (needsCompatDefines)
        {
            prefix.add("#ifndef FLIXEL_COMPAT_DEFINES\n");
            prefix.add("#define FLIXEL_COMPAT_DEFINES\n");
            prefix.add("#define texture2D texture\n");

            // Note that varying is input in a fragment shader, but output in a vertex shader.
            if (type == FRAGMENT)
            {
                prefix.add("#define varying in\n");
                prefix.add("out vec4 flixel_FragColor;\n");
                prefix.add("#define gl_FragColor flixel_FragColor\n");
            }
            else if (type == VERTEX)
            {
                prefix.add("#define attribute in\n");
                prefix.add("#define varying out\n");
            }

            prefix.add("#endif\n\n");
        }

        return prefix.toString() + source;
    }
}

typedef GLSLExtension = 
{
    /** Extension name. **/
    var name:String;

    /** Extension behavior. **/
    var behavior:GLSLExtensionBehavior;

	/**
	 * Optional array of shader types the extension should be applied to.
     *  
     * If left null, the extension will be applied to all provided sources.
	 */
    @:optional var shaderTypes:Array<GLSLShaderType>;
}

enum abstract GLSLExtensionBehavior(String) to String
{
    var ENABLE = "enable";
    var REQUIRE = "require";
    var WARN = "warn";
    var DISABLE = "disable";
}

enum abstract GLSLFloatPrecision(String) to String 
{
    var LOW = "lowp";
    var MEDIUM = "mediump";
    var HIGH = "highp";
}

enum GLSLShaderType
{
    VERTEX;
    FRAGMENT;
}
