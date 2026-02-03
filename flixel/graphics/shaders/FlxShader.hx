package flixel.graphics.shaders;

typedef FlxShader = #if FLX_RENDER_OPENGL flixel.system.render.gl.FlxGLShader #else flixel.system.render.quad.FlxGraphicsShader #end;
