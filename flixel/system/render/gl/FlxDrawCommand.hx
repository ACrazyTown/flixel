package flixel.system.render.gl;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxGraphic;

class FlxDrawCommand implements IFlxDestroyable
{
    var type:FlxDrawCommandType;

	var graphic:FlxGraphic;
	var material:FlxMaterial;
	var colored:Bool;
	var hasColorOffsets:Bool;

    public function new() {}

    public function destroy():Void 
    {
        graphic = null;
        material = null;
    }

    public function reset():Void
    {
        graphic = null;
        material = null;
        colored = false;
        hasColorOffsets = false;
    }

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
