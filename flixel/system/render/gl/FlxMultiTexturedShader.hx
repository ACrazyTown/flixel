package flixel.system.render.gl;

import lime.graphics.opengl.GL;
import flixel.graphics.shaders.FlxBaseShader;

using StringTools;

/**
 * Used by the renderer internally to batch sprites with different textures.
 * 
 * Basically just a copy of FlxTexturedShader, modified at runtime,
 * to allow passing in multiple textures and picking between them
 */
class FlxMultiTexturedShader extends FlxBaseShader
{
    /**
     * The maximum amount of textures this shader can batch together.
     */
    public static var maxTextures:Null<Int>;

    static var vertexSource:String = "
        attribute vec4 aPosition;
        attribute vec2 aTexCoord;
		attribute vec4 aColor;
        attribute float aTexSlot;

		uniform mat4 uMatrix;
        // uniform vec2 uTextureSize;

		varying vec4 vColor;
        varying vec2 vTexCoord;
        varying float vTexSlot;

        void main()
        {
            vColor = vec4(aColor.bgr * aColor.a, aColor.a);
            vTexCoord = aTexCoord;
            vTexSlot = aTexSlot;
            gl_Position = uMatrix * aPosition;
        }
    ";
    static var fragmentSource:String = "
        varying vec4 vColor;
        varying vec2 vTexCoord;
        varying float vTexSlot;

        uniform sampler2D uImage0;
        %FLX_MULTITEXTURE_SAMPLERS%

        vec4 flixel_texture2D(sampler2D sampler, vec2 coord)
        {
            vec4 color = texture2D(sampler, coord);
            color *= vColor;
            return vec4(color.rgb * color.a, color.a);
        }

        void main()
        {
            vec4 color = vec4(0.0);
            %FLX_MULTITEXTURE_IF%
            color = flixel_texture2D(uImage0, vTexCoord);
            %FLX_MULTITEXTURE_ENDIF%
            gl_FragColor = color;
        }
    ";

    public function new()
    {
        generateShader();

        // some internal hackery that would've usually been done by ShaderMacro,
        // but this shader was pieced together at runtime so we need to do it ourselves...
        __glVertexSource = vertexSource;
        __glFragmentSource = fragmentSource;

        super();
        __initGL();
    }

    function generateShader():Void
    {
        if (maxTextures == null)
        {
            // cap at 32 since that seems to be a hard limit for OpenGL
            var maxTextureUnits = Std.int(Math.min(cast GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS), 32));

            // we need to test how many if-else branches we can have in a shader
            var glslTemplate = "
            #ifdef GL_ES
            precision mediump float;
            #endif
            void main()
            {
                float test = 0.1;
                %CONDITIONS%
                gl_FragColor = vec4(0.0);
            }
            ";

            var maxIfs:Int = maxTextureUnits;
            while (maxIfs > 0) 
            {
                var glsl = glslTemplate.replace("%CONDITIONS%", generateTestIfs(maxIfs));
                if (!canCompileTestShader(glsl))
                    maxIfs = Std.int(maxIfs / 2);
                else
                    break;
            }

            maxTextures = Std.int(Math.min(maxTextureUnits, maxIfs));

            // generate all the samplers
            var samplers = "";
            for (i in 1...maxTextures)
                samplers += 'uniform sampler2D uImage$i;\n';

            // generate the if statements
            var ifs = "";
            for (i in 0...maxTextures)
            {
                if (i > 0)
                    ifs += "else ";

                if (i < maxTextures - 1)
                {
                    var slot:Int = maxTextures - 1 - i;
                    ifs += 'if (vTexSlot > ${slot - 0.5})\n{\ncolor = flixel_texture2D(uImage$slot, vTexCoord);\n}\n';
                }
            }
            ifs += "\n{";

            // finally update the fragment shader
            fragmentSource = fragmentSource.replace("%FLX_MULTITEXTURE_SAMPLERS%", samplers)
                .replace("%FLX_MULTITEXTURE_IF%", ifs)
                .replace("%FLX_MULTITEXTURE_ENDIF%", "\n}\n");
        }
    }

    function canCompileTestShader(glsl:String):Bool
    {
        var shader = GL.createShader(GL.FRAGMENT_SHADER);
        GL.shaderSource(shader, glsl);
        GL.compileShader(shader);

        var success:Bool = GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 1;

        GL.deleteShader(shader);
        return success;
    }

    function generateTestIfs(count:Int):String
    {
        var result:String = "";

        for (i in 0...count)
        {
            if (i > 0)
                result += "\nelse ";
            if (i < count - 1)
                result += 'if (test == $i.0) {}';
        }

        return result;
    }
}
