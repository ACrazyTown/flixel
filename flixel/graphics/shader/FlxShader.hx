package flixel.graphics.shader;

import openfl.display.Shader;

typedef FlxShader = #if FLX_RENDER_TILES FlxGraphicsShader #else Shader #end;
