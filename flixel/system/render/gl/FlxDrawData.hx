package flixel.system.render.gl;

#if FLX_RENDER_OPENGL
import flixel.util.FlxColor;
import openfl.Vector;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxPool;
import openfl.display.BlendMode;
import openfl.display.Shader;
import openfl.geom.ColorTransform;

enum FlxDrawType
{
    QUAD;
    TRIANGLES;
}

/**
 * Helper, stores data about a queued sprite to draw.
 */
class FlxDrawData implements IFlxDestroyable
{
    public var type:FlxDrawType;

    public var texture:FlxGraphic;
    public var textureSmoothing:Bool;
    public var textureRepeat:Bool;

    public var shader:Shader;
    public var blend:BlendMode;

    public var colorOffset:FlxColor;
    public var colorMultiplier:FlxColor;

    public var matrix:FlxMatrix = new FlxMatrix();

    var _inPool:Bool = false;

    function new() {}

    public inline function destroy():Void {}

    public inline function setMatrix(matrix:FlxMatrix)
    {
        if (matrix != null)
            this.matrix.copyFrom(matrix);
        else
            this.matrix.identity();
    }
}

class FlxQuadDrawData extends FlxDrawData implements IFlxPooled
{
    static var pool:FlxPool<FlxQuadDrawData> = new FlxPool(FlxQuadDrawData.new);

    public overload extern static inline function get(frame:FlxFrame, smoothing:Bool, repeat:Bool, shader:FlxShader, blend:BlendMode, colorMultiplier:FlxColor, colorOffset:FlxColor, matrix:FlxMatrix):FlxQuadDrawData
    {
        var data = pool.get();
        
        data.frame = frame;

        data.texture = frame.parent;
        data.textureSmoothing = smoothing;
        data.textureRepeat = repeat;
        data.shader = shader;
        data.blend = blend;
        data.colorMultiplier = colorMultiplier;
        data.colorOffset = colorOffset;
        data.setMatrix(matrix);

        data._inPool = false;

        return data;
    }

    public overload extern static inline function get(frame:FlxFrame, smoothing:Bool, repeat:Bool, shader:FlxShader, blend:BlendMode, transform:ColorTransform, matrix:FlxMatrix):FlxQuadDrawData
    {
        var colorMultiplier = FlxColor.WHITE;
        var colorOffset = FlxColor.TRANSPARENT;

        if (transform != null)
        {
            colorMultiplier = FlxColor.fromRGBFloat(transform.redMultiplier, transform.greenMultiplier, transform.blueMultiplier, transform.alphaMultiplier);
            colorOffset = FlxColor.fromRGB(Std.int(transform.redOffset), Std.int(transform.greenOffset), Std.int(transform.blueOffset), Std.int(transform.alphaOffset));
        }

        return get(frame, smoothing, repeat, shader, blend, colorMultiplier, colorOffset, matrix);
    }

    public var frame:FlxFrame;

    public function new()
    {
        super();
        type = QUAD;
    }

    public inline function put():Void
    {
        if (!_inPool)
        {
            _inPool = true;
            pool.putUnsafe(this);
        }
    }

    public inline function putWeak():Void
    {
        put();
    }
}

class FlxTrianglesDrawData extends FlxDrawData implements IFlxPooled
{
	static var pool:FlxPool<FlxTrianglesDrawData> = new FlxPool(FlxTrianglesDrawData.new);
	
	public static inline function get(vertices:FlxVector2d<Float>, indices:FlxVector2d<Int>, uvs:FlxVector2d<Float>, colors:FlxVector2d<Int>, texture:FlxGraphic,
			smoothing:Bool, repeat:Bool, shader:Shader, blend:BlendMode, transform:ColorTransform, matrix:FlxMatrix)
    {
        var data = pool.get();

        data.vertices = vertices;
        data.indices = indices;
        data.uvs = uvs;
        data.colors = colors;

        data.texture = texture;
        data.textureSmoothing = smoothing;
        data.textureRepeat = repeat;
        data.shader = shader;
        data.blend = blend;

        var colorMultiplier = FlxColor.WHITE;
        var colorOffset = FlxColor.TRANSPARENT;

        if (transform != null)
        {
            colorMultiplier = FlxColor.fromRGBFloat(transform.redMultiplier, transform.greenMultiplier, transform.blueMultiplier, transform.alphaMultiplier);
            colorOffset = FlxColor.fromRGB(Std.int(transform.redOffset), Std.int(transform.greenOffset), Std.int(transform.blueOffset), Std.int(transform.alphaOffset));
        }
        
        data.colorMultiplier = colorMultiplier;
        data.colorOffset = colorOffset;

        data.setMatrix(matrix);

        data._inPool = false;

        return data;
    }
			
    // TODO: typed array
	public var vertices:FlxVector2d<Float>;
	public var indices:Vector<Int>;
	public var uvs:FlxVector2d<Float>;
	public var colors:Vector<Int>;

    public function new()
    {
        super();
        type = TRIANGLES;
    }

    public inline function put():Void
    {
        if (!_inPool)
        {
            _inPool = true;
            pool.putUnsafe(this);
        }
    }

    public inline function putWeak():Void
    {
        put();
    }
}
#end
