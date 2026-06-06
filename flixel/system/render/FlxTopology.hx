package flixel.system.render;

#if FLX_RENDER_OPENGL
import lime.graphics.opengl.GL;
#end

// TODO: doc

/**
 * Describes the primitive used for the draw call.
 * The actual integer value maps to the corresponding value of the renderer's underlying API,
 * and as such may vary depending on the used renderer backend.
 */
#if FLX_RENDER_OPENGL
enum abstract FlxTopology(Int) from Int to Int
{
    /**
	 * The data is interpreted as a set of triangles. Every 3 indices, coresponding to a vertex pair, form a triangle. 
	 * For example: [0, 1, 2] is one triangle, [3, 4, 5] is another triangle, etc.
	 */
    var TRIANGLE_LIST = GL.TRIANGLES;
    var TRIANGLE_STRIP = GL.TRIANGLE_STRIP;
    // var TRIANGLE_FAN = GL.TRIANGLE_FAN;

    /**
	 * The data is interpreted as a set of lines. Every 2 indices, corresponding to a vertex pair, form a line.
	 * For example: [0, 1, 2, 3] draws two seperate lines, where [0, 1] is one line and [2, 3] is the other.
	 */
    var LINE_LIST = GL.LINES;
    var LINE_STRIP = GL.LINE_STRIP;
    // var LINE_LOOP = GL.LINE_LOOP;

    /**
	 * The data is interpreted as a set of points. Each index, corresponding to a vertex pair, represents a 1px point.
	 * For example: [0, 1, 2] draws three seperate points.
	 */
    var POINT_LIST = GL.POINTS;
}
#else
enum abstract FlxTopology(Int) from Int to Int
{
    var TRIANGLE_LIST = 0;
    var TRIANGLE_STRIP = 1;

    var LINE_LIST = 2;
    var LINE_STRIP = 3;

    var POINT_LIST = 4;
}
#end
