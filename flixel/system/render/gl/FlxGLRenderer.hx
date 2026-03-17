package flixel.system.render.gl;

import flixel.system.render.FlxRenderer.FlxTypedRenderer;
import lime.math.Matrix4;

class FlxGLRenderer extends FlxTypedRenderer<FlxGLView>
{
    /**
     * The amount of vertices needed for a single quad.
     */
    public static inline final VERTICES_PER_QUAD:Int = 4;

    /**
     * The amount of indices needed for a single quad.
     */
    public static inline final INDICES_PER_QUAD:Int = 6;

    /**
     * The maximum amount of vertices that can fit in a index buffer.
     */
    public static inline final MAX_VERTICES_PER_BUFFER:Int = 65535;

    /**
     * The maximum amount of quads that can fit in an index buffer.
     * 
     * 65335 (max indices in a buffer) / 4 (unique indices per quad) = ~16383
     */
    public static inline final MAX_QUADS_PER_BUFFER:Int = 16383;
    
    /**
     * The default capacity of a quad batch.
     */
    public static inline final QUADS_PER_BATCH:Int = 8192;

    /**
     * The default shader used by the renderer.
     */
    public static var defaultShader:FlxGLShader;

    /**
     * A tiny wrapper over the GL context.
     * 
     * @see `GLContext`
     */
    public var context(default, null):GLContext;

    public var projection(get, never):Matrix4;
    inline function get_projection():Matrix4
    {
        return _needsFlippedProjection ? _projectionFlipped : _projection;
    }

    /**
     * A quad batcher that can only fit a single quad.
     * Used for optimization purposes when drawing unbatchable quads.
     */
    public var singleQuadBatcher:FlxQuadBatcher;
    public var quadBatcher:FlxQuadBatcher;

    var _projection:Matrix4 = new Matrix4();
    var _projectionFlipped:Matrix4 = new Matrix4();
    var _projectionWidth:Int;
    var _projectionHeight:Int;
    var _needsFlippedProjection:Bool = true;

    public function new():Void
    {
        super();
        method = OPENGL;

        context = new GLContext();

        defaultShader = new FlxGLShader();

        singleQuadBatcher = new FlxQuadBatcher(1);
        quadBatcher = new FlxQuadBatcher(QUADS_PER_BATCH);
    }

    public function createCameraView(camera:FlxCamera)
	{
		return new FlxGLView(camera);
	}

    public function resize(width:Int, height:Int):Void
    {
        if (_projectionWidth == width && _projectionHeight == height)
            return;
    
        _projection.createOrtho(0, width, 0, height, -1000, 1000);
        _projectionFlipped.createOrtho(0, width, height, 0, -1000, 1000);

        _projectionWidth = width;
        _projectionHeight = height;
    }
}
