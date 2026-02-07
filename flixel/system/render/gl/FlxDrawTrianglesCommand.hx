package flixel.system.render.gl;

import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxTrianglesData;
import flixel.graphics.shaders.FlxShader;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
// import flixel.system.render.GL.FlxDrawHardwareCommand;
// import flixel.system.render.gll.GLContext;
import openfl.geom.Matrix;
// import flixel.graphics.shaders.triangles.FlxColoredShader;
// import flixel.graphics.shaders.triangles.FlxTexturedShader;
import lime.graphics.opengl.GL;
import lime.math.Matrix4;

// TODO ant: fix textured triangles
class FlxDrawTrianglesCommand extends FlxGLDrawCommand
{
	/**
	 * Default tile shader.
	 */
	private static var defaultTexturedShader = null; //new FlxTexturedShader(); //new FlxTexturedShader();

	private static var defaultColoredShader = new FlxColoredShader(); //new FlxColoredShader();

	public var data:FlxTrianglesData;

	/**
	 * Color transform for this item.
	 */
	public var color:ColorTransform;

	/**
	 * Transformation matrix for this item on camera.
	 */
	public var matrix(default, set):FlxMatrix;

	var _matrix4:Matrix4 = new Matrix4();

	public function new(renderer:FlxGLRenderer)
	{
		super(renderer);
		type = TRIANGLES;
	}

	override public function destroy():Void
	{
        super.destroy();

		data = null;
		_matrix4 = null;
		matrix = null;
		color = null;
	}

	// override public function prepare(context:GLContext, buffer:FlxRenderTexture, ?transform:FlxMatrix):Void
	// {
	// 	reset();
	// 	super.prepare(context, buffer, transform);
	// }

    function setShader(material:FlxMaterial):FlxShader
    {
        var shader = material.shader;

        if (shader == null)
            shader = textured && false ? defaultTexturedShader : defaultColoredShader;

        // GLHelper.useShader(shader);
        context.setShader(shader);
        this.shader = shader;

        return shader;
    }

	override function flush():Void
	{
		// init! init!
		// setContext(context);
		// context.checkRenderTarget(buffer);
		setShader(material);
		
		if (textured)
        	context.setTexture(graphic.bitmap, material.smoothing, material.getWrap());
		// material.apply(cast GL);

		var red:Float = 1.0;
		var green:Float = 1.0;
		var blue:Float = 1.0;
		var alpha:Float = 1.0;

		var redOffset:Float = 0.0;
		var greenOffset:Float = 0.0;
		var blueOffset:Float = 0.0;
		var alphaOffset:Float = 0.0;

		if (color != null)
		{
			red = color.redMultiplier;
			green = color.greenMultiplier;
			blue = color.blueMultiplier;
			alpha = color.alphaMultiplier;

			redOffset = color.redOffset / 255;
			greenOffset = color.greenOffset / 255;
			blueOffset = color.blueOffset / 255;
			alphaOffset = color.alphaOffset / 255;
		}

        // trace(shader);

		// set uniforms
		GL.uniform4f(shader.data.uColor.index, red, green, blue, alpha);
		GL.uniform4f(shader.data.uColorOffset.index, redOffset, greenOffset, blueOffset, alphaOffset);

		GLHelper.uniformMatrix4fv(shader.data.uMatrix.index, false, _matrix4);
		// GLHelper.uniformMatrix4fv(shader.data.uModel.index, false, _matrix4);

		context.setBlendMode(material.blendMode);

		data.updateVertices();
		GL.vertexAttribPointer(shader.data.aPosition.index, 2, GL.FLOAT, false, 0, 0);
        GL.enableVertexAttribArray(shader.data.aPosition.index);

		if (textured && false)
		{
			// update the uvs
			data.updateUV();
			GL.vertexAttribPointer(shader.data.aTexCoord.index, 2, GL.FLOAT, false, 0, 0);
            GL.enableVertexAttribArray(shader.data.aTexCoord.index);
		}

		// update the colors
		data.updateColors();
		GL.vertexAttribPointer(shader.data.aColor.index, 4, GL.UNSIGNED_BYTE, true, 0, 0);
        GL.enableVertexAttribArray(shader.data.aColor.index);

		data.updateIndices();
		data.dirty = false;

		GL.drawElements(GL.TRIANGLES, data.indexCount, GL.UNSIGNED_SHORT, 0);

		FlxRenderer.totalDrawCalls++;
	}

	override public function reset():Void
	{
		super.reset();
		data = null;
		_matrix4.identity();
		color = null;
	}

	// override private function setContext(context:GLContext):Void
	// {
	// 	super.setContext(context);

	// 	if (data != null)
	// 		data.setContext(cast context.GL());
	// }

	public function canAddTriangles(numTriangles:Int):Bool
	{
		return true;
	}

	// override private function get_numVertices():Int
	// {
	// 	return (data != null) ? data.vertexCount : 0;
	// }

	// override private function get_numTriangles():Int
	// {
	// 	return (data != null) ? data.numTriangles : 0;
	// }

	function set_matrix(value:FlxMatrix):FlxMatrix
	{
		if (value != null)
		{
			_matrix4.identity();
			_matrix4[0] = value.a;
			_matrix4[1] = value.b;
			_matrix4[4] = value.c;
			_matrix4[5] = value.d;
			_matrix4[12] = value.tx;
			_matrix4[13] = value.ty;
			_matrix4.append(renderer.projection);
		}

		return matrix = value;
	}
}
