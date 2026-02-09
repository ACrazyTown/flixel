package flixel.system.render.gl;

import flixel.graphics.shaders.FlxShader;

class FlxTexturedShader extends FlxShader
{
    @:glVertexHeader("
        attribute vec2 aTexCoord;

        uniform vec2 uTextureSize;

        varying vec2 vTexCoord;
    ", true)
    @:glVertexBody("
        vTexCoord = aTexCoord;
    ", true)
    @:glFragmentHeader("
        varying vec2 vTexCoord;

        uniform sampler2D uImage0;

        vec4 flixel_texture2D(sampler2D sampler, vec2 coord)
        {
            vec4 color = texture2D(sampler, coord);

            if (color.a == 0.0)
            {
                return vec4(0.0, 0.0, 0.0, 0.0);
            }
            
            color *= vColor;
            return vec4(color.rgb * color.a, color.a);
        }
    ", true)
    @:glFragmentSource("
        #pragma header

        void main()
        {
            gl_FragColor = flixel_texture2D(uImage0, vTexCoord);
        }
    ", true)

    public function new()
    {
        super();
    }
}
