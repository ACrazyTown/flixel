package flixel.graphics.shaders.glsl;

import flixel.graphics.shaders.glsl.GLSLProgram;
import flixel.graphics.shaders.glsl.FlxGLSLProgram;

using StringTools;

/**
 * An extension of `FlxGLSLProgram` that allows custom shaders to batch multiple textures.
 * 
 * For the shader to be generated properly, you need to include two `#pragma` defines in your
 * shader code. See the example fragment shader for reference:
 * ```glsl
 * // Injects all the uniforms for the automatically generated samplers.
 * #pragma flixel_multitexture_uniforms
 *
 *  void main()
 *  {
 *      // Generates a big if-else chain that samples the correct texture into
 *      // the `flixel_multitexture_color` variable. 
 *      #pragma flixel_multitexture_sample
 * 
 *      // You can now do as you wish with the variable. Here we simply just display
 *      // the pixel as given, without modifying it.
 *      gl_FragColor = flixel_multitexture_color;
 *  }
 * ```
 * 
 * NOTE: This takes advantage of as many texture slots as possible, so shaders that require additional textures themselves will likely not work.
 */
class FlxMultiTextureGLSLProgram extends FlxGLSLProgram
{
    public static var maxTextures:Null<Int>;

    static final DEFAULT_FRAGMENT_SOURCE = "#pragma header

#pragma flixel_multitexture_uniforms

void main()
{
    #pragma flixel_multitexture_sample
    gl_FragColor = flixel_multitexture_color;
}";

    public static final DEFAULT_VERTEX_ATTRIBUTES:Array<String> = [
        "flixel_aPosition", 
        "flixel_aColorMultiplier", 
        "flixel_aColorOffset", 
        "flixel_aTextureCoord",
        "flixel_aTextureSlot"
    ];

    override function prepare() 
    {
        if (fragmentSource == null) fragmentSource = DEFAULT_FRAGMENT_SOURCE;
        if (vertexAttributes == null) vertexAttributes = DEFAULT_VERTEX_ATTRIBUTES;

        // Default vertex source is handled in super.prepare()
        super.prepare();
    }

    override function prepareSource(source:String, type:GLSLShaderType):String 
    {
        if (type == FRAGMENT)
        {
            if (maxTextures == null)
                maxTextures = FlxG.renderer.shaders.getMaxTexturesInShader();

            var uniforms:String = "varying float flixel_vTextureSlot;\n";
            for (i in 1...maxTextures)
                uniforms += 'uniform sampler2D flixel_uTexture$i;\n';

            var sample:String = "vec4 flixel_multitexture_color = vec4(0.0);\n";
            for (i in 0...maxTextures)
            {
                if (i > 0)
                    sample += "else ";

                if (i < maxTextures - 1)
                {
                    var slot:Int = maxTextures - 1 - i;
                    sample += 'if (flixel_vTextureSlot > ${slot - 0.5})\n{\nflixel_multitexture_color = flixel_texture(flixel_uTexture$slot, flixel_vTextureCoord);\n}\n';
                }
            }
            sample += "\n{\n";
            sample += "flixel_multitexture_color = flixel_texture(flixel_uTexture, flixel_vTextureCoord);\n";
            sample += "}\n";

            source = source.replace("#pragma flixel_multitexture_uniforms", uniforms).replace("#pragma flixel_multitexture_sample", sample);
        }
        else if (type == VERTEX) 
        {
            final header = "attribute float flixel_aTextureSlot;\nvarying float flixel_vTextureSlot;\n" + FlxGLSLProgram.DEFAULT_VERTEX_HEADER;
            final body = "flixel_vTextureSlot = flixel_aTextureSlot;\n" + FlxGLSLProgram.DEFAULT_VERTEX_BODY;

            source = source.replace(FlxGLSLProgram.HEADER_STUB, header).replace(FlxGLSLProgram.BODY_STUB, body);
        }

        return super.prepareSource(source, type);
    }
}
