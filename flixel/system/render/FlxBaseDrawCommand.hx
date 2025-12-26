package flixel.system.render;

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

    public function flush(?view:FlxCameraView):Void {}

    public function equals(type:FlxDrawCommandType, graphic:FlxGraphic, material:FlxMaterial, colored:Bool, hasColorOffsets:Bool)
    {
        return (this.type == type
            && this.graphic == graphic
            && this.material.equals(material)
            && this.colored == colored
            && this.hasColorOffsets == hasColorOffsets);
    }
}

enum abstract FlxDrawCommandType(Int) from Int to Int
{
    var QUADS = 0;
    var TRIANGLES = 1;
}
