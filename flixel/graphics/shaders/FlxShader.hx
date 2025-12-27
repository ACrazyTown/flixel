package flixel.graphics.shaders;

typedef FlxShader = #if FLX_RENDER_GL flixel.system.render.gl.FlxBaseShader #else flixel.system.render.quad.FlxGraphicsShader #end
