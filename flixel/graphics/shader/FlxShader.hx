package flixel.graphics.shader;

typedef FlxShader = #if FLX_RENDER_GL flixel.system.render.gl.FlxBaseShader #else flixel.system.render.quad.FlxGraphicsShader #end
