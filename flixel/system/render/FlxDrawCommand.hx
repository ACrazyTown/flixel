package flixel.system.render;

import flixel.graphics.shaders.FlxShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.shaders.FlxBaseShader;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.graphics.FlxMaterial;
import flixel.math.FlxRect;

class FlxDrawCommand implements IFlxDestroyable
{
    var type:FlxDrawCommandType;

	var graphic:FlxGraphic;
    var shader:FlxBaseShader;
	var material:FlxMaterial;
	var colored:Bool;
	var hasColorOffsets:Bool;

    public function new() {}

    public function destroy():Void 
    {
        graphic = null;
        material = null;
        shader = null;
    }

    public function reset():Void
    {
        graphic = null;
        material = null;
        shader = null;
        colored = false;
        hasColorOffsets = false;
    }

    public function flush():Void {}

    public function addQuad(frame:FlxFrame, material:FlxMaterial, matrix:FlxMatrix, ?transform:ColorTransform):Void {}

	public function addUVQuad(graphic:FlxGraphic, material:FlxMaterial, rect:FlxRect, uv:FlxUVRect, matrix:FlxMatrix, ?transform:ColorTransform):Void {}

    public function set(graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool):Void
    {
        this.graphic = graphic;
        this.material = material;
        this.colored = colored;
        this.hasColorOffsets = hasColorOffsets;
    }

	public function equals(type:FlxDrawCommandType, graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool):Bool
	{
		return this.type == type
            && this.graphic == graphic
			&& this.material.equals(material, false)
			&& this.colored == colored
			&& this.hasColorOffsets == hasColorOffsets;
	}
}

enum abstract FlxDrawCommandType(Int) from Int to Int
{
    var QUADS = 0;
    var TRIANGLES = 1;
}
