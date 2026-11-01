package flixel.graphics.shaders.glsl;

import flixel.graphics.shaders.glsl.GLSLProgram;

using StringTools;

/**
 * Processes standard Flixel shaders that use `#pragma header` and `#pragma body` defines.
 * Additionally applies default values for `vertexSource`, `vertexAttributes` and `fragmentSource`,
 * so even a newly created `FlxGLSLProgram` is valid.
 * 
 * Example usage:
 * ```haxe
 * var program = new FlxGLSLProgram();
 * 
 * // Currently, vertex and fragment shader sources are both required for a shader to be valid.
 * program.vertexSource = myVertexSource;
 * 
 * // Note the `#pragma header`, here. This will automatically be replaced with 
 * // `FlxGLSLProgram.DEFAULT_FRAGMENT_HEADER` when the shader gets created.
 * program.fragmentSource = 
 * "#pragma header
 * 
 * void main() {
 *     // Tints everything green
 *     gl_FragColor = flixel_texture(flixel_uTexture, flixel_vTextureCoord) * vec4(0.0, 1.0, 0.0, 1.0);
 * }";
 * 
 * var shader = new FlxShader({glsl: program});
 * ```
 * 
 * @see `GLSLProgram` for info on other properties.
 */
class FlxGLSLProgram extends GLSLProgram
{
    public static final DEFAULT_VERTEX_HEADER:String = "attribute vec4 flixel_aPosition;
attribute vec4 flixel_aColorMultiplier;
attribute vec4 flixel_aColorOffset;
attribute vec2 flixel_aTextureCoord;

uniform mat4 flixel_uMatrix;

varying vec4 flixel_vColorMultiplier;
varying vec4 flixel_vColorOffset;
varying vec2 flixel_vTextureCoord;";

    public static final DEFAULT_VERTEX_BODY:String = "// The colors are ARGB but because of little endian they are stored as BGRA
    flixel_vColorMultiplier = flixel_aColorMultiplier.bgra;
    flixel_vColorOffset = flixel_aColorOffset.bgra;
    flixel_vTextureCoord = flixel_aTextureCoord;

    gl_Position = flixel_uMatrix * flixel_aPosition;";

    public static final DEFAULT_FRAGMENT_HEADER:String = "varying vec4 flixel_vColorMultiplier;
varying vec4 flixel_vColorOffset;
varying vec2 flixel_vTextureCoord;

uniform sampler2D flixel_uTexture;
uniform vec2 flixel_uTextureSize;

vec4 flixel_texture(sampler2D sampler, vec2 coord)
{
    vec4 color = texture2D(sampler, coord);

    color = vec4(color.rgb / color.a, color.a);
    color = (color * flixel_vColorMultiplier) + flixel_vColorOffset;

    return vec4(color.rgb * color.a, color.a);
}

#define flixel_texture2D flixel_texture";

    public static final DEFAULT_VERTEX_SOURCE:String = "#pragma header   
void main()
{
    #pragma body
}";

    public static final DEFAULT_FRAGMENT_SOURCE:String = "#pragma header
void main()
{
    gl_FragColor = flixel_texture(flixel_uTexture, flixel_vTextureCoord);
}";

    public static final DEFAULT_VERTEX_ATTRIBUTES:Array<String> = [
        "flixel_aPosition", 
        "flixel_aColorMultiplier", 
        "flixel_aColorOffset", 
        "flixel_aTextureCoord"
    ];

    public static final HEADER_STUB:String = "#pragma header";
    public static final BODY_STUB:String = "#pragma body";

    override function prepare() 
    {
        if (vertexSource == null) vertexSource = DEFAULT_VERTEX_SOURCE;
        if (vertexAttributes == null) vertexAttributes = DEFAULT_VERTEX_ATTRIBUTES;

        if (fragmentSource == null) fragmentSource = DEFAULT_FRAGMENT_SOURCE;

        super.prepare();
    }

    override function prepareSource(source:String, type:GLSLShaderType):String 
    {
        source = switch type
        {
            case VERTEX: source.replace(HEADER_STUB, DEFAULT_VERTEX_HEADER).replace(BODY_STUB, DEFAULT_VERTEX_BODY);
            case FRAGMENT: source.replace(HEADER_STUB, DEFAULT_FRAGMENT_HEADER);
        }

        return super.prepareSource(source, type);
    }
}
