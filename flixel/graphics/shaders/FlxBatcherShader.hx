package flixel.graphics.shaders;

import flixel.graphics.shaders.FlxShader.FlxShaderData;

/**
 * The default shader used by the renderer to batch differently textured sprites together.
 */
class FlxBatcherShader extends FlxShader
{
    public static var maxTextures:Null<Int>;

    static var _data:FlxShaderData = {
        glsl: {
            vertex: {
                source: "
                    attribute vec4 flixel_aPosition;
                    attribute vec4 flixel_aColorMultiplier;
                    attribute vec4 flixel_aColorOffset;
                    attribute vec2 flixel_aTextureCoord;
                    attribute float flixel_aTextureSlot;

                    uniform mat4 flixel_uMatrix;

                    varying vec4 flixel_vColorMultiplier;
                    varying vec4 flixel_vColorOffset;
                    varying vec2 flixel_vTextureCoord;
                    varying float flixel_vTextureSlot;

                    void main()
                    {
                        // The colors are ARGB but because of little endian they are stored as BGRA
                        flixel_vColorMultiplier = flixel_aColorMultiplier.bgra;
                        flixel_vColorOffset = flixel_aColorOffset.bgra;

                        flixel_vTextureCoord = flixel_aTextureCoord;
                        flixel_vTextureSlot = flixel_aTextureSlot;

                        gl_Position = flixel_uMatrix * flixel_aPosition;
                        gl_PointSize = 1.0;
                    }",
                attributes: [
                    "flixel_aPosition",
                    "flixel_aColorMultiplier",
                    "flixel_aColorOffset",
                    "flixel_aTextureCoord",
                    "flixel_aTextureSlot"
                ]
            },
            fragment: {
                source: null,
                injectBuiltins: true
            }
        }
    };

    public function new()
    {
        if (maxTextures == null)
        {
            var maxTextureUnits = FlxG.renderer.shaders.getMaxTexturesInShader();

            // The actual amount of max textures depends on how many if statements we can have in a shader.
            // Some drivers will outright refuse to compile a shader if it has too many if statements, so pick the smallest between the two
            maxTextures = Std.int(Math.min(maxTextureUnits, FlxG.renderer.shaders.getMaxIfStatementsInShader(maxTextureUnits)));

            var fragmentSource:StringBuf = new StringBuf();
            fragmentSource.add("varying float flixel_vTextureSlot;\n");

            // Generate all the samplers
            for (i in 1...maxTextures)
                fragmentSource.add('uniform sampler2D flixel_uTexture$i;\n');

            fragmentSource.add('void main()\n');
            fragmentSource.add('{\n');
            fragmentSource.add('vec4 color = vec4(0.0);\n');

            // Generate the if statements
            for (i in 0...maxTextures)
            {
                if (i > 0)
                    fragmentSource.add("else ");

                if (i < maxTextures - 1)
                {
                    var slot:Int = maxTextures - 1 - i;
                    fragmentSource.add('if (flixel_vTextureSlot > ${slot - 0.5})\n{\ncolor = flixel_texture(flixel_uTexture$slot, flixel_vTextureCoord);\n}\n');
                }
            }
            fragmentSource.add("\n{\n");

            fragmentSource.add('color = flixel_texture(flixel_uTexture, flixel_vTextureCoord);\n');
            fragmentSource.add('}\n');
            fragmentSource.add('gl_FragColor = color;\n');
            fragmentSource.add('}\n');

            _data.glsl.fragment.source = fragmentSource.toString();
        }

        super(_data);
    }
}
