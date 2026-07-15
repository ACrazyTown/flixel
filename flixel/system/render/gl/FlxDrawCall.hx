package flixel.system.render.gl;

import flixel.graphics.shaders.FlxBatcherShader;
import haxe.ds.Vector;
import flixel.util.FlxDestroyUtil;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import flixel.system.render.FlxTopology;
import flixel.graphics.shaders.FlxShader;
import openfl.display.BlendMode;
import flixel.graphics.textures.FlxTexture;
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

    // public var texture:FlxTexture; // Main texture, others should be bound via shader
    // public var textureSmoothing:Bool;
	public var textures:Vector<FlxTexture>;
	public var texturesSmoothing:Vector<Bool>;

    var _inPool:Bool = false;

    function new() 
	{
		final maxTextures = #if FLX_OPENGL_BATCH_TEXTURES FlxBatcherShader.maxTextures #else 1 #end;
		textures = new Vector<FlxTexture>(maxTextures);
		texturesSmoothing = new Vector<Bool>(maxTextures);
	}

    public inline function destroy():Void {}

	public inline function init(indexBuffer:GLBuffer, count:Int, offset:Int):FlxDrawCall
	{
		this.indexBuffer = indexBuffer;
		this.count = count;
		this.offset = offset;
		
		return this;
	}
	
	// public inline function setState(topology:FlxTopology, shader:FlxShader, blend:BlendMode, texture:FlxTexture, textureSmoothing:Bool):FlxDrawCall
	public inline function setState(topology:FlxTopology, shader:FlxShader, blend:BlendMode, textures:Vector<FlxTexture>, texturesSmoothing:Vector<Bool>):FlxDrawCall
	{
		this.topology = topology;
		
		this.shader = shader;
		
		this.blend = blend;
		
		// this.texture = texture;
		// this.textureSmoothing = textureSmoothing;
		Vector.blit(textures, 0, this.textures, 0, textures.length);
		Vector.blit(texturesSmoothing, 0, this.texturesSmoothing, 0, texturesSmoothing.length);

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
