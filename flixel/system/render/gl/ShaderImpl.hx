package flixel.system.render.gl;

import flixel.system.render.gl.impl.GLUniformLocation;
import flixel.system.render.gl.impl.GL;
import flixel.system.render.gl.impl.GLShader;
import flixel.system.render.gl.impl.GLProgram;

// temporary!
class ShaderImpl
{
    var vertexSource:String;
    var fragmentSource:String;

    public var glProgram:GLProgram;
    var glVertexShader:GLShader;
    var glFragmentShader:GLShader;

    public function new() {}

    public function compile(vertexSource:String, fragmentSource:String):Void
    {
        this.vertexSource = vertexSource;
        glVertexShader = GL.createShader(GL.VERTEX_SHADER);
        GL.shaderSource(glVertexShader, vertexSource);
        GL.compileShader(glVertexShader);

        trace(vertexSource);

        // if (GL.getShaderi(glVertexShader, GL.COMPILE_STATUS) != 1) 
        // {
        //     var log = GL.getShaderInfoLog(glVertexShader);
        //     throw 'vertex shader fail\n$log';
        // }

        this.fragmentSource = fragmentSource;
        glFragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
        GL.shaderSource(glFragmentShader, fragmentSource);
        GL.compileShader(glFragmentShader);

        trace(fragmentSource);

        // if (GL.getShaderi(glFragmentShader, GL.COMPILE_STATUS) != 1) 
        // {
        //     var log = GL.getShaderInfoLog(glFragmentShader);
        //     throw 'fragment shader fail\n$log';
        // }
    }

    public function link():Void
    {
        glProgram = GL.createProgram();
        GL.attachShader(glProgram, glVertexShader);
        GL.attachShader(glProgram, glFragmentShader);
        GL.linkProgram(glProgram);

        GL.deleteShader(glVertexShader);
        GL.deleteShader(glFragmentShader);
    }

    public function getUniformLocation(name:String):GLUniformLocation
    {
        return GL.getUniformLocation(glProgram, name);
    }
}
