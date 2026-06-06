package flixel.system.render.gl;

import flixel.util.FlxDestroyUtil;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import flixel.system.render.FlxTopology;
import flixel.graphics.shaders.FlxShader;
import openfl.display.BlendMode;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxPool;

/**
 * Internal representation of a draw call.
 * Holds all information about the render state needed.
 */
class FlxDrawCall implements IFlxDestroyable
{
    static var pool:FlxPool<FlxDrawCall> = new FlxPool(FlxDrawCall.new);

	public static inline function get():FlxDrawCall
    {
		final dc = pool.get();
		dc._inPool = false;
        return dc;
    }

	// Buffer data
	public var count:Int;
	public var offset:Int;
	// public var attributes:Array<GLAttribute>;
	public var indexBuffer:GLBuffer;

	// Render state
    public var framebuffer:GLFramebuffer;
	public var topology:FlxTopology;
	public var shader:FlxShader;
	public var blend:BlendMode;
    public var texture:FlxGraphic;
    public var textureRepeat:Bool;
    public var textureSmoothing:Bool;

    var _inPool:Bool = false;

    function new() {}

    public inline function destroy():Void {}

	public inline function init(indexBuffer:GLBuffer, count:Int, offset:Int):FlxDrawCall
	{
		this.indexBuffer = indexBuffer;
		this.count = count;
		this.offset = offset;
		
		return this;
	}
	
	public inline function setState(topology:FlxTopology, shader:FlxShader, blend:BlendMode, texture:FlxGraphic, textureRepeat:Bool,
			textureSmoothing:Bool):FlxDrawCall
	{
		this.topology = topology;
		
		this.shader = shader;
		
		this.blend = blend;
		
		this.texture = texture;
		this.textureRepeat = textureRepeat;
		this.textureSmoothing = textureSmoothing;

		return this;
	}

    public inline function put():Void
    {
        if (!_inPool)
        {
            _inPool = true;
            pool.putUnsafe(this);
        }
    }
}

// typedef GLAttribute =
// {
//     buffer:GLBuffer,
//     name:String,
//     size:Int,
//     type:Int,
//     normalized:Bool,
//     stride:Int,
//     offset:Int
// }
