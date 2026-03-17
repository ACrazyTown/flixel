package flixel.system.render.gl;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxPool;
import openfl.display.BlendMode;
import openfl.display.Shader;
import openfl.geom.ColorTransform;

/**
 * Helper, stores data about a queued sprite to draw.
 */
class FlxDrawData implements IFlxPooled
{
    public var texture:FlxGraphic;
    public var textureSmoothing:Bool;
    public var textureRepeat:Bool;

    public var shader:Shader;
    public var blend:BlendMode;
    public var colorTransform:ColorTransform;

    // FlxSprite.drawComplexMatrix (the matrix we receive when drawing)
    // is static so we store the values here to avoid issues where the ref changes 
    public var mtx:Float;
    public var mty:Float;
    public var ma:Float;
    public var mb:Float;
    public var mc:Float;
    public var md:Float;

    function new() {}

    public function destroy():Void {}

    public function set(texture:FlxGraphic, smoothing:Bool, repeat:Bool, shader:Shader, blend:BlendMode, transform:ColorTransform, matrix:FlxMatrix)
    {
        this.texture = texture;
        this.textureSmoothing = smoothing;
        this.textureRepeat = repeat;
        this.shader = shader;
        this.blend = blend;
        this.colorTransform = transform;
        
        updateMatrix(matrix);
    }

    public inline function updateMatrix(matrix:FlxMatrix):Void
    {
        if (matrix == null)
        {
            mtx = 0;
            mty = 0;
            ma = 1;
            mb = 0;
            mc = 0;
            md = 1;
        }
        else
        {
            mtx = matrix.tx;
            mty = matrix.ty;
            ma = matrix.a;
            mb = matrix.b;
            mc = matrix.c;
            md = matrix.d;
        }
    }

    public function put():Void {}

    public inline function putWeak():Void
    {
        put();
    }
}

class FlxQuadDrawData extends FlxDrawData
{
    static var pool:FlxPool<FlxQuadDrawData> = new FlxPool(FlxQuadDrawData.new);

    public static function get(frame:FlxFrame, smoothing:Bool, repeat:Bool, shader:FlxShader, blend:BlendMode, transform:ColorTransform, matrix:FlxMatrix):FlxQuadDrawData
    {
        var data = pool.get();
        
        data.frame = frame;
        data.textureSmoothing = smoothing;
        data.textureRepeat = repeat;

        data.shader = shader;
        data.blend = blend;
        data.colorTransform = transform;

        data.updateMatrix(matrix);

        return data;
    }

    public var frame(default, set):FlxFrame;
    @:noCompletion inline function set_frame(value:FlxFrame):FlxFrame
    {
        texture = value.parent;
        return this.frame = value;
    }

    override function put():Void
    {
        pool.put(this);
    }
}
