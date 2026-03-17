package flixel.system.render.gl;

import flixel.graphics.FlxGraphic;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxPool;
import lime.graphics.opengl.GL;
import lime.utils.ArrayBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import openfl.display.BlendMode;
import openfl.display.Shader;

/**
 * A base graphics batcher. 
 * It provides very little logic on its own and can't be instantiated directly.
 * 
 * @see `FlxQuadBatcher` for an example on a (quad) batcher implementation.
 */
abstract class FlxBatcher<T:FlxDrawData> implements IFlxDestroyable
{
    /**
     * The amount of vertices that can fit in this batch.
     */
    public var size(default, null):Int;

    /**
     * The number of attributes per vertex.
     */
    public var attributesPerVertex:Int;

    /**
     * The shader used by the last added element. 
     * Used to determine when to queue a draw call.
     */
    var _currentShader:Shader;

    /**
     * The blend mode used by the last added element. 
     * Used to determine when to queue a draw call.
     */
    var _currentBlendMode:BlendMode;

    // TODO ant: replace these 3 with FlxTexture
    /**
     * The texture used by the last added element. 
     * Used to determine when to queue a draw call.
     */
    var _currentTexture:FlxGraphic;
    var _currentTextureRepeat:Bool;
    var _currentTextureSmoothing:Bool;

    var _renderer(get, never):FlxGLRenderer;
	inline function get__renderer() return cast (FlxG.renderer, FlxGLRenderer);

    public function new(size:Int, attributesPerVertex:Int)
    {
        if (size <= 0 || size >= FlxGLRenderer.MAX_VERTICES_PER_BUFFER)
            size = FlxGLRenderer.MAX_VERTICES_PER_BUFFER;

        this.size = size;
        this.attributesPerVertex = attributesPerVertex;
    }

    public function destroy():Void {}

    abstract public function add(data:T):Void;

    /**
     * Flush the contents of the buffer and draw all the stored batches.
     */
    abstract public function flush():Void;

    /**
     * Executes a batched draw call.
     * 
     * @param   dc   The draw call to execute.
     */
    function draw(dc:DrawCall):Void
    {
        final shader = dc.shader;

        // Prep the GL state for the upcoming draw
        if (_renderer.context.setShader(shader))
            initShader(shader);

        _renderer.context.setBlendMode(dc.blend);

        _renderer.context.setTexture(dc.texture.bitmap, dc.textureRepeat, dc.textureSmoothing);
        GL.activeTexture(GL.TEXTURE0);
        GL.uniform1i(shader.data.uImage0.index, 0);
        GL.uniform2f(shader.data.uTextureSize.index, dc.texture.width, dc.texture.height);

        // Finally, actually draw them
        GL.drawElements(GL.TRIANGLES, dc.count, GL.UNSIGNED_SHORT, dc.offset);
        FlxG.renderer.totalDrawCalls++;

        dc.put();

        // _offset += _count;
        // _count = 0;
    }

    /**
     * Called during a draw call, when the active shader changes.
     */
    abstract function initShader(shader:Shader):Void;
}

/**
 * Internal data representation of a batched draw call.
 * Managed and reused internally by the batcher, you probably shouldn't mess with these.
 */
class DrawCall implements IFlxDestroyable
{
    static var pool:FlxPool<DrawCall> = new FlxPool(DrawCall.new);

    public static inline function get(count:Int, offset:Int, shader:Shader, blend:BlendMode, texture:FlxGraphic, textureRepeat:Bool, textureSmoothing:Bool):DrawCall
    {
        var dc = pool.get();
        dc.set(count, offset, shader, blend, texture, textureRepeat, textureSmoothing);
        return dc;
    }

    public var shader:Shader;

    public var blend:BlendMode;

    public var texture:FlxGraphic;
    public var textureRepeat:Bool;
    public var textureSmoothing:Bool;

    public var count:Int;
    public var offset:Int;

    function new() {}

    public function destroy():Void {}

    public inline function set(count:Int, offset:Int, shader:Shader, blend:BlendMode, texture:FlxGraphic, textureRepeat:Bool, textureSmoothing:Bool)
    {
        this.count = count;
        this.offset = offset;

        this.shader = shader;

        this.blend = blend;

        this.texture = texture;
        this.textureRepeat = textureRepeat;
        this.textureSmoothing = textureSmoothing;
    }

    public inline function put():Void
    {
        pool.put(this);
    }
}
