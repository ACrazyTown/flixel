package flixel.system.render;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxGraphic;

class FlxBaseDrawCommand<T> implements IFlxDestroyable
{
    public var type:FlxDrawCommandType

    public var graphic:FlxGraphic;
    public var material:FlxMaterial;

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
    }

    public function flush(?view:FlxCameraView):Void {}
}

enum abstract FlxDrawCommandType(Int) from Int to Int
{
    var QUADS = 0;
    var TRIANGLES = 1;
}
