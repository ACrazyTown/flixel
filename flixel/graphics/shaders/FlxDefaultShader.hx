package flixel.graphics.shaders;

import flixel.graphics.shaders.FlxShader.FlxShaderData;

// TODO: Instead of modifying FlxDefaultShader.defaultShaderData consider something like
// FlxG.renderer.defaultShaderData

/**
 * The default single texture shader.
 */
class FlxDefaultShader extends FlxShader
{
    /**
     * The data for the default shader.
     * The default value of optionals left blank will be picked from here.
     */
    public static var defaultShaderData:FlxShaderData = 
    {
        glsl: {
            vertex: {
                source: "
                    attribute vec4 flixel_aPosition;
                    attribute vec4 flixel_aColorMultiplier;
                    attribute vec4 flixel_aColorOffset;
                    attribute vec2 flixel_aTextureCoord;

                    uniform mat4 flixel_uMatrix;

                    varying vec4 flixel_vColorMultiplier;
                    varying vec4 flixel_vColorOffset;
                    varying vec2 flixel_vTextureCoord;

                    void main()
                    {
                        // The colors are ARGB but because of little endian they are stored as BGRA
                        flixel_vColorMultiplier = flixel_aColorMultiplier.bgra;
                        flixel_vColorOffset = flixel_aColorOffset.bgra;

                        flixel_vTextureCoord = flixel_aTextureCoord;

                        gl_Position = flixel_uMatrix * flixel_aPosition;
                        gl_PointSize = 1.0;
                    }",
                attributes: [
                    "flixel_aPosition",
                    "flixel_aColorMultiplier",
                    "flixel_aColorOffset",
                    "flixel_aTextureCoord"
                ],
                version: null,
                precision: HIGH
            },
            fragment: {
                source: "
                    void main()
                    {
                        gl_FragColor = flixel_texture(flixel_uTexture, flixel_vTextureCoord);
                    }",
                version: null,
                precision: HIGH,
                injectBuiltins: true
            }
        }
    }

    public function new()
    {
        super(defaultShaderData);
    }
}
