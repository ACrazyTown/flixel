package flixel.system.render;

import flixel.graphics.frames.FlxFrame;
import openfl.geom.ColorTransform;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxGraphic;

class FlxBaseDrawCommand<T> implements IFlxDestroyable
{
    public var type:FlxDrawCommandType;

    public var graphic:FlxGraphic;
    public var material:FlxMaterial;
    public var colored:Bool = false;
    public var hasColorOffsets:Bool = false;

    public var textured(get, never):Bool;

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
        colored = false;
        hasColorOffsets = false;
    }

    public function flush(?view:FlxCameraView):Void {}

    public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform, material:FlxMaterial):Void {}

	public function addUVQuad(graphic:FlxGraphic, rect:FlxRect, uv:FlxUVRect, matrix:FlxMatrix, ?transform:ColorTransform, material:FlxMaterial):Void {}

    public function set(graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool):Void
    {
        this.graphic = graphic;
        this.material = material;
        this.colored = colored;
        this.hasColorOffsets = hasColorOffsets;
    }

    public function equals(type:FlxDrawCommandType, graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool)
    {
        return (this.type == type
            && this.graphic == graphic
            && this.material.equals(material)
            && this.colored == colored
            && this.hasColorOffsets == hasColorOffsets);
    }

    inline function get_textured():Bool
    {
        return graphic != null;
    }
}

enum abstract FlxDrawCommandType(Int) from Int to Int
{
    var QUADS = 0;
    var TRIANGLES = 1;
}
