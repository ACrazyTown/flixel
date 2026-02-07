package flixel.system.render.gl;

import flixel.graphics.shaders.FlxShader;

class FlxTexturedShader extends FlxShader
{
    @:glVertexSource('
    // precision highp float;
    attribute vec4 aPosition;
    attribute vec2 aTexCoord;
    attribute vec4 aColor;
    attribute vec4 aColorOffset;
    
    uniform mat4 uMatrix;
    uniform vec2 uTextureSize;
    
    varying vec2 vTexCoord;
    varying vec4 vColor;
    varying vec4 vColorOffset;
    
    void main(void)
    {
        vTexCoord = aTexCoord;
        // OpenFl uses textures in bgra format, so we should convert colors...
        vColor = aColor.bgra;
        vColorOffset = aColorOffset.bgra;
        gl_Position = uMatrix * aPosition;
    }
    ')

    @:glFragmentSource('
    // precision highp float;
    varying vec2 vTexCoord;
    varying vec4 vColor;
    varying vec4 vColorOffset;
    
    uniform sampler2D uImage0;
    
    void main(void)
    {
        vec4 color = texture2D(uImage0, vTexCoord);
        
        if (color.a == 0.0)
        {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
        else
        {
            color = vec4(color.rgb / color.a, color.a);
            color = vColorOffset + (color * vColor);
            
            gl_FragColor = vec4(color.rgb * color.a, color.a);
            // gl_FragColor = vec4(0.0, 1.0, 0.5, 1.0);
        }
    }
    ')

    // @:glFragmentHeader("
    //     varying vec2 vTexCoord;
    //     varying vec4 vColor;
    //     varying vec4 vColorOffset
    // ")
    // @:glFragmentBody("
    //     vec4 color = texture2D(uImage0, vTexCoord);
    // ")

    public function new()
    {
        super();
    }
}
