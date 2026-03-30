package flixel.system.render.gl;

import openfl.Vector;
#if FLX_RENDER_OPENGL
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
class FlxDrawData implements IFlxPooled
{
    public var type:FlxDrawType;

    public var texture:FlxGraphic;
    public var textureSmoothing:Bool;
    public var textureRepeat:Bool;

    public var shader:Shader;
    public var blend:BlendMode;
    public var colorTransform:ColorTransform;

    public var matrix:FlxMatrix = new FlxMatrix();

    var _inPool:Bool = false;

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

        this.matrix.identity();
        if (matrix != null)
            this.matrix.copyFrom(matrix);
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
        data.set(frame.parent, smoothing, repeat, shader, blend, transform, matrix);

        data._inPool = false;

        return data;
    }

    public var frame(default, set):FlxFrame;
    @:noCompletion inline function set_frame(value:FlxFrame):FlxFrame
    {
        texture = value.parent;
        return this.frame = value;
    }

    public function new()
    {
        super();
        type = QUAD;
    }

    override function put():Void
    {
        if (!_inPool)
        {
            _inPool = true;
            pool.putUnsafe(this);
        }
    }
}

class FlxTrianglesDrawData extends FlxDrawData
{
	static var pool:FlxPool<FlxTrianglesDrawData> = new FlxPool(FlxTrianglesDrawData.new);
	
	public static function get(vertices:FlxVector2d<Float>, indices:FlxVector2d<Int>, uvs:FlxVector2d<Float>, colors:FlxVector2d<Int>, texture:FlxGraphic,
			smoothing:Bool, repeat:Bool, shader:Shader, blend:BlendMode, transform:ColorTransform, matrix:FlxMatrix)
    {
        var data = pool.get();

        data.vertices = vertices;
        data.indices = indices;
        data.uvs = uvs;
        data.colors = colors;
        data.set(texture, smoothing, repeat, shader, blend, transform, matrix);

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

    override function put():Void
    {
        if (!_inPool)
        {
            _inPool = true;
            pool.putUnsafe(this);
        }
    }
}
#end
